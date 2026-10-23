use std::{
    fs,
    io::{BufRead, BufReader, BufWriter, ErrorKind, Write},
    path::PathBuf,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    thread::{self, JoinHandle},
};

#[cfg(target_os = "macos")]
use std::os::unix::net::{UnixListener, UnixStream};

#[cfg(target_os = "windows")]
use std::net::{SocketAddr, TcpListener, TcpStream};

use anyhow::{Context, Result, bail};
use serde::{Deserialize, Serialize, de::DeserializeOwned};
use std::time::Duration;
use winit::event_loop::EventLoopProxy;

use crate::{
    settings::neovide_std_datapath,
    version::{BUILD_VERSION, release_channel},
    window::{EventPayload, EventTarget, UserEvent},
};

// [CUSTOM-BEGIN] CUSTOM-20261024-002 - Windows instance-reuse transport (loopback TCP + PID endpoint)
// 上游仅实现 macOS unix-socket 单实例复用；此处为 Windows 新增传输层：
// - EndpointInfo：把「端口 + 服务端 PID」写入 endpoint 文件（neovide-<channel>.tcp）
// - try_handoff / start_listener / handle_connection / endpoint_path 的 windows 分支（127.0.0.1 回环 TCP）
// - allow_set_foreground_window：由双击的客户端进程授权服务端抢回前台
// [CUSTOM-END] CUSTOM-20261024-002

const CLIENT_IO_TIMEOUT: Duration = Duration::from_secs(2);
const LISTENER_POLL_INTERVAL: Duration = Duration::from_millis(100);

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct HandoffRequest {
    pub version: String,
    pub files_to_open: Vec<String>,
    pub cwd: Option<String>,
    pub caller_cwd: Option<String>,
    pub tabs: bool,
    pub new_window: bool,
}

