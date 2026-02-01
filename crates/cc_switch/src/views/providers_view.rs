//! Providers view component
//!
//! Displays and manages AI provider configurations.

use std::sync::Arc;

use gpui::{
    AnyElement, App, Corner, IntoElement, ParentElement, Render, SharedString, Styled, Window, div,
};
use i18n::t;
use ui::{
    Button, ButtonStyle, ContextMenu, Divider, DividerColor, ElevationIndex, IconButton,
    IconButtonShape, ListItem, PopoverMenu, Tooltip, prelude::*,
};

use crate::{CcSwitchConfig, Provider, ProviderId};

pub type SwitchCallback = Arc<dyn Fn(ProviderId, &mut Window, &mut App) + Send + Sync>;
pub type AddCallback = Arc<dyn Fn(&mut Window, &mut App) + Send + Sync>;
pub type EditCallback = Arc<dyn Fn(ProviderId, &mut Window, &mut App) + Send + Sync>;
pub type DeleteCallback = Arc<dyn Fn(ProviderId, &mut Window, &mut App) + Send + Sync>;

/// View for displaying provider list
pub struct ProvidersView {
    config: CcSwitchConfig,
    on_switch: Option<SwitchCallback>,
    on_add: Option<AddCallback>,
    on_edit: Option<EditCallback>,
    on_delete: Option<DeleteCallback>,
}

impl ProvidersView {
    pub fn new(config: CcSwitchConfig) -> Self {
        Self {
            config,
            on_switch: None,
            on_add: None,
            on_edit: None,
            on_delete: None,
        }
    }

    pub fn on_switch(
        mut self,
        callback: impl Fn(ProviderId, &mut Window, &mut App) + Send + Sync + 'static,
    ) -> Self {
        self.on_switch = Some(Arc::new(callback));
        self
    }

    pub fn on_add(mut self, callback: impl Fn(&mut Window, &mut App) + Send + Sync + 'static) -> Self {
        self.on_add = Some(Arc::new(callback));
        self
    }

    pub fn on_edit(
        mut self,
        callback: impl Fn(ProviderId, &mut Window, &mut App) + Send + Sync + 'static,
    ) -> Self {
        self.on_edit = Some(Arc::new(callback));
        self
    }

    pub fn on_delete(
        mut self,
        callback: impl Fn(ProviderId, &mut Window, &mut App) + Send + Sync + 'static,
    ) -> Self {
        self.on_delete = Some(Arc::new(callback));
        self
    }

    /// Get the currently active provider
    fn current_provider(&self) -> Option<&Provider> {
        self.config.current_provider()
    }

    /// Render the current provider section header
    fn render_current_provider_section(&self, cx: &App) -> impl IntoElement {
        let current = self.current_provider();

        v_flex()
            .w_full()
            .p_2()
            .gap_1()
            .child(
                h_flex().w_full().justify_between().child(
                    Label::new(t("cc-active-provider"))
                        .size(LabelSize::Small)
                        .color(Color::Muted),
                ),
            )
            .child(
                h_flex().w_full().gap_2().child(match &current {
                    Some(provider) => h_flex()
                        .gap_2()
                        .child(self.render_provider_icon(provider, cx))
                        .child(Label::new(provider.name.clone()).weight(gpui::FontWeight::MEDIUM)),
                    None => h_flex().child(Label::new(t("cc-no-provider")).color(Color::Muted)),
                }),
            )
            .child(
                div()
                    .pt_2()
                    .child(Divider::horizontal().color(DividerColor::Border)),
            )
    }

    /// Render a provider icon based on provider.icon field
    fn render_provider_icon(&self, provider: &Provider, _cx: &App) -> impl IntoElement {
        let icon_name = match provider.icon.as_deref() {
            Some("openai") => IconName::AiOpenAi,
            Some("anthropic") => IconName::AiAnthropic,
            Some("google") => IconName::AiGoogle,
            Some("azure") => IconName::AiBedrock, // Closest available icon
            Some("ollama") => IconName::AiOllama,
            _ => IconName::Sparkle,
        };

        Icon::new(icon_name)
            .size(IconSize::Small)
            .color(Color::Muted)
    }

    /// Render the provider list section
    fn render_provider_list(&self, cx: &App) -> impl IntoElement {
        let providers = self.config.providers_sorted();
        let current_id = self.config.current_provider.as_ref();

        v_flex()
            .w_full()
            .gap_0p5()
            .p_1()
            .child(
                h_flex().px_1().child(
                    Label::new(t("cc-all-providers"))
                        .size(LabelSize::Small)
                        .color(Color::Muted),
                ),
            )
            .children(providers.into_iter().map(|provider| {
                let is_current = current_id.map_or(false, |id| id == &provider.id);
                self.render_provider_item(provider, is_current, cx)
            }))
    }

