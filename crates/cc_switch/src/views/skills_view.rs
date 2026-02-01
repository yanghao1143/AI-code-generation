//! Skills view component
//!
//! Displays and manages skill configurations with drag-drop reordering
//! and per-app toggle support.

use std::sync::Arc;

use gpui::{
    AnyElement, App, Corner, IntoElement, ParentElement, Render, SharedString, Styled,
    Window, div,
};
use i18n::t;
use ui::{
    Button, ButtonStyle, ContextMenu, Divider, DividerColor, ElevationIndex, IconButton,
    IconButtonShape, Label, ListItem, PopoverMenu, Tooltip, prelude::*,
};

use crate::{AppType, CcSwitchConfig, InstalledSkill, SkillApps, SkillId};

/// Drag item for skill reordering
#[derive(Clone)]
pub struct SkillDragItem(pub SkillId);

/// Visual representation during drag operation
pub struct DraggedSkillView {
    name: String,
}

impl Render for DraggedSkillView {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        h_flex()
            .bg(cx.theme().colors().background)
            .p_2()
            .gap_2()
            .shadow_md()
            .rounded_sm()
            .border_1()
            .border_color(cx.theme().colors().border)
            .child(
                Icon::new(IconName::Sparkle)
                    .size(IconSize::Small)
                    .color(Color::Accent),
            )
            .child(Label::new(self.name.clone()).size(LabelSize::Small))
    }
}

pub type ToggleAppCallback = Arc<dyn Fn(SkillId, AppType, bool, &mut Window, &mut App) + Send + Sync>;
pub type ReorderCallback = Arc<dyn Fn(SkillId, SkillId, &mut Window, &mut App) + Send + Sync>;
pub type InstallCallback = Arc<dyn Fn(&mut Window, &mut App) + Send + Sync>;
pub type UninstallCallback = Arc<dyn Fn(SkillId, &mut Window, &mut App) + Send + Sync>;
pub type ToggleAllAppsCallback = Arc<dyn Fn(SkillId, bool, &mut Window, &mut App) + Send + Sync>;

/// View for displaying skills list with drag-drop reordering
pub struct SkillsView {
    config: CcSwitchConfig,
    on_toggle_app: Option<ToggleAppCallback>,
    on_reorder: Option<ReorderCallback>,
    on_install: Option<InstallCallback>,
    on_uninstall: Option<UninstallCallback>,
    on_toggle_all_apps: Option<ToggleAllAppsCallback>,
}

impl SkillsView {
    pub fn new(config: CcSwitchConfig) -> Self {
        Self {
            config,
            on_toggle_app: None,
            on_reorder: None,
            on_install: None,
            on_uninstall: None,
            on_toggle_all_apps: None,
        }
    }

    pub fn on_toggle_app(
        mut self,
        callback: impl Fn(SkillId, AppType, bool, &mut Window, &mut App) + Send + Sync + 'static,
    ) -> Self {
        self.on_toggle_app = Some(Arc::new(callback));
        self
    }

    pub fn on_toggle_all_apps(
        mut self,
        callback: impl Fn(SkillId, bool, &mut Window, &mut App) + Send + Sync + 'static,
    ) -> Self {
        self.on_toggle_all_apps = Some(Arc::new(callback));
        self
    }

    pub fn on_reorder(
        mut self,
        callback: impl Fn(SkillId, SkillId, &mut Window, &mut App) + Send + Sync + 'static,
    ) -> Self {
        self.on_reorder = Some(Arc::new(callback));
        self
    }

    pub fn on_install(mut self, callback: impl Fn(&mut Window, &mut App) + Send + Sync + 'static) -> Self {
        self.on_install = Some(Arc::new(callback));
        self
    }

    pub fn on_uninstall(
        mut self,
        callback: impl Fn(SkillId, &mut Window, &mut App) + Send + Sync + 'static,
    ) -> Self {
        self.on_uninstall = Some(Arc::new(callback));
        self
    }

    /// Render the header section
    fn render_header(&self, _cx: &App) -> impl IntoElement {
        let on_install = self.on_install.clone();

        h_flex()
            .w_full()
            .justify_between()
            .p_2()
            .child(
                h_flex()
                    .gap_2()
                    .child(
                        Icon::new(IconName::Sparkle)
                            .size(IconSize::Small)
                            .color(Color::Accent),
                    )
                    .child(Label::new(t("cc-skills")).weight(gpui::FontWeight::MEDIUM)),
            )
            .child(
                IconButton::new("install-skill", IconName::Plus)
                    .icon_size(IconSize::Small)
                    .shape(IconButtonShape::Square)
                    .tooltip(Tooltip::text(t("cc-install-skill")))
                    .on_click(move |_, window, cx| {
                        if let Some(callback) = &on_install {
                            callback(window, cx);
                        }
                    }),
            )
    }

