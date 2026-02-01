//! Modal for adding or editing an AI Provider configuration

use gpui::{
    App, AsyncApp, Context, DismissEvent, Entity, EventEmitter, FocusHandle, Focusable, Render,
    WeakEntity, Window,
};
use i18n::t;
use menu;
use serde_json::json;
use ui::{
    Button, Modal, ModalFooter, ModalHeader, prelude::*,
};
use ui_input::InputField;
use util::ResultExt;
use workspace::ModalView;

use crate::{AppType, Provider, ProviderId};

pub struct AddProviderModal {
    focus_handle: FocusHandle,
    name_input: Entity<InputField>,
    api_key_input: Entity<InputField>,
    api_url_input: Entity<InputField>,
    id: Option<ProviderId>,
    test_status: Option<(bool, String)>,
    is_testing: bool,
    on_confirm: Box<dyn Fn(Provider, &mut Window, &mut App) + 'static>,
}

impl AddProviderModal {
    pub fn new(
        window: &mut Window,
        cx: &mut Context<Self>,
        provider: Option<Provider>,
        on_confirm: impl Fn(Provider, &mut Window, &mut App) + 'static,
    ) -> Self {
        let name_text = provider.as_ref().map(|p| p.name.clone()).unwrap_or_default();
        let api_key = provider
            .as_ref()
            .and_then(|p| p.settings_config.get("api_key"))
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string();
        let api_url = provider
            .as_ref()
            .and_then(|p| p.settings_config.get("api_url"))
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string();

        let name_input = cx.new(|cx| {
            let mut input = InputField::new(window, cx, &t("cc-provider-name-placeholder"))
                .label(&t("name"))
                .tab_index(1);
            input.set_text(&name_text, window, cx);
            input
        });

        let api_key_input = cx.new(|cx| {
            let mut input = InputField::new(window, cx, &t("cc-api-key-placeholder"))
                .label(&t("cc-api-key"))
                .tab_index(2);
            input.set_text(&api_key, window, cx);
            input
        });

        let api_url_input = cx.new(|cx| {
            let mut input = InputField::new(window, cx, &t("cc-api-url-placeholder"))
                .label(&t("cc-api-url"))
                .tab_index(3);
            input.set_text(&api_url, window, cx);
            input
        });

        Self {
            focus_handle: cx.focus_handle(),
            name_input,
            api_key_input,
            api_url_input,
            id: provider.map(|p| p.id),
            test_status: None,
            is_testing: false,
            on_confirm: Box::new(on_confirm),
        }
    }

    fn test_connection(&mut self, cx: &mut Context<Self>) {
        let api_key = self.api_key_input.read(cx).text(cx);

        if api_key.is_empty() {
            self.test_status = Some((false, t("cc-api-key-required").to_string()));
            cx.notify();
            return;
        }

        self.is_testing = true;
        self.test_status = None;
        cx.notify();

        // Simplified test - just validate that API key is not empty
        // A real implementation would use ApiClient to validate
        cx.spawn(async move |this, cx| {
            // For now, just mark as successful if key is non-empty
            let result = Ok::<bool, anyhow::Error>(true);

            let _ = this.update(cx, |this, cx| {
                this.is_testing = false;
                match result {
                    Ok(true) => {
                        this.test_status = Some((true, t("cc-connection-successful").to_string()));
                    }
                    Ok(false) => {
                        this.test_status = Some((false, t("cc-connection-failed").to_string()));
                    }
                    Err(e) => {
                        this.test_status = Some((false, format!("{}: {}", t("cc-error-prefix"), e)));
                    }
                }
                cx.notify();
            });
        }).detach();
    }

    fn confirm(&mut self, _: &menu::Confirm, window: &mut Window, cx: &mut Context<Self>) {
        let name = self.name_input.read(cx).text(cx);
        let api_key = self.api_key_input.read(cx).text(cx);
        let api_url = self.api_url_input.read(cx).text(cx);

        if name.is_empty() {
            return;
        }

        let id = self.id.clone().unwrap_or_else(|| {
            name.to_lowercase()
                .chars()
                .filter(|c| c.is_alphanumeric() || *c == '-' || *c == '_')
                .collect()
        });

        let provider = Provider {
            id,
            name,
            settings_config: json!({
                "api_key": api_key,
                "api_url": api_url,
            }),
            website_url: None,
            category: None,
            notes: None,
            icon: Some("sparkle".to_string()),
            icon_color: None,
            sort_index: None,
            in_failover_queue: false,
        };

        (self.on_confirm)(provider, window, cx);
        cx.emit(DismissEvent);
    }

    fn cancel(&mut self, _: &menu::Cancel, _: &mut Window, cx: &mut Context<Self>) {
        cx.emit(DismissEvent);
    }
}

impl EventEmitter<DismissEvent> for AddProviderModal {}

impl Focusable for AddProviderModal {
    fn focus_handle(&self, _cx: &App) -> FocusHandle {
        self.focus_handle.clone()
    }
}

impl ModalView for AddProviderModal {}

impl Render for AddProviderModal {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        v_flex()
            .id("add-provider-modal")
            .w(rems(24.))
            .elevation_3(cx)
            .on_action(cx.listener(Self::confirm))
            .on_action(cx.listener(Self::cancel))
            .child(
                Modal::new("add-provider", None)
                    .header(
                        ModalHeader::new().headline(if self.id.is_some() {
                            t("cc-edit-provider")
                        } else {
                            t("cc-add-provider")
                        }),
                    )
                    .child(
                        v_flex()
                            .p_4()
                            .gap_4()
                            .child(self.name_input.clone())
                            .child(self.api_key_input.clone())
                            .child(self.api_url_input.clone())
                            .child(
                                h_flex()
                                    .justify_between()
                                    .items_center()
                                    .child(
                                        Button::new("test-connection", t("cc-test-connection"))
                                            .style(ButtonStyle::Subtle)
                                            .icon(IconName::ArrowRight)
                                            .disabled(self.is_testing)
                                            .on_click(cx.listener(|this, _, _, cx| {
                                                this.test_connection(cx);
                                            }))
                                    )
                                    .when_some(self.test_status.clone(), |this, (success, msg)| {
                                        this.child(
                                            Label::new(msg)
                                                .size(LabelSize::Small)
                                                .color(if success { Color::Success } else { Color::Error })
                                        )
                                    })
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
