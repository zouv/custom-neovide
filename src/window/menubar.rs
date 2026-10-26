// [CUSTOM-BEGIN] CUSTOM-20261025-001 - Windows 原生菜单栏
//
// 菜单内容由 nvim 侧通过 `:amenu` 定义，`neovide.refresh_menu()` 把 `menu_get("")`
// 的树发过来，这里用 muda 转换成 Win32 菜单挂在窗口上；点击后把菜单路径发回 nvim
// 用 `:emenu` 执行。Neovide 只负责“显示 + 转发”，不硬编码任何编辑操作。

use std::{fmt, sync::Arc};

use log::warn;
use muda::{IsMenuItem, Menu, MenuEvent, MenuId, MenuItem, MenuTheme, PredefinedMenuItem, Submenu};
use raw_window_handle::{HasWindowHandle, RawWindowHandle};
use rmpv::Value;
use winit::{
    event_loop::EventLoopProxy,
    window::{Theme, Window},
};

use windows::Win32::{
    Foundation::{HWND, LPARAM, LRESULT, WPARAM},
    UI::{
        Input::KeyboardAndMouse::{GetKeyState, VK_CONTROL},
        Shell::{DefSubclassProc, SetWindowSubclass},
        WindowsAndMessaging::{SC_KEYMENU, WM_SYSCHAR, WM_SYSCOMMAND},
    },
};

use crate::window::{EventPayload, UserEvent};

/// 自定义窗口子类的 id，避免与 muda / winit 的 id 冲突。
const ALT_FILTER_SUBCLASS_ID: usize = 0x4E56_4442; // 'NVDB'

#[derive(Clone, Debug, PartialEq)]
pub enum MenuEntryKind {
    Item { path: String, enabled: bool },
    Submenu(Vec<MenuEntry>),
    Separator,
}

#[derive(Clone, Debug, PartialEq)]
pub struct MenuEntry {
    pub title: String,
    pub hint: Option<String>,
    pub kind: MenuEntryKind,
}

/// 解析 nvim 侧发来的菜单树：
/// `{ title, hint?, path?, enabled?, items?, separator? }` 的数组。
pub fn parse_menu(value: &Value) -> Vec<MenuEntry> {
    parse_entries(value).unwrap_or_default()
}

fn parse_entries(value: &Value) -> Option<Vec<MenuEntry>> {
    let items = value.as_array()?;
    Some(items.iter().filter_map(parse_entry).collect())
}

fn parse_entry(value: &Value) -> Option<MenuEntry> {
    let map = value.as_map()?;

    let mut title = String::new();
    let mut hint = None;
    let mut path = None;
    let mut enabled = true;
    let mut children = None;
    let mut separator = false;

    for (key, value) in map {
        match key.as_str() {
            Some("title") => title = value.as_str().unwrap_or_default().to_string(),
            Some("hint") => {
                hint = value.as_str().filter(|hint| !hint.is_empty()).map(str::to_string)
            }
            Some("path") => path = value.as_str().map(str::to_string),
            Some("enabled") => enabled = value.as_bool().unwrap_or(true),
            Some("items") => children = parse_entries(value),
            Some("separator") => separator = value.as_bool().unwrap_or(false),
            _ => {}
        }
    }

    if separator {
        return Some(MenuEntry { title, hint: None, kind: MenuEntryKind::Separator });
    }

    if let Some(children) = children {
        return Some(MenuEntry { title, hint: None, kind: MenuEntryKind::Submenu(children) });
    }

    let path = path?;
    Some(MenuEntry { title, hint, kind: MenuEntryKind::Item { path, enabled } })
}

enum MenuParent<'a> {
    Menu(&'a Menu),
    Submenu(&'a Submenu),
}

impl MenuParent<'_> {
    fn append(&self, item: &dyn IsMenuItem) {
        let result = match self {
            MenuParent::Menu(menu) => menu.append(item),
            MenuParent::Submenu(submenu) => submenu.append(item),
        };
        if let Err(error) = result {
            warn!("Failed to append menu item: {error}");
        }
    }
}

fn item_text(entry: &MenuEntry) -> String {
    match &entry.hint {
        // Win32 菜单会把 Tab 后面的文本右对齐显示，但不会注册成快捷键。
        Some(hint) => format!("{}\t{}", entry.title, hint),
        None => entry.title.clone(),
    }
}

fn append_entries(parent: &MenuParent, entries: &[MenuEntry]) {
    for entry in entries {
        match &entry.kind {
            MenuEntryKind::Separator => {
                parent.append(&PredefinedMenuItem::separator());
            }
            MenuEntryKind::Item { path, enabled } => {
                parent.append(&MenuItem::with_id(
                    MenuId::new(path),
                    item_text(entry),
                    *enabled,
                    None,
                ));
            }
            MenuEntryKind::Submenu(children) => {
                let submenu = Submenu::new(&entry.title, true);
                append_entries(&MenuParent::Submenu(&submenu), children);
                parent.append(&submenu);
            }
        }
    }
}

fn build_menu(entries: &[MenuEntry]) -> Menu {
    let menu = Menu::new();
    append_entries(&MenuParent::Menu(&menu), entries);
    menu
}

fn menu_theme(theme: Option<Theme>) -> MenuTheme {
    match theme {
        Some(Theme::Dark) => MenuTheme::Dark,
        Some(Theme::Light) => MenuTheme::Light,
        None => MenuTheme::Auto,
    }
}