    /// Render the skills list
    fn render_skills_list(&self, cx: &App) -> impl IntoElement {
        let skills = self.config.skills_sorted();

        v_flex()
            .w_full()
            .gap_0p5()
            .p_1()
            .when(skills.is_empty(), |this| {
                this.child(
                    div().p_4().child(
                        Label::new(t("cc-no-skills"))
                            .size(LabelSize::Small)
                            .color(Color::Muted),
                    ),
                )
            })
            .when(!skills.is_empty(), |this| {
                this.children(skills.into_iter().map(|skill| {
                    self.render_skill_item(skill, cx)
                }))
            })
    }

    /// Render a single skill item with drag-drop support
    fn render_skill_item(
        &self,
        skill: &InstalledSkill,
        cx: &App,
    ) -> impl IntoElement {
        let skill_id = skill.id.clone();
        let skill_name = skill.name.clone();
        let skill_description = skill.description.clone();
        let skill_apps = skill.apps.clone();
        let drop_target_id = skill_id.clone();
        let on_reorder = self.on_reorder.clone();

        div()
            .id(SharedString::from(format!("skill-drag-{}", skill_id)))
            .w_full()
            // Start drag
            .on_drag(SkillDragItem(skill_id.clone()), move |_drag_item, _, _, cx| {
                // Return a view to represent the dragged item
                cx.new(|_| DraggedSkillView {
                    name: skill_name.clone(),
                })
            })
            // Drag over highlight
            .drag_over::<SkillDragItem>(|style, _, _, cx| {
                style.bg(cx.theme().colors().drop_target_background)
            })
            // Handle drop
            .on_drop({
                let on_reorder = on_reorder.clone();
                move |dragged: &SkillDragItem, window, cx| {
                    if let Some(callback) = &on_reorder {
                        callback(dragged.0.clone(), drop_target_id.clone(), window, cx);
                    }
                }
            })
            .child(
                ListItem::new(SharedString::from(format!("skill-{}", skill_id)))
                    .inset(true)
                    .spacing(ui::ListItemSpacing::Dense)
                    .start_slot(
                        h_flex()
                            .gap_1()
                            // Drag handle indicator
                            .child(
                                Icon::new(IconName::EllipsisVertical)
                                    .size(IconSize::Small)
                                    .color(Color::Muted),
                            )
                            // Skill icon
                            .child(
                                Icon::new(IconName::Sparkle)
                                    .size(IconSize::Small)
                                    .color(Color::Accent),
                            ),
                    )
                    .child(
                        v_flex()
                            .gap_0p5()
                            .child(Label::new(skill.name.clone()))
                            .when_some(skill_description.clone(), |this, desc| {
                                this.child(
                                    Label::new(desc).size(LabelSize::Small).color(Color::Muted),
                                )
                            }),
                    )
                    .end_slot(
                        h_flex()
                            .gap_1()
                            .child(self.render_app_toggles(&skill_apps, &skill_id, cx))
                            .child(self.render_skill_menu(&skill_id, &skill.name, &skill.directory, skill.readme_url.as_deref(), cx)),
                    ),
            )
    }

    /// Render per-app toggle buttons (C, X, G, O)
    fn render_app_toggles(
        &self,
        apps: &SkillApps,
        skill_id: &SkillId,
        cx: &App,
    ) -> impl IntoElement {
        let app_buttons = [
            (AppType::Claude, "C", "Claude"),
            (AppType::Codex, "X", "Codex"),
            (AppType::Gemini, "G", "Gemini"),
            (AppType::OpenCode, "O", "OpenCode"),
        ];

        let skill_id = skill_id.clone();
        let on_toggle_app = self.on_toggle_app.clone();

        h_flex()
            .gap_0p5()
            .children(app_buttons.iter().map(|(app, letter, tooltip_text)| {
                let is_enabled = apps.is_enabled_for(app);
                let skill_id = skill_id.clone();
                let app = *app;
                let on_toggle_app = on_toggle_app.clone();

                div()
                    .id(SharedString::from(format!(
                        "skill-{}-app-{}",
                        skill_id,
                        app.as_str()
                    )))
                    .px_1()
                    .py_0p5()
                    .rounded_sm()
                    .cursor_pointer()
                    .text_size(rems(0.65))
                    .when(is_enabled, |this| {
                        this.bg(cx.theme().colors().element_selected)
                            .text_color(cx.theme().colors().text)
                    })
                    .when(!is_enabled, |this| {
                        this.border_1()
                            .border_color(cx.theme().colors().border)
                            .text_color(cx.theme().colors().text_muted)
                    })
                    .hover(|style| style.bg(cx.theme().colors().element_hover))
                    .child(Label::new(*letter).size(LabelSize::XSmall))
                    .tooltip(Tooltip::text(format!(
                        "{} for {}",
                        if is_enabled { t("disable") } else { t("enable") },
                        tooltip_text
                    )))
                    .on_click(move |_, window, cx| {
                        if let Some(callback) = &on_toggle_app {
                            callback(skill_id.clone(), app, !is_enabled, window, cx);
                        }
                    })
            }))
    }

