// [CUSTOM-BEGIN] CUSTOM-20261029-001 - 关闭窗口后驻留系统托盘
//! Windows 系统托盘。
//!
//! 只在窗口被隐藏到托盘后创建；窗口恢复时随 [`Tray`] 析构自动移除图标。
//! 托盘左键通过 [`UserEvent::TrayActivate`] 唤醒 winit 事件循环，右键菜单项
//! 复用 `menubar` 安装的全局 muda 菜单事件回调（id 以 `neovide-tray-` 开头）。

use std::{
    fs::File,
    io::Read,
    sync::{Arc, Mutex},
};

use image::load_from_memory;
use log::warn;
use tray_icon::{
    Icon, MouseButton, MouseButtonState, TrayIcon, TrayIconBuilder, TrayIconEvent,
    menu::{Menu, MenuItem, PredefinedMenuItem, accelerator::Accelerator},
};
use winit::event_loop::EventLoopProxy;

use crate::utils::expand_tilde;

use super::{EventPayload, UserEvent};

pub const SHOW_MENU_ID: &str = "neovide-tray-show";
pub const QUIT_MENU_ID: &str = "neovide-tray-quit";

const TOOLTIP: &str = "Neovide";
const DEFAULT_ICON: &[u8] = include_bytes!("../../assets/neovide.ico");

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TrayMenuAction {
    Show,
    Quit,
}

impl TrayMenuAction {
    pub fn from_menu_id(id: &str) -> Option<Self> {
        match id {
            SHOW_MENU_ID => Some(Self::Show),
            QUIT_MENU_ID => Some(Self::Quit),
            _ => None,
        }
    }
}

/// 持有托盘图标。drop 时 tray-icon 会调用 `Shell_NotifyIcon(NIM_DELETE)`。
pub struct Tray {
    _icon: TrayIcon,
}

impl Tray {
    /// 在当前线程（winit 事件循环线程）创建托盘图标。
    ///
    /// 返回 `None` 时调用方不应隐藏窗口，否则用户将无法恢复窗口。
    pub fn create(proxy: EventLoopProxy<EventPayload>, icon_path: Option<&str>) -> Option<Self> {
        let icon = load_tray_icon(icon_path)?;

        let show = MenuItem::with_id(SHOW_MENU_ID, "显示窗口", true, None::<Accelerator>);
        let separator = PredefinedMenuItem::separator();
        let quit = MenuItem::with_id(QUIT_MENU_ID, "退出 Neovide", true, None::<Accelerator>);
        let menu = Menu::new();
        if let Err(error) = menu.append_items(&[&show, &separator, &quit]) {
            warn!("Failed to build tray menu: {error}");
            return None;
        }

        // TrayIconEvent 的全局 handler 只能设置一次；proxy 每次都是同一个事件循环代理，
        // 因此重复设置（后续托盘创建）被忽略也不会影响行为。
        let proxy = Arc::new(Mutex::new(proxy));
        TrayIconEvent::set_event_handler(Some(move |event: TrayIconEvent| {
            if matches!(
                event,
                TrayIconEvent::Click {
                    button: MouseButton::Left,
                    button_state: MouseButtonState::Up,
                    ..
                }
            ) {
                if let Ok(proxy) = proxy.lock() {
                    let _ = proxy.send_event(EventPayload::all(UserEvent::TrayActivate));
                }
            }
        }));

        let tray = match TrayIconBuilder::new()
            .with_tooltip(TOOLTIP)
            .with_icon(icon)
            .with_menu(Box::new(menu))
            // 左键用于恢复窗口，不弹菜单；右键仍然是菜单。
            .with_menu_on_left_click(false)
            .build()
        {
            Ok(tray) => tray,
            Err(error) => {
                warn!("Failed to create tray icon: {error}");
                return None;
            }
        };

        Some(Self { _icon: tray })
    }
}

fn load_tray_icon(path: Option<&str>) -> Option<Icon> {
    let data = match path {
        Some(path) => {
            let expanded = expand_tilde(path);
            let mut data = Vec::new();
            match File::open(&expanded).and_then(|mut file| file.read_to_end(&mut data)) {
                Ok(_) => data,
                Err(error) => {
                    warn!("Failed to read tray icon `{expanded}`: {error}; using default icon");
                    DEFAULT_ICON.to_vec()
                }
            }
        }
        None => DEFAULT_ICON.to_vec(),
    };

    let image = match load_from_memory(&data) {
        Ok(image) => image,
        Err(error) => {
            warn!("Failed to decode tray icon: {error}");
            return None;
        }
    };
    let rgba = image.to_rgba8();
    let (width, height) = rgba.dimensions();
    match Icon::from_rgba(rgba.into_raw(), width, height) {
        Ok(icon) => Some(icon),
        Err(error) => {
            warn!("Failed to create tray icon from RGBA data: {error}");
            None
        }
    }
}
// [CUSTOM-END] CUSTOM-20261029-001