pub fn window_hwnd(window: &Window) -> Option<isize> {
    match window.window_handle().ok()?.as_raw() {
        RawWindowHandle::Win32(handle) => Some(handle.hwnd.get()),
        _ => None,
    }
}

/// 一个窗口上的菜单栏。
pub struct Menubar {
    menu: Menu,
    hwnd: isize,
    theme: MenuTheme,
    visible: bool,
}

impl fmt::Debug for Menubar {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Menubar").field("hwnd", &self.hwnd).field("visible", &self.visible).finish()
    }
}

impl Menubar {
    pub fn attach(
        window: &Window,
        entries: &[MenuEntry],
        theme: Option<Theme>,
        visible: bool,
    ) -> Option<Self> {
        let hwnd = window_hwnd(window)?;
        let theme = menu_theme(theme);
        let menu = build_menu(entries);

        // SAFETY: hwnd 来自当前窗口，且调用发生在窗口所属的 UI 线程。
        if let Err(error) = unsafe { menu.init_for_hwnd_with_theme(hwnd, theme) } {
            warn!("Failed to attach menu bar: {error}");
            return None;
        }

        // 让 Alt 键只发给 nvim：屏蔽单按 Alt / F10 激活菜单栏的系统行为。
        install_alt_filter(hwnd);

        let mut menubar = Self { menu, hwnd, theme, visible: true };
        menubar.set_visible(visible);
        Some(menubar)
    }

    /// 用新的菜单树替换当前菜单（`neovide.refresh_menu()` 触发）。
    pub fn rebuild(&mut self, entries: &[MenuEntry]) {
        let was_visible = self.visible;

        // SAFETY: hwnd 仍然有效（窗口关闭时整个 Route 会被移除）。
        unsafe {
            if let Err(error) = self.menu.remove_for_hwnd(self.hwnd) {
                warn!("Failed to detach old menu bar: {error}");
            }
        }

        let menu = build_menu(entries);
        // SAFETY: 同上。
        if let Err(error) = unsafe { menu.init_for_hwnd_with_theme(self.hwnd, self.theme) } {
            warn!("Failed to re-attach menu bar: {error}");
            return;
        }
        self.menu = menu;

        // init_for_hwnd 会把菜单显示出来，这里按重建前的状态重新收敛一次。
        self.visible = true;
        self.set_visible(was_visible);
    }

    pub fn set_visible(&mut self, visible: bool) {
        if self.visible == visible {
            return;
        }

        // SAFETY: hwnd 仍然有效。
        let result = unsafe {
            if visible {
                self.menu.show_for_hwnd(self.hwnd)
            } else {
                self.menu.hide_for_hwnd(self.hwnd)
            }
        };
        if let Err(error) = result {
            warn!("Failed to change menu bar visibility: {error}");
            return;
        }
        self.visible = visible;
    }

    pub fn set_theme(&mut self, theme: Option<Theme>) {
        let theme = menu_theme(theme);
        if theme == self.theme {
            return;
        }

        // SAFETY: hwnd 仍然有效。
        if let Err(error) = unsafe { self.menu.set_theme_for_hwnd(self.hwnd, theme) } {
            warn!("Failed to change menu bar theme: {error}");
            return;
        }
        self.theme = theme;
    }
}

/// 全局菜单事件回调：把点击到的菜单路径送进 winit 事件循环。
/// `MenuEvent::set_event_handler` 只能成功设置一次，所以由 `Application::new` 调用。
pub fn set_event_handler(proxy: Arc<std::sync::Mutex<EventLoopProxy<EventPayload>>>) {
    MenuEvent::set_event_handler(Some(move |event: MenuEvent| {
        let path = event.id().0.clone();
        if let Ok(proxy) = proxy.lock() {
            let _ = proxy.send_event(EventPayload::all(UserEvent::MenuCommand(path)));
        }
    }));
}

extern "system" fn alt_filter_proc(
    hwnd: HWND,
    msg: u32,
    wparam: WPARAM,
    lparam: LPARAM,
    _uidsubclass: usize,
    _dwrefdata: usize,
) -> LRESULT {
    match msg {
        // 单按 Alt / F10 会发 SC_KEYMENU，转交给系统会进入菜单模式并吞掉按键。
        WM_SYSCOMMAND if (wparam.0 as u32 & 0xFFF0) == SC_KEYMENU => LRESULT(0),
        // Alt+字母 的 mnemonic 处理也在这里拦掉；AltGr（Ctrl+Alt）要放行，
        // 否则某些键盘布局的字符输入会失效。
        WM_SYSCHAR if (unsafe { GetKeyState(VK_CONTROL.0 as i32) } as u16 & 0x8000) == 0 => {
            LRESULT(0)
        }
        // SAFETY: 其他消息继续交给后续子类与 winit 的窗口过程。
        _ => unsafe { DefSubclassProc(hwnd, msg, wparam, lparam) },
    }
}

fn install_alt_filter(hwnd: isize) {
    // SAFETY: hwnd 有效；子类过程在窗口销毁时由系统自动移除。
    let installed = unsafe {
        SetWindowSubclass(HWND(hwnd as *mut _), Some(alt_filter_proc), ALT_FILTER_SUBCLASS_ID, 0)
    };
    if !installed.as_bool() {
        warn!("Failed to install Alt key filter for menu bar");
    }
}
// [CUSTOM-END] CUSTOM-20261025-001