    /// Render menu button for a skill
    fn render_skill_menu(&self, skill_id: &SkillId, _skill_name: &str, directory: &str, readme_url: Option<&str>, _cx: &App) -> impl IntoElement {
        let skill_id = skill_id.clone();
        let directory = directory.to_string();
        let readme_url = readme_url.map(|s| s.to_string());
        let on_toggle_all_apps = self.on_toggle_all_apps.clone();
        let on_uninstall = self.on_uninstall.clone();

        PopoverMenu::new(SharedString::from(format!("skill-menu-{}", skill_id)))
            .trigger(
                IconButton::new(
                    SharedString::from(format!("skill-menu-btn-{}", skill_id)),
                    IconName::Ellipsis,
                )
                .icon_size(IconSize::Small)
                .shape(IconButtonShape::Square)
                .tooltip(Tooltip::text(t("cc-more-options"))),
            )
            .anchor(Corner::TopRight)
            .menu(move |window, cx| {
                let skill_id = skill_id.clone();
                let directory = directory.clone();
                let readme_url = readme_url.clone();
                let on_toggle_all_apps = on_toggle_all_apps.clone();
                let on_uninstall = on_uninstall.clone();

                Some(ContextMenu::build(window, cx, move |menu, _window, _cx| {
                    let skill_id = skill_id.clone();
                    let directory = directory.clone();
                    let readme_url = readme_url.clone();
                    let on_toggle_all_apps = on_toggle_all_apps.clone();
                    let on_uninstall = on_uninstall.clone();

                    menu.entry(&t("cc-open-skill-directory"), None, {
                        let directory = directory.clone();
                        move |_window, cx| {
                            cx.open_url(&format!("file://{}", directory));
                        }
                    })
                    .when_some(readme_url, |menu, url| {
                        menu.entry(&t("cc-view-readme"), None, move |_window, cx| {
                            cx.open_url(&url);
                        })
                    })
                    .separator()
                    .entry(&t("cc-enable-for-all"), None, {
                        let skill_id = skill_id.clone();
                        let on_toggle_all_apps = on_toggle_all_apps.clone();
                        move |window, cx| {
                            if let Some(callback) = &on_toggle_all_apps {
                                callback(skill_id.clone(), true, window, cx);
                            }
                        }
                    })
                    .entry(&t("cc-disable-for-all"), None, {
                        let skill_id = skill_id.clone();
                        let on_toggle_all_apps = on_toggle_all_apps.clone();
                        move |window, cx| {
                            if let Some(callback) = &on_toggle_all_apps {
                                callback(skill_id.clone(), false, window, cx);
                            }
                        }
                    })
                    .separator()
                    .entry(&t("cc-uninstall"), None, {
                        let skill_id = skill_id.clone();
                        let on_uninstall = on_uninstall.clone();
                        move |window, cx| {
                            if let Some(callback) = &on_uninstall {
                                callback(skill_id.clone(), window, cx);
                            }
                        }
                    })
                }))
            })
    }

    /// Render the install skill button
    fn render_install_button(&self, _cx: &App) -> impl IntoElement {
        let on_install = self.on_install.clone();

        div().w_full().p_2().child(
            Button::new("install-skill-btn", t("cc-install-skill"))
                .full_width()
                .style(ButtonStyle::Outlined)
                .layer(ElevationIndex::Surface)
                .icon(IconName::Plus)
                .icon_position(IconPosition::Start)
                .icon_size(IconSize::Small)
                .icon_color(Color::Muted)
                .label_size(LabelSize::Small)
                .on_click(move |_, window, cx| {
                    if let Some(callback) = &on_install {
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
            .child(self.render_header(cx))
            .child(Divider::horizontal().color(DividerColor::Border))
            .child(self.render_skills_list(cx))
            .child(div().flex_grow())
            .child(self.render_install_button(cx))
            .into_any_element()
    }
}

impl Render for SkillsView {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        self.render_content(cx)
    }
}