impl HandoffRequest {
    #[allow(dead_code)]
    pub fn new() -> Self {
        Self {
            version: BUILD_VERSION.to_owned(),
            files_to_open: Vec::new(),
            cwd: None,
            caller_cwd: None,
            tabs: true,
            new_window: false,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum HandoffResult {
    Accepted,
    NoListener,
    Failed(String),
    Rejected(String),
}

/// Opaque handle that keeps the instance IPC listener alive and tears it down on drop.
pub struct ListenerGuard {
    shutdown: Arc<AtomicBool>,
    join_handle: Option<JoinHandle<()>>,
    endpoint: PathBuf,
    #[cfg(target_os = "windows")]
    addr: SocketAddr,
}

impl Drop for ListenerGuard {
    fn drop(&mut self) {
        self.shutdown.store(true, Ordering::Relaxed);

        // Unblock the accept loop so the thread can observe the shutdown flag.
        #[cfg(target_os = "macos")]
        let _ = UnixStream::connect(&self.endpoint);
        #[cfg(target_os = "windows")]
        let _ = TcpStream::connect(self.addr);

        if let Some(join_handle) = self.join_handle.take() {
            let _ = join_handle.join();
        }

        let _ = fs::remove_file(&self.endpoint);
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct HandoffResponse {
    accepted: bool,
    version: String,
    error: Option<String>,
}

/// Windows transport metadata written to the endpoint file: the loopback port the
/// listener is bound to and the server process id. The pid lets the forwarding
/// client grant the running instance permission to bring its window to the foreground.
#[cfg(target_os = "windows")]
#[derive(Serialize, Deserialize)]
struct EndpointInfo {
    port: u16,
    pid: u32,
}

/// Sends a handoff request and reads the response over an established stream.
fn exchange_request<R: BufRead, W: Write>(
    mut writer: W,
    mut reader: R,
    request: &HandoffRequest,
) -> HandoffResult {
    if let Err(error) = write_message(&mut writer, request) {
        return HandoffResult::Failed(format!("failed to send instance IPC request: {error}"));
    }

    match read_message::<HandoffResponse, _>(&mut reader) {
        Ok(response) if response.accepted => HandoffResult::Accepted,
        Ok(response) => HandoffResult::Rejected(
            response.error.unwrap_or_else(|| "instance IPC request was rejected".to_owned()),
        ),
        Err(error) => {
            HandoffResult::Failed(format!("failed to read instance IPC response: {error}"))
        }
    }
}

#[cfg(target_os = "macos")]
pub fn try_handoff(request: &HandoffRequest) -> HandoffResult {
    let endpoint = endpoint_path();
    let stream = match UnixStream::connect(&endpoint) {
        Ok(stream) => stream,
        Err(error) => match error.kind() {
            ErrorKind::NotFound | ErrorKind::ConnectionRefused => return HandoffResult::NoListener,
            _ => {
                return HandoffResult::Failed(format!(
                    "failed to connect to instance IPC listener at {}: {error}",
                    endpoint.display()
                ));
            }
        },
    };

    let _ = stream.set_read_timeout(Some(CLIENT_IO_TIMEOUT));
    let _ = stream.set_write_timeout(Some(CLIENT_IO_TIMEOUT));

    let writer = match stream.try_clone() {
        Ok(stream) => BufWriter::new(stream),
        Err(error) => {
            return HandoffResult::Failed(format!(
                "failed to clone instance IPC stream for writing: {error}"
            ));
        }
    };

    exchange_request(writer, BufReader::new(stream), request)
}

#[cfg(target_os = "windows")]
pub fn try_handoff(request: &HandoffRequest) -> HandoffResult {
    let endpoint = endpoint_path();
    let info: EndpointInfo = match fs::read_to_string(&endpoint) {
        Ok(contents) => match serde_json::from_str(&contents) {
            Ok(info) => info,
            Err(error) => {
                return HandoffResult::Failed(format!(
                    "failed to parse instance IPC endpoint file {}: {error}",
                    endpoint.display()
                ));
            }
        },
        Err(error) if error.kind() == ErrorKind::NotFound => return HandoffResult::NoListener,
        Err(error) => {
            return HandoffResult::Failed(format!(
                "failed to read instance IPC endpoint file {}: {error}",
                endpoint.display()
            ));
        }
    };

    // The double-clicked process owns the foreground at this point; grant the running
    // instance a one-shot right to bring its window to the front when it focuses.
    allow_set_foreground_window(info.pid);

    let addr = SocketAddr::from(([127, 0, 0, 1], info.port));
    let stream = match TcpStream::connect(addr) {
        Ok(stream) => stream,
        Err(error) => match error.kind() {
            ErrorKind::ConnectionRefused | ErrorKind::NotFound => return HandoffResult::NoListener,
            _ => {
                return HandoffResult::Failed(format!(
                    "failed to connect to instance IPC listener at {addr}: {error}"
                ));
            }
        },
    };

    let _ = stream.set_read_timeout(Some(CLIENT_IO_TIMEOUT));
    let _ = stream.set_write_timeout(Some(CLIENT_IO_TIMEOUT));

    let writer = match stream.try_clone() {
        Ok(stream) => BufWriter::new(stream),
        Err(error) => {
            return HandoffResult::Failed(format!(
                "failed to clone instance IPC stream for writing: {error}"
            ));
        }
    };

    exchange_request(writer, BufReader::new(stream), request)
}

#[cfg(target_os = "macos")]
pub fn start_listener(proxy: EventLoopProxy<EventPayload>) -> Result<ListenerGuard> {
    let endpoint = endpoint_path();
    fs::create_dir_all(neovide_std_datapath()).with_context(|| {
        format!("failed to create instance IPC data directory {}", neovide_std_datapath().display())
    })?;

    if endpoint.exists() {
        match UnixStream::connect(&endpoint) {
            Ok(_) => {
                bail!("instance IPC listener is already running at {}", endpoint.display());
            }
            Err(error)
                if matches!(
                    error.kind(),
                    std::io::ErrorKind::NotFound | std::io::ErrorKind::ConnectionRefused
                ) =>
            {
                fs::remove_file(&endpoint).with_context(|| {
                    format!("failed to remove stale instance IPC socket {}", endpoint.display())
                })?;
            }
            Err(error) => {
                return Err(error).with_context(|| {
                    format!(
                        "failed to validate existing instance IPC socket {}",
                        endpoint.display()
                    )
                });
            }
        }
    }

    let listener = UnixListener::bind(&endpoint).with_context(|| {
        format!("failed to bind instance IPC listener at {}", endpoint.display())
    })?;

    listener
        .set_nonblocking(true)
        .context("failed to configure instance IPC listener as nonblocking")?;

    let shutdown = Arc::new(AtomicBool::new(false));
    let listener_proxy = proxy.clone();
    let listener_shutdown = shutdown.clone();
    let join_handle = thread::Builder::new()
        .name("instance-ipc-listener".to_owned())
        .spawn(move || {
            while !listener_shutdown.load(Ordering::Relaxed) {
                match listener.accept() {
                    Ok((stream, _)) => {
                        if let Err(error) = handle_connection(stream, &listener_proxy) {
                            log::warn!("instance IPC connection failed: {error:#}");
                        }
                    }
                    Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                        thread::sleep(LISTENER_POLL_INTERVAL);
                    }
                    Err(error) => {
                        log::error!("instance IPC listener failed: {error}");
                        break;
                    }
                }
            }
        })
        .context("failed to spawn instance IPC listener thread")?;

    Ok(ListenerGuard { shutdown, join_handle: Some(join_handle), endpoint })
}

#[cfg(target_os = "windows")]
pub fn start_listener(proxy: EventLoopProxy<EventPayload>) -> Result<ListenerGuard> {
    let endpoint = endpoint_path();
    fs::create_dir_all(neovide_std_datapath()).with_context(|| {
        format!("failed to create instance IPC data directory {}", neovide_std_datapath().display())
    })?;

    if endpoint.exists() {
        // A previous instance may have left a stale endpoint file behind. It's stale if
        // nothing is listening on the recorded port anymore.
        let stale = match fs::read_to_string(&endpoint) {
            Ok(contents) => match serde_json::from_str::<EndpointInfo>(&contents) {
                Ok(info) => {
                    let addr = SocketAddr::from(([127, 0, 0, 1], info.port));
                    TcpStream::connect(addr).is_err()
                }
                Err(_) => true,
            },
            Err(_) => true,
        };

        if !stale {
            bail!("instance IPC listener is already running at {}", endpoint.display());
        }
        fs::remove_file(&endpoint).with_context(|| {
            format!("failed to remove stale instance IPC endpoint {}", endpoint.display())
        })?;
    }

    let listener = TcpListener::bind(SocketAddr::from(([127, 0, 0, 1], 0)))
        .context("failed to bind instance IPC listener")?;
    let addr = listener.local_addr().context("failed to read instance IPC listener address")?;

    // Publish the port and server pid so forwarding clients can connect and grant
    // foreground permission.
    let info = EndpointInfo { port: addr.port(), pid: std::process::id() };
    let contents =
        serde_json::to_string(&info).context("failed to serialize instance IPC endpoint")?;
    fs::write(&endpoint, contents)
        .with_context(|| format!("failed to write instance IPC endpoint {}", endpoint.display()))?;

    listener
        .set_nonblocking(true)
        .context("failed to configure instance IPC listener as nonblocking")?;

    let shutdown = Arc::new(AtomicBool::new(false));
    let listener_proxy = proxy.clone();
    let listener_shutdown = shutdown.clone();
    let join_handle = thread::Builder::new()
        .name("instance-ipc-listener".to_owned())
        .spawn(move || {
            while !listener_shutdown.load(Ordering::Relaxed) {
                match listener.accept() {
                    Ok((stream, _)) => {
                        if let Err(error) = handle_connection(stream, &listener_proxy) {
                            log::warn!("instance IPC connection failed: {error:#}");
                        }
                    }
                    Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                        thread::sleep(LISTENER_POLL_INTERVAL);
                    }
                    Err(error) => {
                        log::error!("instance IPC listener failed: {error}");
                        break;
                    }
                }
            }
        })
        .context("failed to spawn instance IPC listener thread")?;

    Ok(ListenerGuard {
        shutdown,
        join_handle: Some(join_handle),
        endpoint,
        #[cfg(target_os = "windows")]
        addr,
    })
}

#[cfg(target_os = "macos")]
fn handle_connection(stream: UnixStream, proxy: &EventLoopProxy<EventPayload>) -> Result<()> {
    let _ = stream.set_read_timeout(Some(CLIENT_IO_TIMEOUT));
    let _ = stream.set_write_timeout(Some(CLIENT_IO_TIMEOUT));

    let mut reader = BufReader::new(stream.try_clone().context("failed to clone IPC stream")?);
    let request: HandoffRequest =
        read_message(&mut reader).context("failed to decode instance IPC request")?;

    let response = handle_request(request, proxy);
    let mut writer = BufWriter::new(stream);
    write_message(&mut writer, &response).context("failed to encode instance IPC response")
}

#[cfg(target_os = "windows")]
fn handle_connection(stream: TcpStream, proxy: &EventLoopProxy<EventPayload>) -> Result<()> {
    let _ = stream.set_read_timeout(Some(CLIENT_IO_TIMEOUT));
    let _ = stream.set_write_timeout(Some(CLIENT_IO_TIMEOUT));

    let mut reader = BufReader::new(stream.try_clone().context("failed to clone IPC stream")?);
    let request: HandoffRequest =
        read_message(&mut reader).context("failed to decode instance IPC request")?;

    let response = handle_request(request, proxy);
    let mut writer = BufWriter::new(stream);
    write_message(&mut writer, &response).context("failed to encode instance IPC response")
}

/// Grants the given process a one-shot right to set the foreground window. Called from
/// the double-clicked forwarding process, which owns the foreground at this point.
#[cfg(target_os = "windows")]
fn allow_set_foreground_window(pid: u32) {
    use windows::Win32::UI::WindowsAndMessaging::AllowSetForegroundWindow;

    unsafe {
        let _ = AllowSetForegroundWindow(pid);
    }
}

fn handle_request(
    request: HandoffRequest,
    proxy: &EventLoopProxy<EventPayload>,
) -> HandoffResponse {
    if request.new_window || !request.files_to_open.is_empty() {
        let payload = EventPayload {
            payload: UserEvent::OpenFiles {
                files: request.files_to_open,
                cwd: request.cwd,
                caller_cwd: request.caller_cwd,
                tabs: request.tabs,
                new_window: request.new_window,
            },
            target: EventTarget::Focused,
        };

        if let Err(error) = proxy.send_event(payload) {
            return HandoffResponse {
                accepted: false,
                version: BUILD_VERSION.to_owned(),
                error: Some(format!(
                    "failed to forward handoff request to app event loop: {error}"
                )),
            };
        }
    }

    HandoffResponse { accepted: true, version: BUILD_VERSION.to_owned(), error: None }
}

#[cfg(target_os = "macos")]
fn endpoint_path() -> PathBuf {
    neovide_std_datapath().join(format!("neovide-{}.sock", release_channel()))
}

#[cfg(target_os = "windows")]
fn endpoint_path() -> PathBuf {
    neovide_std_datapath().join(format!("neovide-{}.tcp", release_channel()))
}

fn write_message<T, W>(writer: &mut W, value: &T) -> Result<()>
where
    T: Serialize,
    W: Write,
{
    serde_json::to_writer(&mut *writer, value).context("failed to serialize JSON message")?;
    writer.write_all(b"\n").context("failed to terminate JSON message")?;
    writer.flush().context("failed to flush JSON message")
}

fn read_message<T, R>(reader: &mut R) -> Result<T>
where
    T: DeserializeOwned,
    R: BufRead,
{
    let mut buffer = Vec::new();
    let bytes_read =
        reader.read_until(b'\n', &mut buffer).context("failed to read JSON message")?;

    if bytes_read == 0 {
        bail!("connection closed before a JSON message was received");
    }

    if matches!(buffer.last(), Some(b'\n')) {
        buffer.pop();
    }

    serde_json::from_slice(&buffer).context("failed to deserialize JSON message")
}

#[cfg(test)]
mod tests {
    use super::{HandoffRequest, HandoffResponse, read_message, write_message};
    use crate::version::BUILD_VERSION;
    use std::io::Cursor;

    #[test]
    fn handoff_request_new_sets_build_version() {
        let request = HandoffRequest::new();
        assert_eq!(request.version, BUILD_VERSION);
        assert!(request.files_to_open.is_empty());
        assert!(request.cwd.is_none());
        assert!(request.caller_cwd.is_none());
        assert!(request.tabs);
        assert!(!request.new_window);
    }

    #[test]
    fn json_line_roundtrip_preserves_request() {
        let request = HandoffRequest {
            files_to_open: vec!["~/project".into()],
            cwd: Some("/path/to/user".into()),
            caller_cwd: Some("/path/to/worktree".into()),
            tabs: false,
            new_window: true,
            ..HandoffRequest::new()
        };

        let mut encoded = Vec::new();
        write_message(&mut encoded, &request).unwrap();

        let mut cursor = Cursor::new(encoded);
        let decoded: HandoffRequest = read_message(&mut cursor).unwrap();

        assert_eq!(decoded, request);
    }

    #[test]
    fn json_line_roundtrip_preserves_response() {
        let response =
            HandoffResponse { accepted: true, version: BUILD_VERSION.to_owned(), error: None };

        let mut encoded = Vec::new();
        write_message(&mut encoded, &response).unwrap();

        let mut cursor = Cursor::new(encoded);
        let decoded: HandoffResponse = read_message(&mut cursor).unwrap();

        assert_eq!(decoded, response);
    }
}
