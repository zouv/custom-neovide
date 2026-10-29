// [CUSTOM-BEGIN] CUSTOM-20261029-003 - 帮助.关于
//! “关于 Neovide”原生对话框（Windows）。
//!
//! 菜单项由 nvim 侧 `:amenu` 定义，点击后通过 `rpcnotify("neovide.about", text)`
//! 把展示内容送到这里，用 Win32 MessageBox 弹出。

use windows::{
    Win32::UI::WindowsAndMessaging::{MB_ICONINFORMATION, MB_OK, MessageBoxW},
    core::HSTRING,
};

use super::menubar::window_hwnd;
use winit::window::Window;

const TITLE: &str = "关于 Neovide";

pub fn show(message: &str, window: Option<&Window>) {
    let owner = window
        .and_then(window_hwnd)
        .map(|hwnd| windows::Win32::Foundation::HWND(hwnd as *mut core::ffi::c_void));

    // SAFETY: 这是阻塞式原生对话框；owner 是当前 Neovide 窗口，字符串在调用期间有效。
    unsafe {
        MessageBoxW(
            owner,
            &HSTRING::from(message),
            &HSTRING::from(TITLE),
            MB_OK | MB_ICONINFORMATION,
        );
    }
}
// [CUSTOM-END] CUSTOM-20261029-003
