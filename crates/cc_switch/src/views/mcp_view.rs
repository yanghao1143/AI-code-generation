//! MCP servers view component
//!
//! Displays and manages MCP server configurations with drag-drop reordering
//! and per-app toggles.

use std::sync::Arc;

use gpui::{AnyElement, App, Context, Pixels, Render, Window};
use i18n::t;
use settings::Settings;
use theme::ThemeSettings;
use ui::{ContextMenu, PopoverMenu, Tooltip, prelude::*};

use crate::{AppType, McpServer, McpServerId};

/// Data for drag-drop operations
#[derive(Clone)]
pub struct McpDragItem {
    pub id: McpServerId,
    pub name: String,
}

/// Visual representation during drag operation
pub struct DraggedMcpServerView {
    name: String,
    width: Pixels,
}

impl Render for DraggedMcpServerView {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let ui_font = ThemeSettings::get_global(cx).ui_font.family.clone();
        h_flex()
            .font_family(ui_font)
            .bg(cx.theme().colors().background)
            .w(self.width)
            .p_1()
            .gap_1()
            .shadow_md()
            .rounded_sm()
            .child(
                Icon::new(IconName::Server)
                    .size(IconSize::Small)
                    .color(Color::Muted),
            )
            .child(Label::new(self.name.clone()).size(LabelSize::Small))
    }
}

pub type ReorderCallback = Arc<dyn Fn(McpServerId, McpServerId, &mut Window, &mut App) + Send + Sync>;
pub type ToggleAppCallback = Arc<dyn Fn(McpServerId, AppType, bool, &mut Window, &mut App) + Send + Sync>;
pub type AddCallback = Arc<dyn Fn(&mut Window, &mut App) + Send + Sync>;
pub type EditCallback = Arc<dyn Fn(McpServerId, &mut Window, &mut App) + Send + Sync>;
pub type DeleteCallback = Arc<dyn Fn(McpServerId, &mut Window, &mut App) + Send + Sync>;

/// View for displaying MCP server list with drag-drop reordering
pub struct McpView {
    servers: Vec<McpServer>,
    dragging: Option<McpServerId>,
    width: Pixels,
    on_reorder: Option<ReorderCallback>,
    on_toggle_app: Option<ToggleAppCallback>,
    on_add: Option<AddCallback>,
    on_edit: Option<EditCallback>,
    on_delete: Option<DeleteCallback>,
}

impl McpView {
    pub fn new(servers: Vec<McpServer>) -> Self {
        Self {
            servers,
            dragging: None,
            width: px(280.),
            on_reorder: None,
            on_toggle_app: None,
            on_add: None,
            on_edit: None,
            on_delete: None,
        }
    }

    pub fn update_servers(&mut self, servers: Vec<McpServer>) {
        self.servers = servers;
    }

    pub fn set_width(&mut self, width: Pixels) {
        self.width = width;
    }

    pub fn on_reorder(
        mut self,
        callback: impl Fn(McpServerId, McpServerId, &mut Window, &mut App) + Send + Sync + 'static,
    ) -> Self {
        self.on_reorder = Some(Arc::new(callback));
        self
    }

    pub fn on_toggle_app(
        mut self,
        callback: impl Fn(McpServerId, AppType, bool, &mut Window, &mut App) + Send + Sync + 'static,
    ) -> Self {
        self.on_toggle_app = Some(Arc::new(callback));
        self
    }

    pub fn on_add(mut self, callback: impl Fn(&mut Window, &mut App) + Send + Sync + 'static) -> Self {
        self.on_add = Some(Arc::new(callback));
        self
    }

    pub fn on_edit(
        mut self,
        callback: impl Fn(McpServerId, &mut Window, &mut App) + Send + Sync + 'static,
    ) -> Self {
        self.on_edit = Some(Arc::new(callback));
        self
    }

    pub fn on_delete(
        mut self,
        callback: impl Fn(McpServerId, &mut Window, &mut App) + Send + Sync + 'static,
    ) -> Self {
        self.on_delete = Some(Arc::new(callback));
        self
    }

    fn reorder_mcp_server(&self, from_id: &McpServerId, to_id: &McpServerId, window: &mut Window, cx: &mut App) {
        if let Some(callback) = &self.on_reorder {
            callback(from_id.clone(), to_id.clone(), window, cx);
        }
    }