    /// Render a single provider list item
    fn render_provider_item(
        &self,
        provider: &Provider,
        is_current: bool,
        cx: &App,
    ) -> impl IntoElement {
        let provider_id = provider.id.clone();
        let provider_name = provider.name.clone();
        let on_switch = self.on_switch.clone();

        ListItem::new(SharedString::from(format!("provider-{}", provider_id)))
            .inset(true)
            .spacing(ui::ListItemSpacing::Dense)
            .toggle_state(is_current)
            .start_slot(self.render_provider_icon(provider, cx))
            .child(
                h_flex()
                    .w_full()
                    .gap_1()
                    .child(Label::new(provider_name.clone()))
                    .when(is_current, |this| {
                        this.child(
                            Icon::new(IconName::Check)
                                .size(IconSize::Small)
                                .color(Color::Success),
                        )
                    }),
            )
            .end_hover_slot(self.render_provider_menu(&provider_id, &provider_name, cx))
            .on_click({
                let provider_id = provider_id.clone();
                move |_, window, cx| {
                    if let Some(callback) = &on_switch {
                        callback(provider_id.clone(), window, cx);
                    }
                }
            })
    }

    /// Render the popover menu for a provider
    fn render_provider_menu(
        &self,
        provider_id: &ProviderId,
        _provider_name: &str,
        _cx: &App,
    ) -> impl IntoElement {
        let provider_id = provider_id.clone();
        let on_edit = self.on_edit.clone();
        let on_delete = self.on_delete.clone();

        PopoverMenu::new(SharedString::from(format!("provider-menu-{}", provider_id)))
            .trigger(
                IconButton::new(
                    SharedString::from(format!("provider-menu-btn-{}", provider_id)),
                    IconName::Ellipsis,
                )
                .icon_size(IconSize::Small)
                .shape(IconButtonShape::Square)
                .tooltip(Tooltip::text(t("cc-more-options"))),
            )
            .anchor(Corner::TopRight)
            .menu(move |window, cx| {
                let provider_id = provider_id.clone();
                let on_edit = on_edit.clone();
                let on_delete = on_delete.clone();

                Some(ContextMenu::build(window, cx, move |menu, _window, _cx| {
                    let provider_id = provider_id.clone();
                    let on_edit = on_edit.clone();
                    let on_delete = on_delete.clone();

                    menu.entry(&t("edit"), None, {
                        let provider_id = provider_id.clone();
                        let on_edit = on_edit.clone();
                        move |window, cx| {
                            if let Some(callback) = &on_edit {
                                callback(provider_id.clone(), window, cx);
                            }
                        }
                    })
                    .entry(&t("cc-duplicate"), None, {
                        let _provider_id = provider_id.clone();
                        move |_window, _cx| {
                            log::debug!("Duplicate provider: {}", _provider_id);
                        }
                    })
                    .separator()
                    .entry(&t("delete"), None, {
                        let provider_id = provider_id.clone();
                        let on_delete = on_delete.clone();
                        move |window, cx| {
                            if let Some(callback) = &on_delete {
                                callback(provider_id.clone(), window, cx);
                            }
                        }
                    })
                }))
            })
    }

    /// Render the add provider button
    fn render_add_button(&self, _cx: &App) -> impl IntoElement {
        let on_add = self.on_add.clone();

        div().w_full().p_2().child(
            Button::new("add-provider", t("cc-add-provider"))
                .full_width()
                .style(ButtonStyle::Outlined)
                .layer(ElevationIndex::Surface)
                .icon(IconName::Plus)
                .icon_position(IconPosition::Start)
                .icon_size(IconSize::Small)
                .icon_color(Color::Muted)
                .label_size(LabelSize::Small)
                .on_click(move |_, window, cx| {
                    if let Some(callback) = &on_add {
                        callback(window, cx);
                    }
                }),
        )
    }

    /// Main render method called by the panel - accepts generic App context
    pub fn render_content(&self, cx: &App) -> AnyElement {
        v_flex()
            .w_full()
            .h_full()
            .child(self.render_current_provider_section(cx))
            .child(self.render_provider_list(cx))
            .child(div().flex_grow())
            .child(self.render_add_button(cx))
            .into_any_element()
    }
}


impl Render for ProvidersView {
    fn render(&mut self, _window: &mut Window, cx: &mut gpui::Context<Self>) -> impl IntoElement {
        self.render_content(cx)
    }
}
