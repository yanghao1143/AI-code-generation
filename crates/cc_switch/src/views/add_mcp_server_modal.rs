//! Modal for adding or editing an MCP server configuration

use anyhow::Result;
use gpui::{
    DismissEvent, Entity, EventEmitter, FocusHandle, Focusable, Render, ScrollHandle,
};
use i18n::t;
use menu;
use serde_json::json;
use std::collections::HashMap;
use ui::{
    Button, ButtonStyle, IconButton, IconName, Label, Modal, ModalFooter, ModalHeader, prelude::*,
};
use ui_input::InputField;
use workspace::ModalView;

use crate::{AppType, McpApps, McpServer, McpServerId};

pub struct AddMcpServerModal {
    focus_handle: FocusHandle,
    scroll_handle: ScrollHandle,
    name_input: Entity<InputField>,
    command_input: Entity<InputField>,
    args_input: Entity<InputField>,
    env_inputs: Vec<(Entity<InputField>, Entity<InputField>)>,
    id: Option<McpServerId>,
    on_confirm: Box<dyn Fn(McpServer, &mut Window, &mut App) + 'static>,
}

impl AddMcpServerModal {
    pub fn new(
        window: &mut Window,
        cx: &mut Context<Self>,
        server: Option<McpServer>,
        on_confirm: impl Fn(McpServer, &mut Window, &mut App) + 'static,
    ) -> Self {
        let name_text = server.as_ref().map(|s| s.name.clone()).unwrap_or_default();
        let command_text = server
            .as_ref()
            .and_then(|s| s.server.get("command"))
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string();
        let args_text = server
            .as_ref()
            .and_then(|s| s.server.get("args"))
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(|v| v.as_str())
                    .collect::<Vec<_>>()
                    .join(" ")
            })
            .unwrap_or_default();

        let mut env_inputs = Vec::new();
        if let Some(env_map) = server.as_ref().and_then(|s| s.server.get("env")).and_then(|v| v.as_object()) {
            for (k, v) in env_map {
                let val_str = v.as_str().unwrap_or("").to_string();
                let key_input = cx.new(|cx| InputField::new(window, cx, &t("key")).tab_index(4));
                key_input.update(cx, |input, cx| input.set_text(k, window, cx));

                let val_input = cx.new(|cx| InputField::new(window, cx, &t("value")).tab_index(5));
                val_input.update(cx, |input, cx| input.set_text(&val_str, window, cx));

                env_inputs.push((key_input, val_input));
            }
        }

        let name_input = cx.new(|cx| {
            InputField::new(window, cx, &t("cc-server-name-placeholder"))
                .label(&t("name"))
                .tab_index(1)
        });
        name_input.update(cx, |input, cx| input.set_text(&name_text, window, cx));

        let command_input = cx.new(|cx| {
            InputField::new(window, cx, &t("cc-command-placeholder"))
                .label(&t("command"))
                .tab_index(2)
        });
        command_input.update(cx, |input, cx| input.set_text(&command_text, window, cx));

        let args_input = cx.new(|cx| {
            InputField::new(window, cx, &t("cc-arguments-placeholder"))
                .label(&t("arguments"))
                .tab_index(3)
        });
        args_input.update(cx, |input, cx| input.set_text(&args_text, window, cx));

        Self {
            focus_handle: cx.focus_handle(),
            scroll_handle: ScrollHandle::new(),
            name_input,
            command_input,
            args_input,
            env_inputs,
            id: server.map(|s| s.id),
            on_confirm: Box::new(on_confirm),
        }
    }

    fn add_env_var(&mut self, window: &mut Window, cx: &mut Context<Self>) {
        let key_input = cx.new(|cx| InputField::new(window, cx, &t("key")).tab_index(4));
        let val_input = cx.new(|cx| InputField::new(window, cx, &t("value")).tab_index(5));
        self.env_inputs.push((key_input, val_input));
        cx.notify();
    }

    fn remove_env_var(&mut self, index: usize, cx: &mut Context<Self>) {
        if index < self.env_inputs.len() {
            self.env_inputs.remove(index);
            cx.notify();
        }
    }

    fn confirm(&mut self, _: &menu::Confirm, window: &mut Window, cx: &mut Context<Self>) {
        let name = self.name_input.read(cx).text(cx);
        let command = self.command_input.read(cx).text(cx);
        let args_str = self.args_input.read(cx).text(cx);

        if name.is_empty() || command.is_empty() {
            return;
        }

        let args: Vec<String> = args_str
            .split_whitespace()
            .map(|s| s.to_string())
            .collect();

        let mut env_map = HashMap::new();
        for (k_input, v_input) in &self.env_inputs {
            let key = k_input.read(cx).text(cx);
            let val = v_input.read(cx).text(cx);
            if !key.is_empty() {
                env_map.insert(key, val);
            }
        }

        let id = self.id.clone().unwrap_or_else(|| {
            name.to_lowercase()
                .chars()
                .filter(|c| c.is_alphanumeric() || *c == '-' || *c == '_')
                .collect()
        });

        let mut server_config = json!({
            "type": "stdio",
            "command": command,
            "args": args,
        });

        if !env_map.is_empty() {
            server_config.as_object_mut().unwrap().insert("env".to_string(), json!(env_map));
        }

        let mcp_server = McpServer {
            id,
            name,
            server: server_config,
            apps: McpApps::all_enabled(),
            description: None,
            homepage: None,
            docs: None,
            tags: Vec::new(),
            sort_index: None,
        };

        (self.on_confirm)(mcp_server, window, cx);
        cx.emit(DismissEvent);
    }

    fn cancel(&mut self, _: &menu::Cancel, _: &mut Window, cx: &mut Context<Self>) {
        cx.emit(DismissEvent);
    }
}