    fn render_header(&self, cx: &App) -> impl IntoElement {
        let on_add = self.on_add.clone();

        h_flex()
            .w_full()
            .justify_between()
            .px_2()
            .py_1()
            .border_b_1()
            .border_color(cx.theme().colors().border)
            .child(
                h_flex()
                    .gap_1()
                    .child(
                        Icon::new(IconName::Server)
                            .size(IconSize::Small)
                            .color(Color::Muted),
                    )
                    .child(
                        Label::new(t("cc-mcp-servers"))
                            .size(LabelSize::Small)
                            .color(Color::Muted),
                    ),
            )
            .child(
                IconButton::new("add-mcp-server", IconName::Plus)
                    .icon_size(IconSize::Small)
                    .style(ButtonStyle::Subtle)
                    .tooltip(Tooltip::text(t("cc-add-mcp-server")))
                    .on_click(move |_, window, cx| {
                        if let Some(callback) = &on_add {
                            callback(window, cx);
                        }
                    }),
            )
    }

    fn render_app_toggle(
        &self,
        server_id: &McpServerId,
        app: AppType,
        enabled: bool,
        cx: &App,
    ) -> impl IntoElement {
        let label = match app {
            AppType::Claude => "C",
            AppType::Codex => "X",
            AppType::Gemini => "G",
            AppType::OpenCode => "O",
        };

        let tooltip_text = format!(
            "{} for {}",
            if enabled { t("disable") } else { t("enable") },
            app.display_name()
        );

        let server_id = server_id.clone();
        let on_toggle_app = self.on_toggle_app.clone();

        div()
            .id(SharedString::from(format!(
                "app-toggle-{}-{}",
                server_id,
                app.as_str()
            )))
            .w_5()
            .h_5()
            .flex()
            .justify_center()
            .items_center()
            .rounded_sm()
            .cursor_pointer()
            .border_1()
            .when(enabled, |this| {
                this.bg(cx.theme().colors().element_selected)
                    .border_color(cx.theme().colors().border_focused)
            })
            .when(!enabled, |this| {
                this.bg(cx.theme().colors().element_background)
                    .border_color(cx.theme().colors().border)
            })
            .hover(|style| style.bg(cx.theme().colors().element_hover))
            .child(Label::new(label).size(LabelSize::XSmall).color(if enabled {
                Color::Default
            } else {
                Color::Muted
            }))
            .tooltip(move |window, cx| (Tooltip::text(tooltip_text.clone()))(window, cx))
            .on_click(move |_, window, cx| {
                if let Some(callback) = &on_toggle_app {
                    callback(server_id.clone(), app, !enabled, window, cx);
                }
            })
    }

    fn render_app_toggles(&self, server: &McpServer, cx: &App) -> impl IntoElement {
        h_flex()
            .gap_0p5()
            .child(self.render_app_toggle(&server.id, AppType::Claude, server.apps.claude, cx))
            .child(self.render_app_toggle(&server.id, AppType::Codex, server.apps.codex, cx))
            .child(self.render_app_toggle(&server.id, AppType::Gemini, server.apps.gemini, cx))
            .child(self.render_app_toggle(&server.id, AppType::OpenCode, server.apps.opencode, cx))
    }

    // Note: render_server_item with drag-drop and context menu removed due to GPUI API incompatibility
    // Using render_server_item_simple instead

    fn render_empty_state(&self, cx: &App) -> impl IntoElement {
        let on_add = self.on_add.clone();

        v_flex()
            .w_full()
            .p_4()
            .gap_2()
            .items_center()
            .child(
                Icon::new(IconName::Server)
                    .size(IconSize::Medium)
                    .color(Color::Muted),
            )
            .child(Label::new(t("cc-no-mcp-servers")).color(Color::Muted))
            .child(
                Button::new("add-first-mcp", t("cc-add-mcp-server"))
                    .style(ButtonStyle::Filled)
                    .on_click(move |_, window, cx| {
                        if let Some(callback) = &on_add {
                            callback(window, cx);
                        }
                    }),
            )
    }

