//! Modal for installing a new Skill

use gpui::{
    DismissEvent, Entity, EventEmitter, FocusHandle, Focusable, Render, ScrollHandle,
};
use i18n::t;
use menu;
use ui::{
    Button, Modal, ModalFooter, ModalHeader, prelude::*,
};
use ui_input::InputField;
use workspace::ModalView;

use crate::InstalledSkill;

pub struct AddSkillModal {
    focus_handle: FocusHandle,
    url_input: Entity<InputField>,
    name_input: Entity<InputField>,
    on_confirm: Box<dyn Fn(InstalledSkill, &mut Window, &mut App) + 'static>,
}

impl AddSkillModal {
    pub fn new(
        window: &mut Window,
        cx: &mut Context<Self>,
        on_confirm: impl Fn(InstalledSkill, &mut Window, &mut App) + 'static,
    ) -> Self {
        let url_input = cx.new(|cx| {
            InputField::new(window, cx, &t("cc-skill-url-placeholder"))
                .label(&t("cc-repository-url"))
                .tab_index(1)
        });

        let name_input = cx.new(|cx| {
            InputField::new(window, cx, &t("cc-skill-name-placeholder"))
                .label(&t("name"))
                .tab_index(2)
        });

        Self {
            focus_handle: cx.focus_handle(),
            url_input,
            name_input,
            on_confirm: Box::new(on_confirm),
        }
    }

    fn confirm(&mut self, _: &menu::Confirm, window: &mut Window, cx: &mut Context<Self>) {
        let url_text = self.url_input.read(cx).text(cx);
        let mut name_text = self.name_input.read(cx).text(cx);

        if url_text.is_empty() {
            return;
        }

        let skill = if url_text.starts_with("http") || url_text.starts_with("git@") {
            // Parse as Repo
            // Simple parsing logic: try to extract owner/repo
            // Format: https://github.com/owner/repo
            let parts: Vec<&str> = url_text.trim_end_matches('/').split('/').collect();
            let (owner, repo) = if parts.len() >= 2 {
                (parts[parts.len() - 2], parts[parts.len() - 1])
            } else {
                ("unknown", "unknown")
            };
            
            // Remove .git suffix if present
            let repo: &str = repo.strip_suffix(".git").unwrap_or(repo);

            if name_text.is_empty() {
                name_text = repo.to_string();
            }

            InstalledSkill::new_from_repo(owner, repo, "main", name_text, repo)
        } else {
            // Parse as Local Path
            if name_text.is_empty() {
                // Use last part of path as name
                let path = std::path::Path::new(&url_text);
                name_text = path.file_name()
                    .map(|s| s.to_string_lossy().to_string())
                    .unwrap_or_else(|| t("cc-local-skill"));
            }
            
            InstalledSkill::new_local(
                format!("local:{}", name_text), // Temporary ID generation
                name_text.clone(),
                url_text, // Using input as directory/path for now
            )
        };

        (self.on_confirm)(skill, window, cx);
        cx.emit(DismissEvent);
    }

    fn cancel(&mut self, _: &menu::Cancel, _: &mut Window, cx: &mut Context<Self>) {
        cx.emit(DismissEvent);
    }
}

impl EventEmitter<DismissEvent> for AddSkillModal {}

impl Focusable for AddSkillModal {
    fn focus_handle(&self, _cx: &App) -> FocusHandle {
        self.focus_handle.clone()
    }
}

impl ModalView for AddSkillModal {}

impl Render for AddSkillModal {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        v_flex()
            .id("add-skill-modal")
            .w(rems(24.))
            .elevation_3(cx)
            .on_action(cx.listener(Self::confirm))
            .on_action(cx.listener(Self::cancel))
            .child(
                Modal::new("install-skill", None)
                    .header(
                        ModalHeader::new().headline(t("cc-install-skill")),
                    )
                    .child(
                        v_flex()
                            .p_4()
                            .gap_4()
                            .child(self.url_input.clone())
                            .child(self.name_input.clone()),
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
                                    Button::new("confirm", t("install"))
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