impl EventEmitter<DismissEvent> for AddMcpServerModal {}

impl Focusable for AddMcpServerModal {
    fn focus_handle(&self, _cx: &App) -> FocusHandle {
        self.focus_handle.clone()
    }
}

impl ModalView for AddMcpServerModal {}

impl Render for AddMcpServerModal {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let env_rows = self.env_inputs.iter().enumerate().map(|(ix, (k, v))| {
            h_flex()
                .gap_2()
                .child(k.clone())
                .child(v.clone())
                .child(
                    IconButton::new("remove-env", IconName::Trash)
                        .icon_size(IconSize::Small)
                        .on_click(cx.listener(move |this, _, _, cx| {
                            this.remove_env_var(ix, cx);
                        }))
                )
        }).collect::<Vec<_>>();

        v_flex()
            .id("add-mcp-server-modal")
            .w(rems(30.))
            .elevation_3(cx)
            .on_action(cx.listener(Self::confirm))
            .on_action(cx.listener(Self::cancel))
            .child(
                Modal::new("add-mcp-server", None)
                    .header(
                        ModalHeader::new().headline(if self.id.is_some() {
                            t("cc-edit-mcp-server")
                        } else {
                            t("cc-add-mcp-server")
                        }),
                    )
                    .child(
                        v_flex()
                            .p_4()
                            .gap_4()
                            .child(self.name_input.clone())
                            .child(self.command_input.clone())
                            .child(self.args_input.clone())
                            .child(
                                v_flex()
                                    .gap_2()
                                    .child(
                                        h_flex()
                                            .justify_between()
                                            .child(Label::new(t("cc-environment-variables")).size(LabelSize::Small))
                                            .child(
                                                Button::new("add-env", t("cc-add-env-var"))
                                                    .icon(IconName::Plus)
                                                    .style(ButtonStyle::Subtle)
                                                    .on_click(cx.listener(|this, _, window, cx| {
                                                        this.add_env_var(window, cx);
                                                    }))
                                            )
                                    )
                                    .children(env_rows)
                            ),
                    )
                    .footer(
                        ModalFooter::new().end_slot(
                            h_flex()
                                .gap_2()
                                .child(
                                    Button::new("cancel", t("cancel")).on_click(cx.listener(|this, _, window, cx| {
                                        this.cancel(&menu::Cancel, window, cx);
                                    })),
                                )
                                .child(
                                    Button::new("confirm", t("confirm"))
                                        .style(ButtonStyle::Filled)
                                        .on_click(cx.listener(|this, _, window, cx| {
                                            this.confirm(&menu::Confirm, window, cx);
                                        })),
                                ),
                        ),
                    ),
            )
    }
}