    /// Simplified server item render without context menu (for non-Entity usage)
    fn render_server_item_simple(
        &self,
        server: &McpServer,
        on_edit: Option<EditCallback>,
        on_delete: Option<DeleteCallback>,
        cx: &App,
    ) -> impl IntoElement {
        let server_id = server.id.clone();
        let server_name = server.name.clone();
        let description = server.description.clone();
        let tags: Vec<String> = server.tags.clone();
        let env_count = server
            .server
            .get("env")
            .and_then(|v| v.as_object())
            .map(|o| o.len())
            .unwrap_or(0);
        let edit_server_id = server_id.clone();
        let delete_server_id = server_id.clone();

        div()
            .id(SharedString::from(format!("mcp-server-{}", server_id)))
            .w_full()
            .px_2()
            .py_1()
            .child(
                h_flex()
                    .w_full()
                    .justify_between()
                    .items_start()
                    .gap_2()
                    .rounded_sm()
                    .px_1()
                    .py_1()
                    .hover(|style| style.bg(cx.theme().colors().ghost_element_hover))
                    .child(
                        v_flex()
                            .flex_1()
                            .gap_1()
                            .child(
                                h_flex()
                                    .gap_2()
                                    .child(
                                        Icon::new(IconName::Server)
                                            .size(IconSize::Small)
                                            .color(Color::Muted),
                                    )
                                    .child(
                                        Label::new(server_name)
                                            .size(LabelSize::Small)
                                            .single_line()
                                            .truncate(),
                                    )
                            )
                            .when_some(description, |this, desc| {
                                this.child(
                                    Label::new(desc)
                                        .size(LabelSize::XSmall)
                                        .color(Color::Muted)
                                        .single_line()
                                        .truncate()
                                )
                            })
                            .child(
                                h_flex()
                                    .gap_1()
                                    .flex_wrap()
                                    .when(env_count > 0, |this| {
                                        this.child(
                                            Label::new(format!("{} {}", env_count, t("env")))
                                                .size(LabelSize::XSmall)
                                                .color(Color::Accent)
                                        )
                                    })
                                    .children(tags.into_iter().map(|tag| {
                                        div()
                                            .px_1()
                                            .rounded_sm()
                                            .bg(cx.theme().colors().element_background)
                                            .border_1()
                                            .border_color(cx.theme().colors().border)
                                            .child(
                                                Label::new(tag)
                                                    .size(LabelSize::XSmall)
                                                    .color(Color::Muted)
                                            )
                                    }))
                            )
                    )
                    .child(
                        h_flex()
                            .gap_1()
                            .items_start()
                            .child(self.render_app_toggles(server, cx))
                            .child(
                                IconButton::new("edit-mcp-btn", IconName::Pencil)
                                    .icon_size(IconSize::Small)
                                    .style(ButtonStyle::Subtle)
                                    .on_click(move |_, window, cx| {
                                        if let Some(callback) = &on_edit {
                                            callback(edit_server_id.clone(), window, cx);
                                        }
                                    })
                            )
                            .child(
                                IconButton::new("delete-mcp-btn", IconName::Trash)
                                    .icon_size(IconSize::Small)
                                    .style(ButtonStyle::Subtle)
                                    .on_click(move |_, window, cx| {
                                        if let Some(callback) = &on_delete {
                                            callback(delete_server_id.clone(), window, cx);
                                        }
                                    })
                            ),
                    ),
            )
    }

    /// Main render method - accepts generic App context
    pub fn render_content(&self, cx: &App) -> AnyElement {
        let servers = self.servers.clone();
        let on_edit = self.on_edit.clone();
        let on_delete = self.on_delete.clone();

        div()
            .flex()
            .flex_col()
            .w_full()
            .h_full()
            .child(self.render_header(cx))
            .child(
                div()
                    .id("mcp-server-list")
                    .flex()
                    .flex_col()
                    .flex_1()
                    .overflow_y_scroll()
                    .children(if servers.is_empty() {
                        vec![self.render_empty_state(cx).into_any_element()]
                    } else {
                        servers
                            .iter()
                            .map(|server| self.render_server_item_simple(server, on_edit.clone(), on_delete.clone(), cx).into_any_element())
                            .collect()
                    }),
            )
            .into_any_element()
    }
}

impl Render for McpView {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        self.render_content(cx)
    }
}
