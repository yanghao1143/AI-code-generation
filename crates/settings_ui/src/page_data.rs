use gpui::{Action as _, App};
use i18n::t;
use settings::{LanguageSettingsContent, SettingsContent};
use std::borrow::Cow;
use std::sync::Arc;
use strum::IntoDiscriminant as _;
use ui::IntoElement;

use crate::{
    ActionLink, DynamicItem, PROJECT, SettingField, SettingItem, SettingsFieldMetadata,
    SettingsPage, SettingsPageItem, SubPageLink, USER, active_language, all_language_names,
    pages::render_edit_prediction_setup_page,
};

const DEFAULT_STRING: String = String::new();
/// A default empty string reference. Useful in `pick` functions for cases either in dynamic item fields, or when dealing with `settings::Maybe`
/// to avoid the "NO DEFAULT" case.
const DEFAULT_EMPTY_STRING: Option<&String> = Some(&DEFAULT_STRING);

macro_rules! concat_sections {
    (@vec, $($arr:expr),+ $(,)?) => {{
        let total_len = 0_usize $(+ $arr.len())+;
        let mut out = Vec::with_capacity(total_len);

        $(
            out.extend($arr);
        )+

        out
    }};

    ($($arr:expr),+ $(,)?) => {{
        let total_len = 0_usize $(+ $arr.len())+;

        let mut out: Box<[std::mem::MaybeUninit<_>]> = Box::new_uninit_slice(total_len);

        let mut index = 0usize;
        $(
            let array = $arr;
            for item in array {
                out[index].write(item);
                index += 1;
            }
        )+

        debug_assert_eq!(index, total_len);

        // SAFETY: we wrote exactly `total_len` elements.
        unsafe { out.assume_init() }
    }};
}

pub(crate) fn settings_data(cx: &App) -> Vec<SettingsPage> {
    vec![
        general_page(),
        appearance_page(),
        keymap_page(),
        editor_page(),
        languages_and_tools_page(cx),
        search_and_files_page(),
        window_and_layout_page(),
        panels_page(),
        debugger_page(),
        terminal_page(),
        version_control_page(),
        collaboration_page(),
        ai_page(),
        network_page(),
    ]
}

fn general_page() -> SettingsPage {
    fn general_settings_section() -> [SettingsPageItem; 8] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-general"))),
            SettingsPageItem::SettingItem(SettingItem {
                files: PROJECT,
                title: Cow::Owned(t("setting-project-name")),
                description: Cow::Owned(t("setting-project-name-desc")),
                field: Box::new(SettingField {
                    json_path: Some("project_name"),
                    pick: |settings_content| {
                        settings_content
                            .project
                            .worktree
                            .project_name
                            .as_ref()
                            .or(DEFAULT_EMPTY_STRING)
                    },
                    write: |settings_content, value| {
                        settings_content.project.worktree.project_name =
                            value.filter(|name| !name.is_empty());
                    },
                }),
                metadata: Some(Box::new(SettingsFieldMetadata {
                    placeholder: Some("Project Name"),
                    ..Default::default()
                })),
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-when-closing-no-tabs")),
                description: Cow::Owned(t("setting-when-closing-no-tabs-desc")),
                field: Box::new(SettingField {
                    json_path: Some("when_closing_with_no_tabs"),
                    pick: |settings_content| {
                        settings_content
                            .workspace
                            .when_closing_with_no_tabs
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.workspace.when_closing_with_no_tabs = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-on-last-window-closed")),
                description: Cow::Owned(t("setting-on-last-window-closed-desc")),
                field: Box::new(SettingField {
                    json_path: Some("on_last_window_closed"),
                    pick: |settings_content| {
                        settings_content.workspace.on_last_window_closed.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.workspace.on_last_window_closed = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-use-system-path-prompts")),
                description: Cow::Owned(t("setting-use-system-path-prompts-desc")),
                field: Box::new(SettingField {
                    json_path: Some("use_system_path_prompts"),
                    pick: |settings_content| {
                        settings_content.workspace.use_system_path_prompts.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.workspace.use_system_path_prompts = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-use-system-prompts")),
                description: Cow::Owned(t("setting-use-system-prompts-desc")),
                field: Box::new(SettingField {
                    json_path: Some("use_system_prompts"),
                    pick: |settings_content| settings_content.workspace.use_system_prompts.as_ref(),
                    write: |settings_content, value| {
                        settings_content.workspace.use_system_prompts = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-redact-private-values")),
                description: Cow::Owned(t("setting-redact-private-values-desc")),
                field: Box::new(SettingField {
                    json_path: Some("redact_private_values"),
                    pick: |settings_content| settings_content.editor.redact_private_values.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.redact_private_values = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-private-files")),
                description: Cow::Owned(t("setting-private-files-desc")),
                field: Box::new(
                    SettingField {
                        json_path: Some("worktree.private_files"),
                        pick: |settings_content| {
                            settings_content.project.worktree.private_files.as_ref()
                        },
                        write: |settings_content, value| {
                            settings_content.project.worktree.private_files = value;
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER,
            }),
        ]
    }
    fn security_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-security"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-trust-all-projects")),
                description: Cow::Owned(t("setting-trust-all-projects-desc")),
                field: Box::new(SettingField {
                    json_path: Some("session.trust_all_projects"),
                    pick: |settings_content| {
                        settings_content
                            .session
                            .as_ref()
                            .and_then(|session| session.trust_all_worktrees.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content
                            .session
                            .get_or_insert_default()
                            .trust_all_worktrees = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn workspace_restoration_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-workspace-restoration"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-restore-unsaved-buffers")),
                description: Cow::Owned(t("setting-restore-unsaved-buffers-desc")),
                field: Box::new(SettingField {
                    json_path: Some("session.restore_unsaved_buffers"),
                    pick: |settings_content| {
                        settings_content
                            .session
                            .as_ref()
                            .and_then(|session| session.restore_unsaved_buffers.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content
                            .session
                            .get_or_insert_default()
                            .restore_unsaved_buffers = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-restore-on-startup")),
                description: Cow::Owned(t("setting-restore-on-startup-desc")),
                field: Box::new(SettingField {
                    json_path: Some("restore_on_startup"),
                    pick: |settings_content| settings_content.workspace.restore_on_startup.as_ref(),
                    write: |settings_content, value| {
                        settings_content.workspace.restore_on_startup = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn scoped_settings_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-scoped"))),
            SettingsPageItem::SettingItem(SettingItem {
                files: USER,
                title: Cow::Owned(t("setting-preview-channel")),
                description: Cow::Owned(t("setting-preview-channel-desc")),
                field: Box::new(
                    SettingField {
                        json_path: Some("preview_channel_settings"),
                        pick: |settings_content| Some(settings_content),
                        write: |_settings_content, _value| {},
                    }
                    .unimplemented(),
                ),
                metadata: None,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                files: USER,
                title: Cow::Owned(t("setting-settings-profiles")),
                description: Cow::Owned(t("setting-settings-profiles-desc")),
                field: Box::new(
                    SettingField {
                        json_path: Some("settings_profiles"),
                        pick: |settings_content| Some(settings_content),
                        write: |_settings_content, _value| {},
                    }
                    .unimplemented(),
                ),
                metadata: None,
            }),
        ]
    }

    fn privacy_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-privacy"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-telemetry-diagnostics")),
                description: Cow::Owned(t("setting-telemetry-diagnostics-desc")),
                field: Box::new(SettingField {
                    json_path: Some("telemetry.diagnostics"),
                    pick: |settings_content| {
                        settings_content
                            .telemetry
                            .as_ref()
                            .and_then(|telemetry| telemetry.diagnostics.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content
                            .telemetry
                            .get_or_insert_default()
                            .diagnostics = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-telemetry-metrics")),
                description: Cow::Owned(t("setting-telemetry-metrics-desc")),
                field: Box::new(SettingField {
                    json_path: Some("telemetry.metrics"),
                    pick: |settings_content| {
                        settings_content
                            .telemetry
                            .as_ref()
                            .and_then(|telemetry| telemetry.metrics.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content.telemetry.get_or_insert_default().metrics = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn auto_update_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-auto-update"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-auto-update")),
                description: Cow::Owned(t("setting-auto-update-desc")),
                field: Box::new(SettingField {
                    json_path: Some("auto_update"),
                    pick: |settings_content| settings_content.auto_update.as_ref(),
                    write: |settings_content, value| {
                        settings_content.auto_update = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    SettingsPage {
        title: Cow::Owned(t("settings-page-general")),
        items: concat_sections!(
            general_settings_section(),
            security_section(),
            workspace_restoration_section(),
            scoped_settings_section(),
            privacy_section(),
            auto_update_section(),
        ),
    }
}

fn appearance_page() -> SettingsPage {
    fn theme_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-theme"))),
            SettingsPageItem::DynamicItem(DynamicItem {
                discriminant: SettingItem {
                    files: USER,
                    title: Cow::Owned(t("setting-theme-mode")),
                    description: Cow::Owned(t("setting-theme-mode-desc")),
                    field: Box::new(SettingField {
                        json_path: Some("theme$"),
                        pick: |settings_content| {
                            Some(&dynamic_variants::<settings::ThemeSelection>()[
                                settings_content
                                    .theme
                                    .theme
                                    .as_ref()?
                                    .discriminant() as usize])
                        },
                        write: |settings_content, value| {
                            let Some(value) = value else {
                                settings_content.theme.theme = None;
                                return;
                            };
                            let settings_value = settings_content.theme.theme.get_or_insert_default();
                            *settings_value = match value {
                                settings::ThemeSelectionDiscriminants::Static => {
                                    let name = match settings_value {
                                        settings::ThemeSelection::Static(_) => return,
                                        settings::ThemeSelection::Dynamic { mode, light, dark } => {
                                            match mode {
                                                theme::ThemeAppearanceMode::Light => light.clone(),
                                                theme::ThemeAppearanceMode::Dark => dark.clone(),
                                                theme::ThemeAppearanceMode::System => dark.clone(), // no cx, can't determine correct choice
                                            }
                                        },
                                    };
                                    settings::ThemeSelection::Static(name)
                                },
                                settings::ThemeSelectionDiscriminants::Dynamic => {
                                    let static_name = match settings_value {
                                        settings::ThemeSelection::Static(theme_name) => theme_name.clone(),
                                        settings::ThemeSelection::Dynamic {..} => return,
                                    };

                                    settings::ThemeSelection::Dynamic {
                                        mode: settings::ThemeAppearanceMode::System,
                                        light: static_name.clone(),
                                        dark: static_name,
                                    }
                                },
                            };
                        },
                    }),
                    metadata: None,
                },
                pick_discriminant: |settings_content| {
                    Some(settings_content.theme.theme.as_ref()?.discriminant() as usize)
                },
                fields: dynamic_variants::<settings::ThemeSelection>().into_iter().map(|variant| {
                    match variant {
                        settings::ThemeSelectionDiscriminants::Static => vec![
                            SettingItem {
                                files: USER,
                                title: Cow::Owned(t("setting-theme-name")),
                                description: Cow::Owned(t("setting-theme-name-desc")),
                                field: Box::new(SettingField {
                                    json_path: Some("theme"),
                                    pick: |settings_content| {
                                        match settings_content.theme.theme.as_ref() {
                                            Some(settings::ThemeSelection::Static(name)) => Some(name),
                                            _ => None
                                        }
                                    },
                                    write: |settings_content, value| {
                                        let Some(value) = value else {
                                            return;
                                        };
                                        match settings_content
                                            .theme
                                            .theme.get_or_insert_default() {
                                                settings::ThemeSelection::Static(theme_name) => *theme_name = value,
                                                _ => return
                                            }
                                    },
                                }),
                                metadata: None,
                            }
                        ],
                        settings::ThemeSelectionDiscriminants::Dynamic => vec![
                            SettingItem {
                                files: USER,
                                title: Cow::Owned(t("setting-mode")),
                                description: Cow::Owned(t("setting-mode-desc")),
                                field: Box::new(SettingField {
                                    json_path: Some("theme.mode"),
                                    pick: |settings_content| {
                                        match settings_content.theme.theme.as_ref() {
                                            Some(settings::ThemeSelection::Dynamic { mode, ..}) => Some(mode),
                                            _ => None
                                        }
                                    },
                                    write: |settings_content, value| {
                                        let Some(value) = value else {
                                            return;
                                        };
                                        match settings_content
                                            .theme
                                            .theme.get_or_insert_default() {
                                                settings::ThemeSelection::Dynamic{ mode, ..} => *mode = value,
                                                _ => return
                                            }
                                    },
                                }),
                                metadata: None,
                            },
                            SettingItem {
                                files: USER,
                                title: Cow::Owned(t("setting-light-theme")),
                                description: Cow::Owned(t("setting-light-theme-desc")),
                                field: Box::new(SettingField {
                                    json_path: Some("theme.light"),
                                    pick: |settings_content| {
                                        match settings_content.theme.theme.as_ref() {
                                            Some(settings::ThemeSelection::Dynamic { light, ..}) => Some(light),
                                            _ => None
                                        }
                                    },
                                    write: |settings_content, value| {
                                        let Some(value) = value else {
                                            return;
                                        };
                                        match settings_content
                                            .theme
                                            .theme.get_or_insert_default() {
                                                settings::ThemeSelection::Dynamic{ light, ..} => *light = value,
                                                _ => return
                                            }
                                    },
                                }),
                                metadata: None,
                            },
                            SettingItem {
                                files: USER,
                                title: Cow::Owned(t("setting-dark-theme")),
                                description: Cow::Owned(t("setting-dark-theme-desc")),
                                field: Box::new(SettingField {
                                    json_path: Some("theme.dark"),
                                    pick: |settings_content| {
                                        match settings_content.theme.theme.as_ref() {
                                            Some(settings::ThemeSelection::Dynamic { dark, ..}) => Some(dark),
                                            _ => None
                                        }
                                    },
                                    write: |settings_content, value| {
                                        let Some(value) = value else {
                                            return;
                                        };
                                        match settings_content
                                            .theme
                                            .theme.get_or_insert_default() {
                                                settings::ThemeSelection::Dynamic{ dark, ..} => *dark = value,
                                                _ => return
                                            }
                                    },
                                }),
                                metadata: None,
                            }
                        ],
                    }
                }).collect(),
            }),
            SettingsPageItem::DynamicItem(DynamicItem {
                discriminant: SettingItem {
                    files: USER,
                    title: Cow::Owned(t("setting-icon-theme")),
                    description: Cow::Owned(t("setting-icon-theme-desc")),
                    field: Box::new(SettingField {
                        json_path: Some("icon_theme$"),
                        pick: |settings_content| {
                            Some(&dynamic_variants::<settings::IconThemeSelection>()[
                                settings_content
                                    .theme
                                    .icon_theme
                                    .as_ref()?
                                    .discriminant() as usize])
                        },
                        write: |settings_content, value| {
                            let Some(value) = value else {
                                settings_content.theme.icon_theme = None;
                                return;
                            };
                            let settings_value = settings_content.theme.icon_theme.get_or_insert_with(|| {
                                settings::IconThemeSelection::Static(settings::IconThemeName(theme::default_icon_theme().name.clone().into()))
                            });
                            *settings_value = match value {
                                settings::IconThemeSelectionDiscriminants::Static => {
                                    let name = match settings_value {
                                        settings::IconThemeSelection::Static(_) => return,
                                        settings::IconThemeSelection::Dynamic { mode, light, dark } => {
                                            match mode {
                                                theme::ThemeAppearanceMode::Light => light.clone(),
                                                theme::ThemeAppearanceMode::Dark => dark.clone(),
                                                theme::ThemeAppearanceMode::System => dark.clone(), // no cx, can't determine correct choice
                                            }
                                        },
                                    };
                                    settings::IconThemeSelection::Static(name)
                                },
                                settings::IconThemeSelectionDiscriminants::Dynamic => {
                                    let static_name = match settings_value {
                                        settings::IconThemeSelection::Static(theme_name) => theme_name.clone(),
                                        settings::IconThemeSelection::Dynamic {..} => return,
                                    };

                                    settings::IconThemeSelection::Dynamic {
                                        mode: settings::ThemeAppearanceMode::System,
                                        light: static_name.clone(),
                                        dark: static_name,
                                    }
                                },
                            };
                        },
                    }),
                    metadata: None,
                },
                pick_discriminant: |settings_content| {
                    Some(settings_content.theme.icon_theme.as_ref()?.discriminant() as usize)
                },
                fields: dynamic_variants::<settings::IconThemeSelection>().into_iter().map(|variant| {
                    match variant {
                        settings::IconThemeSelectionDiscriminants::Static => vec![
                            SettingItem {
                                files: USER,
                                title: Cow::Owned(t("setting-icon-theme-name")),
                                description: Cow::Owned(t("setting-icon-theme-name-desc")),
                                field: Box::new(SettingField {
                                    json_path: Some("icon_theme$string"),
                                    pick: |settings_content| {
                                        match settings_content.theme.icon_theme.as_ref() {
                                            Some(settings::IconThemeSelection::Static(name)) => Some(name),
                                            _ => None
                                        }
                                    },
                                    write: |settings_content, value| {
                                        let Some(value) = value else {
                                            return;
                                        };
                                        match settings_content
                                            .theme
                                            .icon_theme.as_mut() {
                                                Some(settings::IconThemeSelection::Static(theme_name)) => *theme_name = value,
                                                _ => return
                                            }
                                    },
                                }),
                                metadata: None,
                            }
                        ],
                        settings::IconThemeSelectionDiscriminants::Dynamic => vec![
                            SettingItem {
                                files: USER,
                                title: Cow::Owned(t("setting-mode")),
                                description: Cow::Owned(t("setting-mode-desc")),
                                field: Box::new(SettingField {
                                    json_path: Some("icon_theme"),
                                    pick: |settings_content| {
                                        match settings_content.theme.icon_theme.as_ref() {
                                            Some(settings::IconThemeSelection::Dynamic { mode, ..}) => Some(mode),
                                            _ => None
                                        }
                                    },
                                    write: |settings_content, value| {
                                        let Some(value) = value else {
                                            return;
                                        };
                                        match settings_content
                                            .theme
                                            .icon_theme.as_mut() {
                                                Some(settings::IconThemeSelection::Dynamic{ mode, ..}) => *mode = value,
                                                _ => return
                                            }
                                    },
                                }),
                                metadata: None,
                            },
                            SettingItem {
                                files: USER,
                                title: Cow::Owned(t("setting-light-icon-theme")),
                                description: Cow::Owned(t("setting-light-icon-theme-desc")),
                                field: Box::new(SettingField {
                                    json_path: Some("icon_theme.light"),
                                    pick: |settings_content| {
                                        match settings_content.theme.icon_theme.as_ref() {
                                            Some(settings::IconThemeSelection::Dynamic { light, ..}) => Some(light),
                                            _ => None
                                        }
                                    },
                                    write: |settings_content, value| {
                                        let Some(value) = value else {
                                            return;
                                        };
                                        match settings_content
                                            .theme
                                            .icon_theme.as_mut() {
                                                Some(settings::IconThemeSelection::Dynamic{ light, ..}) => *light = value,
                                                _ => return
                                            }
                                    },
                                }),
                                metadata: None,
                            },
                            SettingItem {
                                files: USER,
                                title: Cow::Owned(t("setting-dark-icon-theme")),
                                description: Cow::Owned(t("setting-dark-icon-theme-desc")),
                                field: Box::new(SettingField {
                                    json_path: Some("icon_theme.dark"),
                                    pick: |settings_content| {
                                        match settings_content.theme.icon_theme.as_ref() {
                                            Some(settings::IconThemeSelection::Dynamic { dark, ..}) => Some(dark),
                                            _ => None
                                        }
                                    },
                                    write: |settings_content, value| {
                                        let Some(value) = value else {
                                            return;
                                        };
                                        match settings_content
                                            .theme
                                            .icon_theme.as_mut() {
                                                Some(settings::IconThemeSelection::Dynamic{ dark, ..}) => *dark = value,
                                                _ => return
                                            }
                                    },
                                }),
                                metadata: None,
                            }
                        ],
                    }
                }).collect(),
            }),
        ]
    }

    fn buffer_font_section() -> [SettingsPageItem; 7] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-buffer-font"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-font-family")),
                description: Cow::Owned(t("setting-font-family-desc")),
                field: Box::new(SettingField {
                    json_path: Some("buffer_font_family"),
                    pick: |settings_content| settings_content.theme.buffer_font_family.as_ref(),
                    write: |settings_content, value| {
                        settings_content.theme.buffer_font_family = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-font-size")),
                description: Cow::Owned(t("setting-font-size-desc")),
                field: Box::new(SettingField {
                    json_path: Some("buffer_font_size"),
                    pick: |settings_content| settings_content.theme.buffer_font_size.as_ref(),
                    write: |settings_content, value| {
                        settings_content.theme.buffer_font_size = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-font-weight")),
                description: Cow::Owned(t("setting-font-weight-desc")),
                field: Box::new(SettingField {
                    json_path: Some("buffer_font_weight"),
                    pick: |settings_content| settings_content.theme.buffer_font_weight.as_ref(),
                    write: |settings_content, value| {
                        settings_content.theme.buffer_font_weight = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::DynamicItem(DynamicItem {
                discriminant: SettingItem {
                    files: USER,
                    title: Cow::Owned(t("setting-line-height")),
                    description: Cow::Owned(t("setting-line-height-desc")),
                    field: Box::new(SettingField {
                        json_path: Some("buffer_line_height$"),
                        pick: |settings_content| {
                            Some(
                                &dynamic_variants::<settings::BufferLineHeight>()[settings_content
                                    .theme
                                    .buffer_line_height
                                    .as_ref()?
                                    .discriminant()
                                    as usize],
                            )
                        },
                        write: |settings_content, value| {
                            let Some(value) = value else {
                                settings_content.theme.buffer_line_height = None;
                                return;
                            };
                            let settings_value = settings_content
                                .theme
                                .buffer_line_height
                                .get_or_insert_with(|| settings::BufferLineHeight::default());
                            *settings_value = match value {
                                settings::BufferLineHeightDiscriminants::Comfortable => {
                                    settings::BufferLineHeight::Comfortable
                                }
                                settings::BufferLineHeightDiscriminants::Standard => {
                                    settings::BufferLineHeight::Standard
                                }
                                settings::BufferLineHeightDiscriminants::Custom => {
                                    let custom_value =
                                        theme::BufferLineHeight::from(*settings_value).value();
                                    settings::BufferLineHeight::Custom(custom_value)
                                }
                            };
                        },
                    }),
                    metadata: None,
                },
                pick_discriminant: |settings_content| {
                    Some(
                        settings_content
                            .theme
                            .buffer_line_height
                            .as_ref()?
                            .discriminant() as usize,
                    )
                },
                fields: dynamic_variants::<settings::BufferLineHeight>()
                    .into_iter()
                    .map(|variant| match variant {
                        settings::BufferLineHeightDiscriminants::Comfortable => vec![],
                        settings::BufferLineHeightDiscriminants::Standard => vec![],
                        settings::BufferLineHeightDiscriminants::Custom => vec![SettingItem {
                            files: USER,
                            title: Cow::Owned(t("setting-custom-line-height")),
                            description: Cow::Owned(t("setting-custom-line-height-desc")),
                            field: Box::new(SettingField {
                                json_path: Some("buffer_line_height"),
                                pick: |settings_content| match settings_content
                                    .theme
                                    .buffer_line_height
                                    .as_ref()
                                {
                                    Some(settings::BufferLineHeight::Custom(value)) => Some(value),
                                    _ => None,
                                },
                                write: |settings_content, value| {
                                    let Some(value) = value else {
                                        return;
                                    };
                                    match settings_content.theme.buffer_line_height.as_mut() {
                                        Some(settings::BufferLineHeight::Custom(line_height)) => {
                                            *line_height = f32::max(value, 1.0)
                                        }
                                        _ => return,
                                    }
                                },
                            }),
                            metadata: None,
                        }],
                    })
                    .collect(),
            }),
            SettingsPageItem::SettingItem(SettingItem {
                files: USER,
                title: Cow::Owned(t("setting-font-features")),
                description: Cow::Owned(t("setting-font-features-desc")),
                field: Box::new(
                    SettingField {
                        json_path: Some("buffer_font_features"),
                        pick: |settings_content| {
                            settings_content.theme.buffer_font_features.as_ref()
                        },
                        write: |settings_content, value| {
                            settings_content.theme.buffer_font_features = value;
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                files: USER,
                title: Cow::Owned(t("setting-font-fallbacks")),
                description: Cow::Owned(t("setting-font-fallbacks-desc")),
                field: Box::new(
                    SettingField {
                        json_path: Some("buffer_font_fallbacks"),
                        pick: |settings_content| {
                            settings_content.theme.buffer_font_fallbacks.as_ref()
                        },
                        write: |settings_content, value| {
                            settings_content.theme.buffer_font_fallbacks = value;
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
            }),
        ]
    }

    fn ui_font_section() -> [SettingsPageItem; 6] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-ui-font"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-ui-font-family")),
                description: Cow::Owned(t("setting-ui-font-family-desc")),
                field: Box::new(SettingField {
                    json_path: Some("ui_font_family"),
                    pick: |settings_content| settings_content.theme.ui_font_family.as_ref(),
                    write: |settings_content, value| {
                        settings_content.theme.ui_font_family = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-ui-font-size")),
                description: Cow::Owned(t("setting-ui-font-size-desc")),
                field: Box::new(SettingField {
                    json_path: Some("ui_font_size"),
                    pick: |settings_content| settings_content.theme.ui_font_size.as_ref(),
                    write: |settings_content, value| {
                        settings_content.theme.ui_font_size = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-ui-font-weight")),
                description: Cow::Owned(t("setting-ui-font-weight-desc")),
                field: Box::new(SettingField {
                    json_path: Some("ui_font_weight"),
                    pick: |settings_content| settings_content.theme.ui_font_weight.as_ref(),
                    write: |settings_content, value| {
                        settings_content.theme.ui_font_weight = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                files: USER,
                title: Cow::Owned(t("setting-ui-font-features")),
                description: Cow::Owned(t("setting-ui-font-features-desc")),
                field: Box::new(
                    SettingField {
                        json_path: Some("ui_font_features"),
                        pick: |settings_content| settings_content.theme.ui_font_features.as_ref(),
                        write: |settings_content, value| {
                            settings_content.theme.ui_font_features = value;
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                files: USER,
                title: Cow::Owned(t("setting-ui-font-fallbacks")),
                description: Cow::Owned(t("setting-ui-font-fallbacks-desc")),
                field: Box::new(
                    SettingField {
                        json_path: Some("ui_font_fallbacks"),
                        pick: |settings_content| settings_content.theme.ui_font_fallbacks.as_ref(),
                        write: |settings_content, value| {
                            settings_content.theme.ui_font_fallbacks = value;
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
            }),
        ]
    }

    fn agent_panel_font_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-agent-font"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-agent-ui-font-size")),
                description: Cow::Owned(t("setting-agent-ui-font-size-desc")),
                field: Box::new(SettingField {
                    json_path: Some("agent_ui_font_size"),
                    pick: |settings_content| {
                        settings_content
                            .theme
                            .agent_ui_font_size
                            .as_ref()
                            .or(settings_content.theme.ui_font_size.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content.theme.agent_ui_font_size = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-agent-buffer-font-size")),
                description: Cow::Owned(t("setting-agent-buffer-font-size-desc")),
                field: Box::new(SettingField {
                    json_path: Some("agent_buffer_font_size"),
                    pick: |settings_content| {
                        settings_content
                            .theme
                            .agent_buffer_font_size
                            .as_ref()
                            .or(settings_content.theme.buffer_font_size.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content.theme.agent_buffer_font_size = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn text_rendering_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-text-rendering"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-text-rendering-mode")),
                description: Cow::Owned(t("setting-text-rendering-mode-desc")),
                field: Box::new(SettingField {
                    json_path: Some("text_rendering_mode"),
                    pick: |settings_content| {
                        settings_content.workspace.text_rendering_mode.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.workspace.text_rendering_mode = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn cursor_section() -> [SettingsPageItem; 5] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-cursor"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-multi-cursor-modifier")),
                description: Cow::Owned(t("setting-multi-cursor-modifier-desc")),
                field: Box::new(SettingField {
                    json_path: Some("multi_cursor_modifier"),
                    pick: |settings_content| settings_content.editor.multi_cursor_modifier.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.multi_cursor_modifier = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-cursor-blink")),
                description: Cow::Owned(t("setting-cursor-blink-desc")),
                field: Box::new(SettingField {
                    json_path: Some("cursor_blink"),
                    pick: |settings_content| settings_content.editor.cursor_blink.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.cursor_blink = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-cursor-shape")),
                description: Cow::Owned(t("setting-cursor-shape-desc")),
                field: Box::new(SettingField {
                    json_path: Some("cursor_shape"),
                    pick: |settings_content| settings_content.editor.cursor_shape.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.cursor_shape = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-hide-mouse")),
                description: Cow::Owned(t("setting-hide-mouse-desc")),
                field: Box::new(SettingField {
                    json_path: Some("hide_mouse"),
                    pick: |settings_content| settings_content.editor.hide_mouse.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.hide_mouse = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn highlighting_section() -> [SettingsPageItem; 6] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-highlighting"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-unnecessary-code-fade")),
                description: Cow::Owned(t("setting-unnecessary-code-fade-desc")),
                field: Box::new(SettingField {
                    json_path: Some("unnecessary_code_fade"),
                    pick: |settings_content| settings_content.theme.unnecessary_code_fade.as_ref(),
                    write: |settings_content, value| {
                        settings_content.theme.unnecessary_code_fade = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-current-line-highlight")),
                description: Cow::Owned(t("setting-current-line-highlight-desc")),
                field: Box::new(SettingField {
                    json_path: Some("current_line_highlight"),
                    pick: |settings_content| {
                        settings_content.editor.current_line_highlight.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.editor.current_line_highlight = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-selection-highlight")),
                description: Cow::Owned(t("setting-selection-highlight-desc")),
                field: Box::new(SettingField {
                    json_path: Some("selection_highlight"),
                    pick: |settings_content| settings_content.editor.selection_highlight.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.selection_highlight = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-rounded-selection")),
                description: Cow::Owned(t("setting-rounded-selection-desc")),
                field: Box::new(SettingField {
                    json_path: Some("rounded_selection"),
                    pick: |settings_content| settings_content.editor.rounded_selection.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.rounded_selection = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-minimum-contrast")),
                description: Cow::Owned(t("setting-minimum-contrast-desc")),
                field: Box::new(SettingField {
                    json_path: Some("minimum_contrast_for_highlights"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .minimum_contrast_for_highlights
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.editor.minimum_contrast_for_highlights = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn guides_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-guides"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-show-wrap-guides")),
                description: Cow::Owned(t("setting-show-wrap-guides-desc")),
                field: Box::new(SettingField {
                    json_path: Some("show_wrap_guides"),
                    pick: |settings_content| {
                        settings_content
                            .project
                            .all_languages
                            .defaults
                            .show_wrap_guides
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project
                            .all_languages
                            .defaults
                            .show_wrap_guides = value;
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            // todo(settings_ui): This needs a custom component
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-wrap-guides")),
                description: Cow::Owned(t("setting-wrap-guides-desc")),
                field: Box::new(
                    SettingField {
                        json_path: Some("wrap_guides"),
                        pick: |settings_content| {
                            settings_content
                                .project
                                .all_languages
                                .defaults
                                .wrap_guides
                                .as_ref()
                        },
                        write: |settings_content, value| {
                            settings_content.project.all_languages.defaults.wrap_guides = value;
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER | PROJECT,
            }),
        ]
    }

    let items: Box<[SettingsPageItem]> = concat_sections!(
        theme_section(),
        buffer_font_section(),
        ui_font_section(),
        agent_panel_font_section(),
        text_rendering_section(),
        cursor_section(),
        highlighting_section(),
        guides_section(),
    );

    SettingsPage {
        title: Cow::Owned(t("settings-page-appearance")),
        items,
    }
}

fn keymap_page() -> SettingsPage {
    fn keybindings_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-keybindings"))),
            SettingsPageItem::ActionLink(ActionLink {
                title: t("setting-edit-keybindings").into(),
                description: Some(t("setting-edit-keybindings-desc").into()),
                button_text: t("setting-open-keymap").into(),
                on_click: Arc::new(|settings_window, window, cx| {
                    let Some(original_window) = settings_window.original_window else {
                        return;
                    };
                    original_window
                        .update(cx, |_workspace, original_window, cx| {
                            original_window
                                .dispatch_action(zed_actions::OpenKeymap.boxed_clone(), cx);
                            original_window.activate_window();
                        })
                        .ok();
                    window.remove_window();
                }),
            }),
        ]
    }

    fn base_keymap_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-base-keymap"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-base-keymap")),
                description: Cow::Owned(t("setting-base-keymap-desc")),
                field: Box::new(SettingField {
                    json_path: Some("base_keymap"),
                    pick: |settings_content| settings_content.base_keymap.as_ref(),
                    write: |settings_content, value| {
                        settings_content.base_keymap = value;
                    },
                }),
                metadata: Some(Box::new(SettingsFieldMetadata {
                    should_do_titlecase: Some(false),
                    ..Default::default()
                })),
                files: USER,
            }),
        ]
    }

    fn modal_editing_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-modal-editing"))),
            // todo(settings_ui): Vim/Helix Mode should be apart of one type because it's undefined
            // behavior to have them both enabled at the same time
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-vim-mode")),
                description: Cow::Owned(t("setting-vim-mode-desc")),
                field: Box::new(SettingField {
                    json_path: Some("vim_mode"),
                    pick: |settings_content| settings_content.vim_mode.as_ref(),
                    write: |settings_content, value| {
                        settings_content.vim_mode = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-helix-mode")),
                description: Cow::Owned(t("setting-helix-mode-desc")),
                field: Box::new(SettingField {
                    json_path: Some("helix_mode"),
                    pick: |settings_content| settings_content.helix_mode.as_ref(),
                    write: |settings_content, value| {
                        settings_content.helix_mode = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    let items: Box<[SettingsPageItem]> = concat_sections!(
        keybindings_section(),
        base_keymap_section(),
        modal_editing_section(),
    );

    SettingsPage {
        title: Cow::Owned(t("settings-page-keymap")),
        items,
    }
}

fn editor_page() -> SettingsPage {
    fn auto_save_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-auto-save"))),
            SettingsPageItem::DynamicItem(DynamicItem {
                discriminant: SettingItem {
                    files: USER,
                    title: Cow::Owned(t("setting-auto-save-mode")),
                    description: Cow::Owned(t("setting-auto-save-mode-desc")),
                    field: Box::new(SettingField {
                        json_path: Some("autosave$"),
                        pick: |settings_content| {
                            Some(
                                &dynamic_variants::<settings::AutosaveSetting>()[settings_content
                                    .workspace
                                    .autosave
                                    .as_ref()?
                                    .discriminant()
                                    as usize],
                            )
                        },
                        write: |settings_content, value| {
                            let Some(value) = value else {
                                settings_content.workspace.autosave = None;
                                return;
                            };
                            let settings_value = settings_content
                                .workspace
                                .autosave
                                .get_or_insert_with(|| settings::AutosaveSetting::Off);
                            *settings_value = match value {
                                settings::AutosaveSettingDiscriminants::Off => {
                                    settings::AutosaveSetting::Off
                                }
                                settings::AutosaveSettingDiscriminants::AfterDelay => {
                                    let milliseconds = match settings_value {
                                        settings::AutosaveSetting::AfterDelay { milliseconds } => {
                                            *milliseconds
                                        }
                                        _ => settings::DelayMs(1000),
                                    };
                                    settings::AutosaveSetting::AfterDelay { milliseconds }
                                }
                                settings::AutosaveSettingDiscriminants::OnFocusChange => {
                                    settings::AutosaveSetting::OnFocusChange
                                }
                                settings::AutosaveSettingDiscriminants::OnWindowChange => {
                                    settings::AutosaveSetting::OnWindowChange
                                }
                            };
                        },
                    }),
                    metadata: None,
                },
                pick_discriminant: |settings_content| {
                    Some(settings_content.workspace.autosave.as_ref()?.discriminant() as usize)
                },
                fields: dynamic_variants::<settings::AutosaveSetting>()
                    .into_iter()
                    .map(|variant| match variant {
                        settings::AutosaveSettingDiscriminants::Off => vec![],
                        settings::AutosaveSettingDiscriminants::AfterDelay => vec![SettingItem {
                            files: USER,
                            title: Cow::Owned(t("setting-auto-save-delay")),
                            description: Cow::Owned(t("setting-auto-save-delay-desc")),
                            field: Box::new(SettingField {
                                json_path: Some("autosave.after_delay.milliseconds"),
                                pick: |settings_content| match settings_content
                                    .workspace
                                    .autosave
                                    .as_ref()
                                {
                                    Some(settings::AutosaveSetting::AfterDelay {
                                        milliseconds,
                                    }) => Some(milliseconds),
                                    _ => None,
                                },
                                write: |settings_content, value| {
                                    let Some(value) = value else {
                                        settings_content.workspace.autosave = None;
                                        return;
                                    };
                                    match settings_content.workspace.autosave.as_mut() {
                                        Some(settings::AutosaveSetting::AfterDelay {
                                            milliseconds,
                                        }) => *milliseconds = value,
                                        _ => return,
                                    }
                                },
                            }),
                            metadata: None,
                        }],
                        settings::AutosaveSettingDiscriminants::OnFocusChange => vec![],
                        settings::AutosaveSettingDiscriminants::OnWindowChange => vec![],
                    })
                    .collect(),
            }),
        ]
    }

    fn which_key_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-which-key"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-show-which-key")),
                description: Cow::Owned(t("setting-show-which-key-desc")),
                field: Box::new(SettingField {
                    json_path: Some("which_key.enabled"),
                    pick: |settings_content| {
                        settings_content
                            .which_key
                            .as_ref()
                            .and_then(|settings| settings.enabled.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content.which_key.get_or_insert_default().enabled = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-which-key-delay")),
                description: Cow::Owned(t("setting-which-key-delay-desc")),
                field: Box::new(SettingField {
                    json_path: Some("which_key.delay_ms"),
                    pick: |settings_content| {
                        settings_content
                            .which_key
                            .as_ref()
                            .and_then(|settings| settings.delay_ms.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content.which_key.get_or_insert_default().delay_ms = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn multibuffer_section() -> [SettingsPageItem; 5] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-multibuffer"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-double-click-multibuffer")),
                description: Cow::Owned(t("setting-double-click-multibuffer-desc")),
                field: Box::new(SettingField {
                    json_path: Some("double_click_in_multibuffer"),
                    pick: |settings_content| {
                        settings_content.editor.double_click_in_multibuffer.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.editor.double_click_in_multibuffer = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-expand-excerpt-lines")),
                description: Cow::Owned(t("setting-expand-excerpt-lines-desc")),
                field: Box::new(SettingField {
                    json_path: Some("expand_excerpt_lines"),
                    pick: |settings_content| settings_content.editor.expand_excerpt_lines.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.expand_excerpt_lines = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-excerpt-context-lines")),
                description: Cow::Owned(t("setting-excerpt-context-lines-desc")),
                field: Box::new(SettingField {
                    json_path: Some("excerpt_context_lines"),
                    pick: |settings_content| settings_content.editor.excerpt_context_lines.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.excerpt_context_lines = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-expand-outlines-depth")),
                description: Cow::Owned(t("setting-expand-outlines-depth-desc")),
                field: Box::new(SettingField {
                    json_path: Some("outline_panel.expand_outlines_with_depth"),
                    pick: |settings_content| {
                        settings_content
                            .outline_panel
                            .as_ref()
                            .and_then(|outline_panel| {
                                outline_panel.expand_outlines_with_depth.as_ref()
                            })
                    },
                    write: |settings_content, value| {
                        settings_content
                            .outline_panel
                            .get_or_insert_default()
                            .expand_outlines_with_depth = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn scrolling_section() -> [SettingsPageItem; 8] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-scrolling"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-scroll-beyond-last-line")),
                description: Cow::Owned(t("setting-scroll-beyond-last-line-desc")),
                field: Box::new(SettingField {
                    json_path: Some("scroll_beyond_last_line"),
                    pick: |settings_content| {
                        settings_content.editor.scroll_beyond_last_line.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.editor.scroll_beyond_last_line = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-vertical-scroll-margin")),
                description: Cow::Owned(t("setting-vertical-scroll-margin-desc")),
                field: Box::new(SettingField {
                    json_path: Some("vertical_scroll_margin"),
                    pick: |settings_content| {
                        settings_content.editor.vertical_scroll_margin.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.editor.vertical_scroll_margin = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-horizontal-scroll-margin")),
                description: Cow::Owned(t("setting-horizontal-scroll-margin-desc")),
                field: Box::new(SettingField {
                    json_path: Some("horizontal_scroll_margin"),
                    pick: |settings_content| {
                        settings_content.editor.horizontal_scroll_margin.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.editor.horizontal_scroll_margin = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-scroll-sensitivity")),
                description: Cow::Owned(t("setting-scroll-sensitivity-desc")),
                field: Box::new(SettingField {
                    json_path: Some("scroll_sensitivity"),
                    pick: |settings_content| settings_content.editor.scroll_sensitivity.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.scroll_sensitivity = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-fast-scroll-sensitivity")),
                description: Cow::Owned(t("setting-fast-scroll-sensitivity-desc")),
                field: Box::new(SettingField {
                    json_path: Some("fast_scroll_sensitivity"),
                    pick: |settings_content| {
                        settings_content.editor.fast_scroll_sensitivity.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.editor.fast_scroll_sensitivity = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-autoscroll-on-clicks")),
                description: Cow::Owned(t("setting-autoscroll-on-clicks-desc")),
                field: Box::new(SettingField {
                    json_path: Some("autoscroll_on_clicks"),
                    pick: |settings_content| settings_content.editor.autoscroll_on_clicks.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.autoscroll_on_clicks = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-sticky-scroll")),
                description: Cow::Owned(t("setting-sticky-scroll-desc")),
                field: Box::new(SettingField {
                    json_path: Some("sticky_scroll.enabled"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .sticky_scroll
                            .as_ref()
                            .and_then(|sticky_scroll| sticky_scroll.enabled.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .sticky_scroll
                            .get_or_insert_default()
                            .enabled = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn signature_help_section() -> [SettingsPageItem; 4] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-signature-help"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-auto-signature-help")),
                description: Cow::Owned(t("setting-auto-signature-help-desc")),
                field: Box::new(SettingField {
                    json_path: Some("auto_signature_help"),
                    pick: |settings_content| settings_content.editor.auto_signature_help.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.auto_signature_help = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-show-signature-after-edits")),
                description: Cow::Owned(t("setting-show-signature-after-edits-desc")),
                field: Box::new(SettingField {
                    json_path: Some("show_signature_help_after_edits"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .show_signature_help_after_edits
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.editor.show_signature_help_after_edits = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-snippet-sort-order")),
                description: Cow::Owned(t("setting-snippet-sort-order-desc")),
                field: Box::new(SettingField {
                    json_path: Some("snippet_sort_order"),
                    pick: |settings_content| settings_content.editor.snippet_sort_order.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.snippet_sort_order = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn hover_popover_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-hover-popover"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-hover-popover-enabled")),
                description: Cow::Owned(t("setting-hover-popover-enabled-desc")),
                field: Box::new(SettingField {
                    json_path: Some("hover_popover_enabled"),
                    pick: |settings_content| settings_content.editor.hover_popover_enabled.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.hover_popover_enabled = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            // todo(settings ui): add units to this number input
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-hover-popover-delay")),
                description: Cow::Owned(t("setting-hover-popover-delay-desc")),
                field: Box::new(SettingField {
                    json_path: Some("hover_popover_enabled"),
                    pick: |settings_content| settings_content.editor.hover_popover_delay.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.hover_popover_delay = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn drag_and_drop_selection_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-drag-drop"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-drag-drop-enabled")),
                description: Cow::Owned(t("setting-drag-drop-enabled-desc")),
                field: Box::new(SettingField {
                    json_path: Some("drag_and_drop_selection.enabled"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .drag_and_drop_selection
                            .as_ref()
                            .and_then(|drag_and_drop| drag_and_drop.enabled.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .drag_and_drop_selection
                            .get_or_insert_default()
                            .enabled = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-drag-drop-delay")),
                description: Cow::Owned(t("setting-drag-drop-delay-desc")),
                field: Box::new(SettingField {
                    json_path: Some("drag_and_drop_selection.delay"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .drag_and_drop_selection
                            .as_ref()
                            .and_then(|drag_and_drop| drag_and_drop.delay.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .drag_and_drop_selection
                            .get_or_insert_default()
                            .delay = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn gutter_section() -> [SettingsPageItem; 8] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-gutter"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-show-line-numbers")),
                description: Cow::Owned(t("setting-show-line-numbers-desc")),
                field: Box::new(SettingField {
                    json_path: Some("gutter.line_numbers"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .gutter
                            .as_ref()
                            .and_then(|gutter| gutter.line_numbers.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .gutter
                            .get_or_insert_default()
                            .line_numbers = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-relative-line-numbers")),
                description: Cow::Owned(t("setting-relative-line-numbers-desc")),
                field: Box::new(SettingField {
                    json_path: Some("relative_line_numbers"),
                    pick: |settings_content| settings_content.editor.relative_line_numbers.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.relative_line_numbers = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-show-runnables")),
                description: Cow::Owned(t("setting-show-runnables-desc")),
                field: Box::new(SettingField {
                    json_path: Some("gutter.runnables"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .gutter
                            .as_ref()
                            .and_then(|gutter| gutter.runnables.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .gutter
                            .get_or_insert_default()
                            .runnables = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-show-breakpoints")),
                description: Cow::Owned(t("setting-show-breakpoints-desc")),
                field: Box::new(SettingField {
                    json_path: Some("gutter.breakpoints"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .gutter
                            .as_ref()
                            .and_then(|gutter| gutter.breakpoints.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .gutter
                            .get_or_insert_default()
                            .breakpoints = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-show-folds")),
                description: Cow::Owned(t("setting-show-folds-desc")),
                field: Box::new(SettingField {
                    json_path: Some("gutter.folds"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .gutter
                            .as_ref()
                            .and_then(|gutter| gutter.folds.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content.editor.gutter.get_or_insert_default().folds = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-min-line-number-digits")),
                description: Cow::Owned(t("setting-min-line-number-digits-desc")),
                field: Box::new(SettingField {
                    json_path: Some("gutter.min_line_number_digits"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .gutter
                            .as_ref()
                            .and_then(|gutter| gutter.min_line_number_digits.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .gutter
                            .get_or_insert_default()
                            .min_line_number_digits = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-inline-code-actions")),
                description: Cow::Owned(t("setting-inline-code-actions-desc")),
                field: Box::new(SettingField {
                    json_path: Some("inline_code_actions"),
                    pick: |settings_content| settings_content.editor.inline_code_actions.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.inline_code_actions = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn scrollbar_section() -> [SettingsPageItem; 10] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-scrollbar"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-scrollbar-show")),
                description: Cow::Owned(t("setting-scrollbar-show-desc")),
                field: Box::new(SettingField {
                    json_path: Some("scrollbar"),
                    pick: |settings_content| {
                        settings_content.editor.scrollbar.as_ref()?.show.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .scrollbar
                            .get_or_insert_default()
                            .show = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-scrollbar-cursors")),
                description: Cow::Owned(t("setting-scrollbar-cursors-desc")),
                field: Box::new(SettingField {
                    json_path: Some("scrollbar.cursors"),
                    pick: |settings_content| {
                        settings_content.editor.scrollbar.as_ref()?.cursors.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .scrollbar
                            .get_or_insert_default()
                            .cursors = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-scrollbar-git-diff")),
                description: Cow::Owned(t("setting-scrollbar-git-diff-desc")),
                field: Box::new(SettingField {
                    json_path: Some("scrollbar.git_diff"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .scrollbar
                            .as_ref()?
                            .git_diff
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .scrollbar
                            .get_or_insert_default()
                            .git_diff = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-scrollbar-search-results")),
                description: Cow::Owned(t("setting-scrollbar-search-results-desc")),
                field: Box::new(SettingField {
                    json_path: Some("scrollbar.search_results"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .scrollbar
                            .as_ref()?
                            .search_results
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .scrollbar
                            .get_or_insert_default()
                            .search_results = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-scrollbar-selected-text")),
                description: Cow::Owned(t("setting-scrollbar-selected-text-desc")),
                field: Box::new(SettingField {
                    json_path: Some("scrollbar.selected_text"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .scrollbar
                            .as_ref()?
                            .selected_text
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .scrollbar
                            .get_or_insert_default()
                            .selected_text = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-scrollbar-selected-symbol")),
                description: Cow::Owned(t("setting-scrollbar-selected-symbol-desc")),
                field: Box::new(SettingField {
                    json_path: Some("scrollbar.selected_symbol"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .scrollbar
                            .as_ref()?
                            .selected_symbol
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .scrollbar
                            .get_or_insert_default()
                            .selected_symbol = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-scrollbar-diagnostics")),
                description: Cow::Owned(t("setting-scrollbar-diagnostics-desc")),
                field: Box::new(SettingField {
                    json_path: Some("scrollbar.diagnostics"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .scrollbar
                            .as_ref()?
                            .diagnostics
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .scrollbar
                            .get_or_insert_default()
                            .diagnostics = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-scrollbar-horizontal")),
                description: Cow::Owned(t("setting-scrollbar-horizontal-desc")),
                field: Box::new(SettingField {
                    json_path: Some("scrollbar.axes.horizontal"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .scrollbar
                            .as_ref()?
                            .axes
                            .as_ref()?
                            .horizontal
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .scrollbar
                            .get_or_insert_default()
                            .axes
                            .get_or_insert_default()
                            .horizontal = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-scrollbar-vertical")),
                description: Cow::Owned(t("setting-scrollbar-vertical-desc")),
                field: Box::new(SettingField {
                    json_path: Some("scrollbar.axes.vertical"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .scrollbar
                            .as_ref()?
                            .axes
                            .as_ref()?
                            .vertical
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .scrollbar
                            .get_or_insert_default()
                            .axes
                            .get_or_insert_default()
                            .vertical = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn minimap_section() -> [SettingsPageItem; 7] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-minimap"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-minimap-show")),
                description: Cow::Owned(t("setting-minimap-show-desc")),
                field: Box::new(SettingField {
                    json_path: Some("minimap.show"),
                    pick: |settings_content| {
                        settings_content.editor.minimap.as_ref()?.show.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.editor.minimap.get_or_insert_default().show = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-minimap-display-in")),
                description: Cow::Owned(t("setting-minimap-display-in-desc")),
                field: Box::new(SettingField {
                    json_path: Some("minimap.display_in"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .minimap
                            .as_ref()?
                            .display_in
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .minimap
                            .get_or_insert_default()
                            .display_in = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-minimap-thumb")),
                description: Cow::Owned(t("setting-minimap-thumb-desc")),
                field: Box::new(SettingField {
                    json_path: Some("minimap.thumb"),
                    pick: |settings_content| {
                        settings_content.editor.minimap.as_ref()?.thumb.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .minimap
                            .get_or_insert_default()
                            .thumb = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-minimap-thumb-border")),
                description: Cow::Owned(t("setting-minimap-thumb-border-desc")),
                field: Box::new(SettingField {
                    json_path: Some("minimap.thumb_border"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .minimap
                            .as_ref()?
                            .thumb_border
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .minimap
                            .get_or_insert_default()
                            .thumb_border = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-minimap-current-line-highlight")),
                description: Cow::Owned(t("setting-minimap-current-line-highlight-desc")),
                field: Box::new(SettingField {
                    json_path: Some("minimap.current_line_highlight"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .minimap
                            .as_ref()
                            .and_then(|minimap| minimap.current_line_highlight.as_ref())
                            .or(settings_content.editor.current_line_highlight.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .minimap
                            .get_or_insert_default()
                            .current_line_highlight = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-minimap-max-width-columns")),
                description: Cow::Owned(t("setting-minimap-max-width-columns-desc")),
                field: Box::new(SettingField {
                    json_path: Some("minimap.max_width_columns"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .minimap
                            .as_ref()?
                            .max_width_columns
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .minimap
                            .get_or_insert_default()
                            .max_width_columns = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn toolbar_section() -> [SettingsPageItem; 6] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-toolbar"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-toolbar-breadcrumbs")),
                description: Cow::Owned(t("setting-toolbar-breadcrumbs-desc")),
                field: Box::new(SettingField {
                    json_path: Some("toolbar.breadcrumbs"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .toolbar
                            .as_ref()?
                            .breadcrumbs
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .toolbar
                            .get_or_insert_default()
                            .breadcrumbs = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-toolbar-quick-actions")),
                description: Cow::Owned(t("setting-toolbar-quick-actions-desc")),
                field: Box::new(SettingField {
                    json_path: Some("toolbar.quick_actions"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .toolbar
                            .as_ref()?
                            .quick_actions
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .toolbar
                            .get_or_insert_default()
                            .quick_actions = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-toolbar-selections-menu")),
                description: Cow::Owned(t("setting-toolbar-selections-menu-desc")),
                field: Box::new(SettingField {
                    json_path: Some("toolbar.selections_menu"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .toolbar
                            .as_ref()?
                            .selections_menu
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .toolbar
                            .get_or_insert_default()
                            .selections_menu = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-toolbar-agent-review")),
                description: Cow::Owned(t("setting-toolbar-agent-review-desc")),
                field: Box::new(SettingField {
                    json_path: Some("toolbar.agent_review"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .toolbar
                            .as_ref()?
                            .agent_review
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .toolbar
                            .get_or_insert_default()
                            .agent_review = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-toolbar-code-actions")),
                description: Cow::Owned(t("setting-toolbar-code-actions-desc")),
                field: Box::new(SettingField {
                    json_path: Some("toolbar.code_actions"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .toolbar
                            .as_ref()?
                            .code_actions
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .toolbar
                            .get_or_insert_default()
                            .code_actions = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn vim_settings_section() -> [SettingsPageItem; 11] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-vim"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-vim-default-mode")),
                description: Cow::Owned(t("setting-vim-default-mode-desc")),
                field: Box::new(SettingField {
                    json_path: Some("vim.default_mode"),
                    pick: |settings_content| settings_content.vim.as_ref()?.default_mode.as_ref(),
                    write: |settings_content, value| {
                        settings_content.vim.get_or_insert_default().default_mode = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-vim-toggle-relative-line-numbers")),
                description: Cow::Owned(t("setting-vim-toggle-relative-line-numbers-desc")),
                field: Box::new(SettingField {
                    json_path: Some("vim.toggle_relative_line_numbers"),
                    pick: |settings_content| {
                        settings_content
                            .vim
                            .as_ref()?
                            .toggle_relative_line_numbers
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .vim
                            .get_or_insert_default()
                            .toggle_relative_line_numbers = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-vim-use-system-clipboard")),
                description: Cow::Owned(t("setting-vim-use-system-clipboard-desc")),
                field: Box::new(SettingField {
                    json_path: Some("vim.use_system_clipboard"),
                    pick: |settings_content| {
                        settings_content.vim.as_ref()?.use_system_clipboard.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .vim
                            .get_or_insert_default()
                            .use_system_clipboard = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-vim-use-smartcase-find")),
                description: Cow::Owned(t("setting-vim-use-smartcase-find-desc")),
                field: Box::new(SettingField {
                    json_path: Some("vim.use_smartcase_find"),
                    pick: |settings_content| {
                        settings_content.vim.as_ref()?.use_smartcase_find.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .vim
                            .get_or_insert_default()
                            .use_smartcase_find = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-vim-highlight-on-yank-duration")),
                description: Cow::Owned(t("setting-vim-highlight-on-yank-duration-desc")),
                field: Box::new(SettingField {
                    json_path: Some("vim.highlight_on_yank_duration"),
                    pick: |settings_content| {
                        settings_content
                            .vim
                            .as_ref()?
                            .highlight_on_yank_duration
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .vim
                            .get_or_insert_default()
                            .highlight_on_yank_duration = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-vim-cursor-shape-normal")),
                description: Cow::Owned(t("setting-vim-cursor-shape-normal-desc")),
                field: Box::new(SettingField {
                    json_path: Some("vim.cursor_shape.normal"),
                    pick: |settings_content| {
                        settings_content
                            .vim
                            .as_ref()?
                            .cursor_shape
                            .as_ref()?
                            .normal
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .vim
                            .get_or_insert_default()
                            .cursor_shape
                            .get_or_insert_default()
                            .normal = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-vim-cursor-shape-insert")),
                description: Cow::Owned(t("setting-vim-cursor-shape-insert-desc")),
                field: Box::new(SettingField {
                    json_path: Some("vim.cursor_shape.insert"),
                    pick: |settings_content| {
                        settings_content
                            .vim
                            .as_ref()?
                            .cursor_shape
                            .as_ref()?
                            .insert
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .vim
                            .get_or_insert_default()
                            .cursor_shape
                            .get_or_insert_default()
                            .insert = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-vim-cursor-shape-replace")),
                description: Cow::Owned(t("setting-vim-cursor-shape-replace-desc")),
                field: Box::new(SettingField {
                    json_path: Some("vim.cursor_shape.replace"),
                    pick: |settings_content| {
                        settings_content
                            .vim
                            .as_ref()?
                            .cursor_shape
                            .as_ref()?
                            .replace
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .vim
                            .get_or_insert_default()
                            .cursor_shape
                            .get_or_insert_default()
                            .replace = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-vim-cursor-shape-visual")),
                description: Cow::Owned(t("setting-vim-cursor-shape-visual-desc")),
                field: Box::new(SettingField {
                    json_path: Some("vim.cursor_shape.visual"),
                    pick: |settings_content| {
                        settings_content
                            .vim
                            .as_ref()?
                            .cursor_shape
                            .as_ref()?
                            .visual
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .vim
                            .get_or_insert_default()
                            .cursor_shape
                            .get_or_insert_default()
                            .visual = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-vim-custom-digraphs")),
                description: Cow::Owned(t("setting-vim-custom-digraphs-desc")),
                field: Box::new(
                    SettingField {
                        json_path: Some("vim.custom_digraphs"),
                        pick: |settings_content| {
                            settings_content.vim.as_ref()?.custom_digraphs.as_ref()
                        },
                        write: |settings_content, value| {
                            settings_content.vim.get_or_insert_default().custom_digraphs = value;
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER,
            }),
        ]
    }

    let items = concat_sections!(
        auto_save_section(),
        which_key_section(),
        multibuffer_section(),
        scrolling_section(),
        signature_help_section(),
        hover_popover_section(),
        drag_and_drop_selection_section(),
        gutter_section(),
        scrollbar_section(),
        minimap_section(),
        toolbar_section(),
        vim_settings_section(),
        language_settings_data(),
    );

    SettingsPage {
        title: Cow::Owned(t("settings-page-editor")),
        items: items,
    }
}

fn languages_and_tools_page(cx: &App) -> SettingsPage {
    fn file_types_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-file-types"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-file-type-associations")),
                description: Cow::Owned(t("setting-file-type-associations-desc")),
                field: Box::new(
                    SettingField {
                        json_path: Some("file_type_associations"),
                        pick: |settings_content| {
                            settings_content.project.all_languages.file_types.as_ref()
                        },
                        write: |settings_content, value| {
                            settings_content.project.all_languages.file_types = value;
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER | PROJECT,
            }),
        ]
    }

    fn diagnostics_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-diagnostics"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-diagnostics-max-severity")),
                description: Cow::Owned(t("setting-diagnostics-max-severity-desc")),
                field: Box::new(SettingField {
                    json_path: Some("diagnostics_max_severity"),
                    pick: |settings_content| {
                        settings_content.editor.diagnostics_max_severity.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.editor.diagnostics_max_severity = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-diagnostics-include-warnings")),
                description: Cow::Owned(t("setting-diagnostics-include-warnings-desc")),
                field: Box::new(SettingField {
                    json_path: Some("diagnostics.include_warnings"),
                    pick: |settings_content| {
                        settings_content
                            .diagnostics
                            .as_ref()?
                            .include_warnings
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .diagnostics
                            .get_or_insert_default()
                            .include_warnings = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn inline_diagnostics_section() -> [SettingsPageItem; 5] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-inline-diagnostics"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-inline-diagnostics-enabled")),
                description: Cow::Owned(t("setting-inline-diagnostics-enabled-desc")),
                field: Box::new(SettingField {
                    json_path: Some("diagnostics.inline.enabled"),
                    pick: |settings_content| {
                        settings_content
                            .diagnostics
                            .as_ref()?
                            .inline
                            .as_ref()?
                            .enabled
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .diagnostics
                            .get_or_insert_default()
                            .inline
                            .get_or_insert_default()
                            .enabled = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-inline-diagnostics-update-debounce")),
                description: Cow::Owned(t("setting-inline-diagnostics-update-debounce-desc")),
                field: Box::new(SettingField {
                    json_path: Some("diagnostics.inline.update_debounce_ms"),
                    pick: |settings_content| {
                        settings_content
                            .diagnostics
                            .as_ref()?
                            .inline
                            .as_ref()?
                            .update_debounce_ms
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .diagnostics
                            .get_or_insert_default()
                            .inline
                            .get_or_insert_default()
                            .update_debounce_ms = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-inline-diagnostics-padding")),
                description: Cow::Owned(t("setting-inline-diagnostics-padding-desc")),
                field: Box::new(SettingField {
                    json_path: Some("diagnostics.inline.padding"),
                    pick: |settings_content| {
                        settings_content
                            .diagnostics
                            .as_ref()?
                            .inline
                            .as_ref()?
                            .padding
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .diagnostics
                            .get_or_insert_default()
                            .inline
                            .get_or_insert_default()
                            .padding = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-inline-diagnostics-min-column")),
                description: Cow::Owned(t("setting-inline-diagnostics-min-column-desc")),
                field: Box::new(SettingField {
                    json_path: Some("diagnostics.inline.min_column"),
                    pick: |settings_content| {
                        settings_content
                            .diagnostics
                            .as_ref()?
                            .inline
                            .as_ref()?
                            .min_column
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .diagnostics
                            .get_or_insert_default()
                            .inline
                            .get_or_insert_default()
                            .min_column = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn lsp_pull_diagnostics_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-lsp-pull-diagnostics"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-lsp-pull-diagnostics-enabled")),
                description: Cow::Owned(t("setting-lsp-pull-diagnostics-enabled-desc")),
                field: Box::new(SettingField {
                    json_path: Some("diagnostics.lsp_pull_diagnostics.enabled"),
                    pick: |settings_content| {
                        settings_content
                            .diagnostics
                            .as_ref()?
                            .lsp_pull_diagnostics
                            .as_ref()?
                            .enabled
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .diagnostics
                            .get_or_insert_default()
                            .lsp_pull_diagnostics
                            .get_or_insert_default()
                            .enabled = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            // todo(settings_ui): Needs unit
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-lsp-pull-diagnostics-debounce")),
                description: Cow::Owned(t("setting-lsp-pull-diagnostics-debounce-desc")),
                field: Box::new(SettingField {
                    json_path: Some("diagnostics.lsp_pull_diagnostics.debounce_ms"),
                    pick: |settings_content| {
                        settings_content
                            .diagnostics
                            .as_ref()?
                            .lsp_pull_diagnostics
                            .as_ref()?
                            .debounce_ms
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .diagnostics
                            .get_or_insert_default()
                            .lsp_pull_diagnostics
                            .get_or_insert_default()
                            .debounce_ms = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn lsp_highlights_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-lsp-highlights"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-lsp-highlights-debounce")),
                description: Cow::Owned(t("setting-lsp-highlights-debounce-desc")),
                field: Box::new(SettingField {
                    json_path: Some("lsp_highlight_debounce"),
                    pick: |settings_content| {
                        settings_content.editor.lsp_highlight_debounce.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.editor.lsp_highlight_debounce = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn languages_list_section(cx: &App) -> Box<[SettingsPageItem]> {
        // todo(settings_ui): Refresh on extension (un)/installed
        // Note that `crates/json_schema_store` solves the same problem, there is probably a way to unify the two
        std::iter::once(SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-languages"))))
            .chain(all_language_names(cx).into_iter().map(|language_name| {
                let link = format!("languages.{language_name}");
                SettingsPageItem::SubPageLink(SubPageLink {
                    title: language_name,
                    r#type: crate::SubPageType::Language,
                    description: None,
                    json_path: Some(link.leak()),
                    in_json: true,
                    files: USER | PROJECT,
                    render: |this, scroll_handle, window, cx| {
                        let items: Box<[SettingsPageItem]> = concat_sections!(
                            language_settings_data(),
                            non_editor_language_settings_data(),
                            edit_prediction_language_settings_section()
                        );
                        this.render_sub_page_items(
                            items.iter().enumerate(),
                            scroll_handle,
                            window,
                            cx,
                        )
                        .into_any_element()
                    },
                })
            }))
            .collect()
    }

    SettingsPage {
        title: Cow::Owned(t("settings-page-languages-tools")),
        items: {
            concat_sections!(
                non_editor_language_settings_data(),
                file_types_section(),
                diagnostics_section(),
                inline_diagnostics_section(),
                lsp_pull_diagnostics_section(),
                lsp_highlights_section(),
                languages_list_section(cx),
            )
        },
    }
}

fn search_and_files_page() -> SettingsPage {
    fn search_section() -> [SettingsPageItem; 9] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-search"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-search-whole-word")),
                description: Cow::Owned(t("setting-search-whole-word-desc")),
                field: Box::new(SettingField {
                    json_path: Some("search.whole_word"),
                    pick: |settings_content| {
                        settings_content.editor.search.as_ref()?.whole_word.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .search
                            .get_or_insert_default()
                            .whole_word = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-search-case-sensitive")),
                description: Cow::Owned(t("setting-search-case-sensitive-desc")),
                field: Box::new(SettingField {
                    json_path: Some("search.case_sensitive"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .search
                            .as_ref()?
                            .case_sensitive
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .search
                            .get_or_insert_default()
                            .case_sensitive = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-search-use-smartcase")),
                description: Cow::Owned(t("setting-search-use-smartcase-desc")),
                field: Box::new(SettingField {
                    json_path: Some("use_smartcase_search"),
                    pick: |settings_content| settings_content.editor.use_smartcase_search.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.use_smartcase_search = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-search-include-ignored")),
                description: Cow::Owned(t("setting-search-include-ignored-desc")),
                field: Box::new(SettingField {
                    json_path: Some("search.include_ignored"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .search
                            .as_ref()?
                            .include_ignored
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .search
                            .get_or_insert_default()
                            .include_ignored = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-search-regex")),
                description: Cow::Owned(t("setting-search-regex-desc")),
                field: Box::new(SettingField {
                    json_path: Some("search.regex"),
                    pick: |settings_content| {
                        settings_content.editor.search.as_ref()?.regex.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.editor.search.get_or_insert_default().regex = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-search-wrap")),
                description: Cow::Owned(t("setting-search-wrap-desc")),
                field: Box::new(SettingField {
                    json_path: Some("search_wrap"),
                    pick: |settings_content| settings_content.editor.search_wrap.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.search_wrap = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-search-center-on-match")),
                description: Cow::Owned(t("setting-search-center-on-match-desc")),
                field: Box::new(SettingField {
                    json_path: Some("editor.search.center_on_match"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .search
                            .as_ref()
                            .and_then(|search| search.center_on_match.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .search
                            .get_or_insert_default()
                            .center_on_match = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-search-seed-from-cursor")),
                description: Cow::Owned(t("setting-search-seed-from-cursor-desc")),
                field: Box::new(SettingField {
                    json_path: Some("seed_search_query_from_cursor"),
                    pick: |settings_content| {
                        settings_content
                            .editor
                            .seed_search_query_from_cursor
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.editor.seed_search_query_from_cursor = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn file_finder_section() -> [SettingsPageItem; 6] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-file-finder"))),
            // todo: null by default
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-file-finder-include-ignored")),
                description: Cow::Owned(t("setting-file-finder-include-ignored-desc")),
                field: Box::new(SettingField {
                    json_path: Some("file_finder.include_ignored"),
                    pick: |settings_content| {
                        settings_content
                            .file_finder
                            .as_ref()?
                            .include_ignored
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .file_finder
                            .get_or_insert_default()
                            .include_ignored = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-file-finder-file-icons")),
                description: Cow::Owned(t("setting-file-finder-file-icons-desc")),
                field: Box::new(SettingField {
                    json_path: Some("file_finder.file_icons"),
                    pick: |settings_content| {
                        settings_content.file_finder.as_ref()?.file_icons.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .file_finder
                            .get_or_insert_default()
                            .file_icons = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-file-finder-modal-max-width")),
                description: Cow::Owned(t("setting-file-finder-modal-max-width-desc")),
                field: Box::new(SettingField {
                    json_path: Some("file_finder.modal_max_width"),
                    pick: |settings_content| {
                        settings_content
                            .file_finder
                            .as_ref()?
                            .modal_max_width
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .file_finder
                            .get_or_insert_default()
                            .modal_max_width = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-file-finder-skip-focus-for-active")),
                description: Cow::Owned(t("setting-file-finder-skip-focus-for-active-desc")),
                field: Box::new(SettingField {
                    json_path: Some("file_finder.skip_focus_for_active_in_search"),
                    pick: |settings_content| {
                        settings_content
                            .file_finder
                            .as_ref()?
                            .skip_focus_for_active_in_search
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .file_finder
                            .get_or_insert_default()
                            .skip_focus_for_active_in_search = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-file-finder-git-status")),
                description: Cow::Owned(t("setting-file-finder-git-status-desc")),
                field: Box::new(SettingField {
                    json_path: Some("file_finder.git_status"),
                    pick: |settings_content| {
                        settings_content.file_finder.as_ref()?.git_status.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .file_finder
                            .get_or_insert_default()
                            .git_status = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn file_scan_section() -> [SettingsPageItem; 5] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-file-scan"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-file-scan-exclusions")),
                description: Cow::Owned(t("setting-file-scan-exclusions-desc")),
                field: Box::new(
                    SettingField {
                        json_path: Some("file_scan_exclusions"),
                        pick: |settings_content| {
                            settings_content
                                .project
                                .worktree
                                .file_scan_exclusions
                                .as_ref()
                        },
                        write: |settings_content, value| {
                            settings_content.project.worktree.file_scan_exclusions = value;
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-file-scan-inclusions")),
                description: Cow::Owned(t("setting-file-scan-inclusions-desc")),
                field: Box::new(
                    SettingField {
                        json_path: Some("file_scan_inclusions"),
                        pick: |settings_content| {
                            settings_content
                                .project
                                .worktree
                                .file_scan_inclusions
                                .as_ref()
                        },
                        write: |settings_content, value| {
                            settings_content.project.worktree.file_scan_inclusions = value;
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-restore-file-state")),
                description: Cow::Owned(t("setting-restore-file-state-desc")),
                field: Box::new(SettingField {
                    json_path: Some("restore_on_file_reopen"),
                    pick: |settings_content| {
                        settings_content.workspace.restore_on_file_reopen.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.workspace.restore_on_file_reopen = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-close-on-file-delete")),
                description: Cow::Owned(t("setting-close-on-file-delete-desc")),
                field: Box::new(SettingField {
                    json_path: Some("close_on_file_delete"),
                    pick: |settings_content| {
                        settings_content.workspace.close_on_file_delete.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.workspace.close_on_file_delete = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    SettingsPage {
        title: Cow::Owned(t("settings-page-search-files")),
        items: concat_sections![search_section(), file_finder_section(), file_scan_section()],
    }
}

fn window_and_layout_page() -> SettingsPage {
    fn status_bar_section() -> [SettingsPageItem; 9] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-status-bar"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-status-bar-project-panel-button")),
                description: Cow::Owned(t("setting-status-bar-project-panel-button-desc")),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.button"),
                    pick: |settings_content| {
                        settings_content.project_panel.as_ref()?.button.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .button = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-status-bar-active-language-button")),
                description: Cow::Owned(t("setting-status-bar-active-language-button-desc")),
                field: Box::new(SettingField {
                    json_path: Some("status_bar.active_language_button"),
                    pick: |settings_content| {
                        settings_content
                            .status_bar
                            .as_ref()?
                            .active_language_button
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .status_bar
                            .get_or_insert_default()
                            .active_language_button = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-status-bar-active-encoding-button")),
                description: Cow::Owned(t("setting-status-bar-active-encoding-button-desc")),
                field: Box::new(SettingField {
                    json_path: Some("status_bar.active_encoding_button"),
                    pick: |settings_content| {
                        settings_content
                            .status_bar
                            .as_ref()?
                            .active_encoding_button
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .status_bar
                            .get_or_insert_default()
                            .active_encoding_button = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-status-bar-cursor-position-button")),
                description: Cow::Owned(t("setting-status-bar-cursor-position-button-desc")),
                field: Box::new(SettingField {
                    json_path: Some("status_bar.cursor_position_button"),
                    pick: |settings_content| {
                        settings_content
                            .status_bar
                            .as_ref()?
                            .cursor_position_button
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .status_bar
                            .get_or_insert_default()
                            .cursor_position_button = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-status-bar-terminal-button")),
                description: Cow::Owned(t("setting-status-bar-terminal-button-desc")),
                field: Box::new(SettingField {
                    json_path: Some("terminal.button"),
                    pick: |settings_content| settings_content.terminal.as_ref()?.button.as_ref(),
                    write: |settings_content, value| {
                        settings_content.terminal.get_or_insert_default().button = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-status-bar-diagnostics-button")),
                description: Cow::Owned(t("setting-status-bar-diagnostics-button-desc")),
                field: Box::new(SettingField {
                    json_path: Some("diagnostics.button"),
                    pick: |settings_content| settings_content.diagnostics.as_ref()?.button.as_ref(),
                    write: |settings_content, value| {
                        settings_content.diagnostics.get_or_insert_default().button = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-status-bar-project-search-button")),
                description: Cow::Owned(t("setting-status-bar-project-search-button-desc")),
                field: Box::new(SettingField {
                    json_path: Some("search.button"),
                    pick: |settings_content| {
                        settings_content.editor.search.as_ref()?.button.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .editor
                            .search
                            .get_or_insert_default()
                            .button = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-status-bar-debugger-button")),
                description: Cow::Owned(t("setting-status-bar-debugger-button-desc")),
                field: Box::new(SettingField {
                    json_path: Some("debugger.button"),
                    pick: |settings_content| settings_content.debugger.as_ref()?.button.as_ref(),
                    write: |settings_content, value| {
                        settings_content.debugger.get_or_insert_default().button = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn title_bar_section() -> [SettingsPageItem; 9] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-title-bar"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-title-bar-show-branch-icon")),
                description: Cow::Owned(t("setting-title-bar-show-branch-icon-desc")),
                field: Box::new(SettingField {
                    json_path: Some("title_bar.show_branch_icon"),
                    pick: |settings_content| {
                        settings_content
                            .title_bar
                            .as_ref()?
                            .show_branch_icon
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .title_bar
                            .get_or_insert_default()
                            .show_branch_icon = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-title-bar-show-branch-name")),
                description: Cow::Owned(t("setting-title-bar-show-branch-name-desc")),
                field: Box::new(SettingField {
                    json_path: Some("title_bar.show_branch_name"),
                    pick: |settings_content| {
                        settings_content
                            .title_bar
                            .as_ref()?
                            .show_branch_name
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .title_bar
                            .get_or_insert_default()
                            .show_branch_name = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-title-bar-show-project-items")),
                description: Cow::Owned(t("setting-title-bar-show-project-items-desc")),
                field: Box::new(SettingField {
                    json_path: Some("title_bar.show_project_items"),
                    pick: |settings_content| {
                        settings_content
                            .title_bar
                            .as_ref()?
                            .show_project_items
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .title_bar
                            .get_or_insert_default()
                            .show_project_items = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-title-bar-show-onboarding-banner")),
                description: Cow::Owned(t("setting-title-bar-show-onboarding-banner-desc")),
                field: Box::new(SettingField {
                    json_path: Some("title_bar.show_onboarding_banner"),
                    pick: |settings_content| {
                        settings_content
                            .title_bar
                            .as_ref()?
                            .show_onboarding_banner
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .title_bar
                            .get_or_insert_default()
                            .show_onboarding_banner = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-title-bar-show-sign-in")),
                description: Cow::Owned(t("setting-title-bar-show-sign-in-desc")),
                field: Box::new(SettingField {
                    json_path: Some("title_bar.show_sign_in"),
                    pick: |settings_content| {
                        settings_content.title_bar.as_ref()?.show_sign_in.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .title_bar
                            .get_or_insert_default()
                            .show_sign_in = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-title-bar-show-user-menu")),
                description: Cow::Owned(t("setting-title-bar-show-user-menu-desc")),
                field: Box::new(SettingField {
                    json_path: Some("title_bar.show_user_menu"),
                    pick: |settings_content| {
                        settings_content.title_bar.as_ref()?.show_user_menu.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .title_bar
                            .get_or_insert_default()
                            .show_user_menu = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-title-bar-show-user-picture")),
                description: Cow::Owned(t("setting-title-bar-show-user-picture-desc")),
                field: Box::new(SettingField {
                    json_path: Some("title_bar.show_user_picture"),
                    pick: |settings_content| {
                        settings_content
                            .title_bar
                            .as_ref()?
                            .show_user_picture
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .title_bar
                            .get_or_insert_default()
                            .show_user_picture = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-title-bar-show-menus")),
                description: Cow::Owned(t("setting-title-bar-show-menus-desc")),
                field: Box::new(SettingField {
                    json_path: Some("title_bar.show_menus"),
                    pick: |settings_content| {
                        settings_content.title_bar.as_ref()?.show_menus.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .title_bar
                            .get_or_insert_default()
                            .show_menus = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn tab_bar_section() -> [SettingsPageItem; 9] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-tab-bar"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-tab-bar-show")),
                description: Cow::Owned(t("setting-tab-bar-show-desc")),
                field: Box::new(SettingField {
                    json_path: Some("tab_bar.show"),
                    pick: |settings_content| settings_content.tab_bar.as_ref()?.show.as_ref(),
                    write: |settings_content, value| {
                        settings_content.tab_bar.get_or_insert_default().show = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-tab-bar-git-status")),
                description: Cow::Owned(t("setting-tab-bar-git-status-desc")),
                field: Box::new(SettingField {
                    json_path: Some("tabs.git_status"),
                    pick: |settings_content| settings_content.tabs.as_ref()?.git_status.as_ref(),
                    write: |settings_content, value| {
                        settings_content.tabs.get_or_insert_default().git_status = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-tab-bar-file-icons")),
                description: Cow::Owned(t("setting-tab-bar-file-icons-desc")),
                field: Box::new(SettingField {
                    json_path: Some("tabs.file_icons"),
                    pick: |settings_content| settings_content.tabs.as_ref()?.file_icons.as_ref(),
                    write: |settings_content, value| {
                        settings_content.tabs.get_or_insert_default().file_icons = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-tab-bar-close-position")),
                description: Cow::Owned(t("setting-tab-bar-close-position-desc")),
                field: Box::new(SettingField {
                    json_path: Some("tabs.close_position"),
                    pick: |settings_content| {
                        settings_content.tabs.as_ref()?.close_position.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.tabs.get_or_insert_default().close_position = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                files: USER,
                title: Cow::Owned(t("setting-tab-bar-max-tabs")),
                description: Cow::Owned(t("setting-tab-bar-max-tabs-desc")),
                // todo(settings_ui): The default for this value is null and it's use in code
                // is complex, so I'm going to come back to this later
                field: Box::new(
                    SettingField {
                        json_path: Some("max_tabs"),
                        pick: |settings_content| settings_content.workspace.max_tabs.as_ref(),
                        write: |settings_content, value| {
                            settings_content.workspace.max_tabs = value;
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-tab-bar-show-nav-history-buttons")),
                description: Cow::Owned(t("setting-tab-bar-show-nav-history-buttons-desc")),
                field: Box::new(SettingField {
                    json_path: Some("tab_bar.show_nav_history_buttons"),
                    pick: |settings_content| {
                        settings_content
                            .tab_bar
                            .as_ref()?
                            .show_nav_history_buttons
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .tab_bar
                            .get_or_insert_default()
                            .show_nav_history_buttons = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-tab-bar-show-buttons")),
                description: Cow::Owned(t("setting-tab-bar-show-buttons-desc")),
                field: Box::new(SettingField {
                    json_path: Some("tab_bar.show_tab_bar_buttons"),
                    pick: |settings_content| {
                        settings_content
                            .tab_bar
                            .as_ref()?
                            .show_tab_bar_buttons
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .tab_bar
                            .get_or_insert_default()
                            .show_tab_bar_buttons = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-tab-bar-pinned-tabs-layout")),
                description: Cow::Owned(t("setting-tab-bar-pinned-tabs-layout-desc")),
                field: Box::new(SettingField {
                    json_path: Some("tab_bar.show_pinned_tabs_in_separate_row"),
                    pick: |settings_content| {
                        settings_content
                            .tab_bar
                            .as_ref()?
                            .show_pinned_tabs_in_separate_row
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .tab_bar
                            .get_or_insert_default()
                            .show_pinned_tabs_in_separate_row = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn tab_settings_section() -> [SettingsPageItem; 4] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-tab-settings"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-tab-activate-on-close")),
                description: Cow::Owned(t("setting-tab-activate-on-close-desc")),
                field: Box::new(SettingField {
                    json_path: Some("tabs.activate_on_close"),
                    pick: |settings_content| {
                        settings_content.tabs.as_ref()?.activate_on_close.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .tabs
                            .get_or_insert_default()
                            .activate_on_close = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-tab-show-diagnostics")),
                description: Cow::Owned(t("setting-tab-show-diagnostics-desc")),
                field: Box::new(SettingField {
                    json_path: Some("tabs.show_diagnostics"),
                    pick: |settings_content| {
                        settings_content.tabs.as_ref()?.show_diagnostics.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .tabs
                            .get_or_insert_default()
                            .show_diagnostics = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-tab-show-close-button")),
                description: Cow::Owned(t("setting-tab-show-close-button-desc")),
                field: Box::new(SettingField {
                    json_path: Some("tabs.show_close_button"),
                    pick: |settings_content| {
                        settings_content.tabs.as_ref()?.show_close_button.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .tabs
                            .get_or_insert_default()
                            .show_close_button = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn preview_tabs_section() -> [SettingsPageItem; 8] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-preview-tabs"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-preview-tabs-enabled")),
                description: Cow::Owned(t("setting-preview-tabs-enabled-desc")),
                field: Box::new(SettingField {
                    json_path: Some("preview_tabs.enabled"),
                    pick: |settings_content| {
                        settings_content.preview_tabs.as_ref()?.enabled.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .preview_tabs
                            .get_or_insert_default()
                            .enabled = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-preview-tabs-from-project-panel")),
                description: Cow::Owned(t("setting-preview-tabs-from-project-panel-desc")),
                field: Box::new(SettingField {
                    json_path: Some("preview_tabs.enable_preview_from_project_panel"),
                    pick: |settings_content| {
                        settings_content
                            .preview_tabs
                            .as_ref()?
                            .enable_preview_from_project_panel
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .preview_tabs
                            .get_or_insert_default()
                            .enable_preview_from_project_panel = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-preview-tabs-from-file-finder")),
                description: Cow::Owned(t("setting-preview-tabs-from-file-finder-desc")),
                field: Box::new(SettingField {
                    json_path: Some("preview_tabs.enable_preview_from_file_finder"),
                    pick: |settings_content| {
                        settings_content
                            .preview_tabs
                            .as_ref()?
                            .enable_preview_from_file_finder
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .preview_tabs
                            .get_or_insert_default()
                            .enable_preview_from_file_finder = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-preview-tabs-from-multibuffer")),
                description: Cow::Owned(t("setting-preview-tabs-from-multibuffer-desc")),
                field: Box::new(SettingField {
                    json_path: Some("preview_tabs.enable_preview_from_multibuffer"),
                    pick: |settings_content| {
                        settings_content
                            .preview_tabs
                            .as_ref()?
                            .enable_preview_from_multibuffer
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .preview_tabs
                            .get_or_insert_default()
                            .enable_preview_from_multibuffer = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-preview-tabs-multibuffer-from-code-nav")),
                description: Cow::Owned(t("setting-preview-tabs-multibuffer-from-code-nav-desc")),
                field: Box::new(SettingField {
                    json_path: Some("preview_tabs.enable_preview_multibuffer_from_code_navigation"),
                    pick: |settings_content| {
                        settings_content
                            .preview_tabs
                            .as_ref()?
                            .enable_preview_multibuffer_from_code_navigation
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .preview_tabs
                            .get_or_insert_default()
                            .enable_preview_multibuffer_from_code_navigation = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-preview-tabs-file-from-code-nav")),
                description: Cow::Owned(t("setting-preview-tabs-file-from-code-nav-desc")),
                field: Box::new(SettingField {
                    json_path: Some("preview_tabs.enable_preview_file_from_code_navigation"),
                    pick: |settings_content| {
                        settings_content
                            .preview_tabs
                            .as_ref()?
                            .enable_preview_file_from_code_navigation
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .preview_tabs
                            .get_or_insert_default()
                            .enable_preview_file_from_code_navigation = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-preview-tabs-keep-preview-on-code-nav")),
                description: Cow::Owned(t("setting-preview-tabs-keep-preview-on-code-nav-desc")),
                field: Box::new(SettingField {
                    json_path: Some("preview_tabs.enable_keep_preview_on_code_navigation"),
                    pick: |settings_content| {
                        settings_content
                            .preview_tabs
                            .as_ref()?
                            .enable_keep_preview_on_code_navigation
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .preview_tabs
                            .get_or_insert_default()
                            .enable_keep_preview_on_code_navigation = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn layout_section() -> [SettingsPageItem; 4] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-layout"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-layout-bottom-dock")),
                description: Cow::Owned(t("setting-layout-bottom-dock-desc")),
                field: Box::new(SettingField {
                    json_path: Some("bottom_dock_layout"),
                    pick: |settings_content| settings_content.workspace.bottom_dock_layout.as_ref(),
                    write: |settings_content, value| {
                        settings_content.workspace.bottom_dock_layout = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                files: USER,
                title: Cow::Owned(t("setting-layout-centered-left-padding")),
                description: Cow::Owned(t("setting-layout-centered-left-padding-desc")),
                field: Box::new(SettingField {
                    json_path: Some("centered_layout.left_padding"),
                    pick: |settings_content| {
                        settings_content
                            .workspace
                            .centered_layout
                            .as_ref()?
                            .left_padding
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .workspace
                            .centered_layout
                            .get_or_insert_default()
                            .left_padding = value;
                    },
                }),
                metadata: None,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                files: USER,
                title: Cow::Owned(t("setting-layout-centered-right-padding")),
                description: Cow::Owned(t("setting-layout-centered-right-padding-desc")),
                field: Box::new(SettingField {
                    json_path: Some("centered_layout.right_padding"),
                    pick: |settings_content| {
                        settings_content
                            .workspace
                            .centered_layout
                            .as_ref()?
                            .right_padding
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .workspace
                            .centered_layout
                            .get_or_insert_default()
                            .right_padding = value;
                    },
                }),
                metadata: None,
            }),
        ]
    }

    fn window_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-window"))),
            // todo(settings_ui): Should we filter by platform.as_ref()?
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-window-use-system-tabs")),
                description: Cow::Owned(t("setting-window-use-system-tabs-desc")),
                field: Box::new(SettingField {
                    json_path: Some("use_system_window_tabs"),
                    pick: |settings_content| {
                        settings_content.workspace.use_system_window_tabs.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.workspace.use_system_window_tabs = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-window-decorations")),
                description: Cow::Owned(t("setting-window-decorations-desc")),
                field: Box::new(SettingField {
                    json_path: Some("window_decorations"),
                    pick: |settings_content| settings_content.workspace.window_decorations.as_ref(),
                    write: |settings_content, value| {
                        settings_content.workspace.window_decorations = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn pane_modifiers_section() -> [SettingsPageItem; 4] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-pane-modifiers"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-pane-inactive-opacity")),
                description: Cow::Owned(t("setting-pane-inactive-opacity-desc")),
                field: Box::new(SettingField {
                    json_path: Some("active_pane_modifiers.inactive_opacity"),
                    pick: |settings_content| {
                        settings_content
                            .workspace
                            .active_pane_modifiers
                            .as_ref()?
                            .inactive_opacity
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .workspace
                            .active_pane_modifiers
                            .get_or_insert_default()
                            .inactive_opacity = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-pane-border-size")),
                description: Cow::Owned(t("setting-pane-border-size-desc")),
                field: Box::new(SettingField {
                    json_path: Some("active_pane_modifiers.border_size"),
                    pick: |settings_content| {
                        settings_content
                            .workspace
                            .active_pane_modifiers
                            .as_ref()?
                            .border_size
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .workspace
                            .active_pane_modifiers
                            .get_or_insert_default()
                            .border_size = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-pane-zoomed-padding")),
                description: Cow::Owned(t("setting-pane-zoomed-padding-desc")),
                field: Box::new(SettingField {
                    json_path: Some("zoomed_padding"),
                    pick: |settings_content| settings_content.workspace.zoomed_padding.as_ref(),
                    write: |settings_content, value| {
                        settings_content.workspace.zoomed_padding = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn pane_split_direction_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-pane-split-direction"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-pane-split-vertical")),
                description: Cow::Owned(t("setting-pane-split-vertical-desc")),
                field: Box::new(SettingField {
                    json_path: Some("pane_split_direction_vertical"),
                    pick: |settings_content| {
                        settings_content
                            .workspace
                            .pane_split_direction_vertical
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.workspace.pane_split_direction_vertical = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-pane-split-horizontal")),
                description: Cow::Owned(t("setting-pane-split-horizontal-desc")),
                field: Box::new(SettingField {
                    json_path: Some("pane_split_direction_horizontal"),
                    pick: |settings_content| {
                        settings_content
                            .workspace
                            .pane_split_direction_horizontal
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.workspace.pane_split_direction_horizontal = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    SettingsPage {
        title: Cow::Owned(t("settings-page-window-layout")),
        items: concat_sections![
            status_bar_section(),
            title_bar_section(),
            tab_bar_section(),
            tab_settings_section(),
            preview_tabs_section(),
            layout_section(),
            window_section(),
            pane_modifiers_section(),
            pane_split_direction_section(),
        ],
    }
}

fn panels_page() -> SettingsPage {
    fn project_panel_section() -> [SettingsPageItem; 20] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-project-panel"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-project-panel-dock")),
                description: Cow::Owned(t("setting-project-panel-dock-desc")),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.dock"),
                    pick: |settings_content| settings_content.project_panel.as_ref()?.dock.as_ref(),
                    write: |settings_content, value| {
                        settings_content.project_panel.get_or_insert_default().dock = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Owned(t("setting-project-panel-default-width")),
                description: Cow::Owned(t("setting-project-panel-default-width-desc")),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.default_width"),
                    pick: |settings_content| {
                        settings_content
                            .project_panel
                            .as_ref()?
                            .default_width
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .default_width = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Hide .gitignore"),
                description: Cow::Borrowed("Whether to hide the gitignore entries in the project panel."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.hide_gitignore"),
                    pick: |settings_content| {
                        settings_content
                            .project_panel
                            .as_ref()?
                            .hide_gitignore
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .hide_gitignore = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Entry Spacing"),
                description: Cow::Borrowed("Spacing between worktree entries in the project panel."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.entry_spacing"),
                    pick: |settings_content| {
                        settings_content
                            .project_panel
                            .as_ref()?
                            .entry_spacing
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .entry_spacing = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("File Icons"),
                description: Cow::Borrowed("Show file icons in the project panel."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.file_icons"),
                    pick: |settings_content| {
                        settings_content.project_panel.as_ref()?.file_icons.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .file_icons = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Folder Icons"),
                description: Cow::Borrowed("Whether to show folder icons or chevrons for directories in the project panel."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.folder_icons"),
                    pick: |settings_content| {
                        settings_content
                            .project_panel
                            .as_ref()?
                            .folder_icons
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .folder_icons = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Git Status"),
                description: Cow::Borrowed("Show the Git status in the project panel."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.git_status"),
                    pick: |settings_content| {
                        settings_content.project_panel.as_ref()?.git_status.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .git_status = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Indent Size"),
                description: Cow::Borrowed("Amount of indentation for nested items."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.indent_size"),
                    pick: |settings_content| {
                        settings_content
                            .project_panel
                            .as_ref()?
                            .indent_size
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .indent_size = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Auto Reveal Entries"),
                description: Cow::Borrowed("Whether to reveal entries in the project panel automatically when a corresponding project entry becomes active."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.auto_reveal_entries"),
                    pick: |settings_content| {
                        settings_content
                            .project_panel
                            .as_ref()?
                            .auto_reveal_entries
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .auto_reveal_entries = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Starts Open"),
                description: Cow::Borrowed("Whether the project panel should open on startup."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.starts_open"),
                    pick: |settings_content| {
                        settings_content
                            .project_panel
                            .as_ref()?
                            .starts_open
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .starts_open = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Auto Fold Directories"),
                description: Cow::Borrowed("Whether to fold directories automatically and show compact folders when a directory has only one subdirectory inside."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.auto_fold_dirs"),
                    pick: |settings_content| {
                        settings_content
                            .project_panel
                            .as_ref()?
                            .auto_fold_dirs
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .auto_fold_dirs = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Show Scrollbar"),
                description: Cow::Borrowed("Show the scrollbar in the project panel."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.scrollbar.show"),
                    pick: |settings_content| {
                        show_scrollbar_or_editor(settings_content, |settings_content| {
                            settings_content
                                .project_panel
                                .as_ref()?
                                .scrollbar
                                .as_ref()?
                                .show
                                .as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .scrollbar
                            .get_or_insert_default()
                            .show = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Show Diagnostics"),
                description: Cow::Borrowed("Which files containing diagnostic errors/warnings to mark in the project panel."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.show_diagnostics"),
                    pick: |settings_content| {
                        settings_content
                            .project_panel
                            .as_ref()?
                            .show_diagnostics
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .show_diagnostics = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Sticky Scroll"),
                description: Cow::Borrowed("Whether to stick parent directories at top of the project panel."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.sticky_scroll"),
                    pick: |settings_content| {
                        settings_content
                            .project_panel
                            .as_ref()?
                            .sticky_scroll
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .sticky_scroll = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                files: USER,
                title: Cow::Borrowed("Show Indent Guides"),
                description: Cow::Borrowed("Show indent guides in the project panel."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.indent_guides.show"),
                    pick: |settings_content| {
                        settings_content
                            .project_panel
                            .as_ref()?
                            .indent_guides
                            .as_ref()?
                            .show
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .indent_guides
                            .get_or_insert_default()
                            .show = value;
                    },
                }),
                metadata: None,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Drag and Drop"),
                description: Cow::Borrowed("Whether to enable drag-and-drop operations in the project panel."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.drag_and_drop"),
                    pick: |settings_content| {
                        settings_content
                            .project_panel
                            .as_ref()?
                            .drag_and_drop
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .drag_and_drop = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Hide Root"),
                description: Cow::Borrowed("Whether to hide the root entry when only one folder is open in the window."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.drag_and_drop"),
                    pick: |settings_content| {
                        settings_content.project_panel.as_ref()?.hide_root.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .hide_root = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Hide Hidden"),
                description: Cow::Borrowed("Whether to hide the hidden entries in the project panel."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.hide_hidden"),
                    pick: |settings_content| {
                        settings_content
                            .project_panel
                            .as_ref()?
                            .hide_hidden
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .hide_hidden = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Hidden Files"),
                description: Cow::Borrowed("Globs to match files that will be considered \"hidden\" and can be hidden from the project panel."),
                field: Box::new(
                    SettingField {
                        json_path: Some("worktree.hidden_files"),
                        pick: |settings_content| {
                            settings_content.project.worktree.hidden_files.as_ref()
                        },
                        write: |settings_content, value| {
                            settings_content.project.worktree.hidden_files = value;
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn auto_open_files_section() -> [SettingsPageItem; 5] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Auto Open Files")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("On Create"),
                description: Cow::Borrowed("Whether to automatically open newly created files in the editor."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.auto_open.on_create"),
                    pick: |settings_content| {
                        settings_content
                            .project_panel
                            .as_ref()?
                            .auto_open
                            .as_ref()?
                            .on_create
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .auto_open
                            .get_or_insert_default()
                            .on_create = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("On Paste"),
                description: Cow::Borrowed("Whether to automatically open files after pasting or duplicating them."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.auto_open.on_paste"),
                    pick: |settings_content| {
                        settings_content
                            .project_panel
                            .as_ref()?
                            .auto_open
                            .as_ref()?
                            .on_paste
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .auto_open
                            .get_or_insert_default()
                            .on_paste = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("On Drop"),
                description: Cow::Borrowed("Whether to automatically open files dropped from external sources."),
                field: Box::new(SettingField {
                    json_path: Some("project_panel.auto_open.on_drop"),
                    pick: |settings_content| {
                        settings_content
                            .project_panel
                            .as_ref()?
                            .auto_open
                            .as_ref()?
                            .on_drop
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .auto_open
                            .get_or_insert_default()
                            .on_drop = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Sort Mode"),
                description: Cow::Borrowed("Sort order for entries in the project panel."),
                field: Box::new(SettingField {
                    pick: |settings_content| {
                        settings_content.project_panel.as_ref()?.sort_mode.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project_panel
                            .get_or_insert_default()
                            .sort_mode = value;
                    },
                    json_path: Some("project_panel.sort_mode"),
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn terminal_panel_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Terminal Panel")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Terminal Dock"),
                description: Cow::Borrowed("Where to dock the terminal panel."),
                field: Box::new(SettingField {
                    json_path: Some("terminal.dock"),
                    pick: |settings_content| settings_content.terminal.as_ref()?.dock.as_ref(),
                    write: |settings_content, value| {
                        settings_content.terminal.get_or_insert_default().dock = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn outline_panel_section() -> [SettingsPageItem; 11] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Outline Panel")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Outline Panel Button"),
                description: Cow::Borrowed("Show the outline panel button in the status bar."),
                field: Box::new(SettingField {
                    json_path: Some("outline_panel.button"),
                    pick: |settings_content| {
                        settings_content.outline_panel.as_ref()?.button.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .outline_panel
                            .get_or_insert_default()
                            .button = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Outline Panel Dock"),
                description: Cow::Borrowed("Where to dock the outline panel."),
                field: Box::new(SettingField {
                    json_path: Some("outline_panel.dock"),
                    pick: |settings_content| settings_content.outline_panel.as_ref()?.dock.as_ref(),
                    write: |settings_content, value| {
                        settings_content.outline_panel.get_or_insert_default().dock = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Outline Panel Default Width"),
                description: Cow::Borrowed("Default width of the outline panel in pixels."),
                field: Box::new(SettingField {
                    json_path: Some("outline_panel.default_width"),
                    pick: |settings_content| {
                        settings_content
                            .outline_panel
                            .as_ref()?
                            .default_width
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .outline_panel
                            .get_or_insert_default()
                            .default_width = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("File Icons"),
                description: Cow::Borrowed("Show file icons in the outline panel."),
                field: Box::new(SettingField {
                    json_path: Some("outline_panel.file_icons"),
                    pick: |settings_content| {
                        settings_content.outline_panel.as_ref()?.file_icons.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .outline_panel
                            .get_or_insert_default()
                            .file_icons = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Folder Icons"),
                description: Cow::Borrowed("Whether to show folder icons or chevrons for directories in the outline panel."),
                field: Box::new(SettingField {
                    json_path: Some("outline_panel.folder_icons"),
                    pick: |settings_content| {
                        settings_content
                            .outline_panel
                            .as_ref()?
                            .folder_icons
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .outline_panel
                            .get_or_insert_default()
                            .folder_icons = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Git Status"),
                description: Cow::Borrowed("Show the Git status in the outline panel."),
                field: Box::new(SettingField {
                    json_path: Some("outline_panel.git_status"),
                    pick: |settings_content| {
                        settings_content.outline_panel.as_ref()?.git_status.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .outline_panel
                            .get_or_insert_default()
                            .git_status = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Indent Size"),
                description: Cow::Borrowed("Amount of indentation for nested items."),
                field: Box::new(SettingField {
                    json_path: Some("outline_panel.indent_size"),
                    pick: |settings_content| {
                        settings_content
                            .outline_panel
                            .as_ref()?
                            .indent_size
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .outline_panel
                            .get_or_insert_default()
                            .indent_size = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Auto Reveal Entries"),
                description: Cow::Borrowed("Whether to reveal when a corresponding outline entry becomes active."),
                field: Box::new(SettingField {
                    json_path: Some("outline_panel.auto_reveal_entries"),
                    pick: |settings_content| {
                        settings_content
                            .outline_panel
                            .as_ref()?
                            .auto_reveal_entries
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .outline_panel
                            .get_or_insert_default()
                            .auto_reveal_entries = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Auto Fold Directories"),
                description: Cow::Borrowed("Whether to fold directories automatically when a directory contains only one subdirectory."),
                field: Box::new(SettingField {
                    json_path: Some("outline_panel.auto_fold_dirs"),
                    pick: |settings_content| {
                        settings_content
                            .outline_panel
                            .as_ref()?
                            .auto_fold_dirs
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .outline_panel
                            .get_or_insert_default()
                            .auto_fold_dirs = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                files: USER,
                title: Cow::Borrowed("Show Indent Guides"),
                description: Cow::Borrowed("When to show indent guides in the outline panel."),
                field: Box::new(SettingField {
                    json_path: Some("outline_panel.indent_guides.show"),
                    pick: |settings_content| {
                        settings_content
                            .outline_panel
                            .as_ref()?
                            .indent_guides
                            .as_ref()?
                            .show
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .outline_panel
                            .get_or_insert_default()
                            .indent_guides
                            .get_or_insert_default()
                            .show = value;
                    },
                }),
                metadata: None,
            }),
        ]
    }

    fn git_panel_section() -> [SettingsPageItem; 10] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Git Panel")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Git Panel Button"),
                description: Cow::Borrowed("Show the Git panel button in the status bar."),
                field: Box::new(SettingField {
                    json_path: Some("git_panel.button"),
                    pick: |settings_content| settings_content.git_panel.as_ref()?.button.as_ref(),
                    write: |settings_content, value| {
                        settings_content.git_panel.get_or_insert_default().button = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Git Panel Dock"),
                description: Cow::Borrowed("Where to dock the Git panel."),
                field: Box::new(SettingField {
                    json_path: Some("git_panel.dock"),
                    pick: |settings_content| settings_content.git_panel.as_ref()?.dock.as_ref(),
                    write: |settings_content, value| {
                        settings_content.git_panel.get_or_insert_default().dock = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Git Panel Default Width"),
                description: Cow::Borrowed("Default width of the Git panel in pixels."),
                field: Box::new(SettingField {
                    json_path: Some("git_panel.default_width"),
                    pick: |settings_content| {
                        settings_content.git_panel.as_ref()?.default_width.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .git_panel
                            .get_or_insert_default()
                            .default_width = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Git Panel Status Style"),
                description: Cow::Borrowed("How entry statuses are displayed."),
                field: Box::new(SettingField {
                    json_path: Some("git_panel.status_style"),
                    pick: |settings_content| {
                        settings_content.git_panel.as_ref()?.status_style.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .git_panel
                            .get_or_insert_default()
                            .status_style = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Fallback Branch Name"),
                description: Cow::Borrowed("Default branch name will be when init.defaultbranch is not set in Git."),
                field: Box::new(SettingField {
                    json_path: Some("git_panel.fallback_branch_name"),
                    pick: |settings_content| {
                        settings_content
                            .git_panel
                            .as_ref()?
                            .fallback_branch_name
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .git_panel
                            .get_or_insert_default()
                            .fallback_branch_name = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Sort By Path"),
                description: Cow::Borrowed("Enable to sort entries in the panel by path, disable to sort by status."),
                field: Box::new(SettingField {
                    json_path: Some("git_panel.sort_by_path"),
                    pick: |settings_content| {
                        settings_content.git_panel.as_ref()?.sort_by_path.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .git_panel
                            .get_or_insert_default()
                            .sort_by_path = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Collapse Untracked Diff"),
                description: Cow::Borrowed("Whether to collapse untracked files in the diff panel."),
                field: Box::new(SettingField {
                    json_path: Some("git_panel.collapse_untracked_diff"),
                    pick: |settings_content| {
                        settings_content
                            .git_panel
                            .as_ref()?
                            .collapse_untracked_diff
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .git_panel
                            .get_or_insert_default()
                            .collapse_untracked_diff = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Tree View"),
                description: Cow::Borrowed("Enable to show entries in tree view list, disable to show in flat view list."),
                field: Box::new(SettingField {
                    json_path: Some("git_panel.tree_view"),
                    pick: |settings_content| {
                        settings_content.git_panel.as_ref()?.tree_view.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.git_panel.get_or_insert_default().tree_view = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Scroll Bar"),
                description: Cow::Borrowed("How and when the scrollbar should be displayed."),
                field: Box::new(SettingField {
                    json_path: Some("git_panel.scrollbar.show"),
                    pick: |settings_content| {
                        show_scrollbar_or_editor(settings_content, |settings_content| {
                            settings_content
                                .git_panel
                                .as_ref()?
                                .scrollbar
                                .as_ref()?
                                .show
                                .as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        settings_content
                            .git_panel
                            .get_or_insert_default()
                            .scrollbar
                            .get_or_insert_default()
                            .show = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn debugger_panel_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Debugger Panel")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Debugger Panel Dock"),
                description: Cow::Borrowed("The dock position of the debug panel."),
                field: Box::new(SettingField {
                    json_path: Some("debugger.dock"),
                    pick: |settings_content| settings_content.debugger.as_ref()?.dock.as_ref(),
                    write: |settings_content, value| {
                        settings_content.debugger.get_or_insert_default().dock = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn notification_panel_section() -> [SettingsPageItem; 4] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Notification Panel")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Notification Panel Button"),
                description: Cow::Borrowed("Show the notification panel button in the status bar."),
                field: Box::new(SettingField {
                    json_path: Some("notification_panel.button"),
                    pick: |settings_content| {
                        settings_content
                            .notification_panel
                            .as_ref()?
                            .button
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .notification_panel
                            .get_or_insert_default()
                            .button = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Notification Panel Dock"),
                description: Cow::Borrowed("Where to dock the notification panel."),
                field: Box::new(SettingField {
                    json_path: Some("notification_panel.dock"),
                    pick: |settings_content| {
                        settings_content.notification_panel.as_ref()?.dock.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .notification_panel
                            .get_or_insert_default()
                            .dock = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Notification Panel Default Width"),
                description: Cow::Borrowed("Default width of the notification panel in pixels."),
                field: Box::new(SettingField {
                    json_path: Some("notification_panel.default_width"),
                    pick: |settings_content| {
                        settings_content
                            .notification_panel
                            .as_ref()?
                            .default_width
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .notification_panel
                            .get_or_insert_default()
                            .default_width = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn collaboration_panel_section() -> [SettingsPageItem; 4] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Collaboration Panel")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Collaboration Panel Button"),
                description: Cow::Borrowed("Show the collaboration panel button in the status bar."),
                field: Box::new(SettingField {
                    json_path: Some("collaboration_panel.button"),
                    pick: |settings_content| {
                        settings_content
                            .collaboration_panel
                            .as_ref()?
                            .button
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .collaboration_panel
                            .get_or_insert_default()
                            .button = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Collaboration Panel Dock"),
                description: Cow::Borrowed("Where to dock the collaboration panel."),
                field: Box::new(SettingField {
                    json_path: Some("collaboration_panel.dock"),
                    pick: |settings_content| {
                        settings_content.collaboration_panel.as_ref()?.dock.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .collaboration_panel
                            .get_or_insert_default()
                            .dock = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Collaboration Panel Default Width"),
                description: Cow::Borrowed("Default width of the collaboration panel in pixels."),
                field: Box::new(SettingField {
                    json_path: Some("collaboration_panel.dock"),
                    pick: |settings_content| {
                        settings_content
                            .collaboration_panel
                            .as_ref()?
                            .default_width
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .collaboration_panel
                            .get_or_insert_default()
                            .default_width = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn agent_panel_section() -> [SettingsPageItem; 5] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Agent Panel")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Agent Panel Button"),
                description: Cow::Borrowed("Whether to show the agent panel button in the status bar."),
                field: Box::new(SettingField {
                    json_path: Some("agent.button"),
                    pick: |settings_content| settings_content.agent.as_ref()?.button.as_ref(),
                    write: |settings_content, value| {
                        settings_content.agent.get_or_insert_default().button = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Agent Panel Dock"),
                description: Cow::Borrowed("Where to dock the agent panel."),
                field: Box::new(SettingField {
                    json_path: Some("agent.dock"),
                    pick: |settings_content| settings_content.agent.as_ref()?.dock.as_ref(),
                    write: |settings_content, value| {
                        settings_content.agent.get_or_insert_default().dock = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Agent Panel Default Width"),
                description: Cow::Borrowed("Default width when the agent panel is docked to the left or right."),
                field: Box::new(SettingField {
                    json_path: Some("agent.default_width"),
                    pick: |settings_content| {
                        settings_content.agent.as_ref()?.default_width.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.agent.get_or_insert_default().default_width = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Agent Panel Default Height"),
                description: Cow::Borrowed("Default height when the agent panel is docked to the bottom."),
                field: Box::new(SettingField {
                    json_path: Some("agent.default_height"),
                    pick: |settings_content| {
                        settings_content.agent.as_ref()?.default_height.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .agent
                            .get_or_insert_default()
                            .default_height = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    SettingsPage {
        title: Cow::Owned(t("settings-page-panels")),
        items: concat_sections![
            project_panel_section(),
            auto_open_files_section(),
            terminal_panel_section(),
            outline_panel_section(),
            git_panel_section(),
            debugger_panel_section(),
            notification_panel_section(),
            collaboration_panel_section(),
            agent_panel_section(),
        ],
    }
}

fn debugger_page() -> SettingsPage {
    fn general_section() -> [SettingsPageItem; 6] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("General")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Stepping Granularity"),
                description: Cow::Borrowed("Determines the stepping granularity for debug operations."),
                field: Box::new(SettingField {
                    json_path: Some("debugger.stepping_granularity"),
                    pick: |settings_content| {
                        settings_content
                            .debugger
                            .as_ref()?
                            .stepping_granularity
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .debugger
                            .get_or_insert_default()
                            .stepping_granularity = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Save Breakpoints"),
                description: Cow::Borrowed("Whether breakpoints should be reused across Zed sessions."),
                field: Box::new(SettingField {
                    json_path: Some("debugger.save_breakpoints"),
                    pick: |settings_content| {
                        settings_content
                            .debugger
                            .as_ref()?
                            .save_breakpoints
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .debugger
                            .get_or_insert_default()
                            .save_breakpoints = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Timeout"),
                description: Cow::Borrowed("Time in milliseconds until timeout error when connecting to a TCP debug adapter."),
                field: Box::new(SettingField {
                    json_path: Some("debugger.timeout"),
                    pick: |settings_content| settings_content.debugger.as_ref()?.timeout.as_ref(),
                    write: |settings_content, value| {
                        settings_content.debugger.get_or_insert_default().timeout = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Log DAP Communications"),
                description: Cow::Borrowed("Whether to log messages between active debug adapters and Zed."),
                field: Box::new(SettingField {
                    json_path: Some("debugger.log_dap_communications"),
                    pick: |settings_content| {
                        settings_content
                            .debugger
                            .as_ref()?
                            .log_dap_communications
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .debugger
                            .get_or_insert_default()
                            .log_dap_communications = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Format DAP Log Messages"),
                description: Cow::Borrowed("Whether to format DAP messages when adding them to debug adapter logger."),
                field: Box::new(SettingField {
                    json_path: Some("debugger.format_dap_log_messages"),
                    pick: |settings_content| {
                        settings_content
                            .debugger
                            .as_ref()?
                            .format_dap_log_messages
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .debugger
                            .get_or_insert_default()
                            .format_dap_log_messages = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    SettingsPage {
        title: Cow::Owned(t("settings-page-debugger")),
        items: concat_sections![general_section()],
    }
}

fn terminal_page() -> SettingsPage {
    fn environment_section() -> [SettingsPageItem; 5] {
        [
                SettingsPageItem::SectionHeader(Cow::Borrowed("Environment")),
                SettingsPageItem::DynamicItem(DynamicItem {
                    discriminant: SettingItem {
                        files: USER | PROJECT,
                        title: Cow::Borrowed("Shell"),
                        description: Cow::Borrowed("What shell to use when opening a terminal."),
                        field: Box::new(SettingField {
                            json_path: Some("terminal.shell$"),
                            pick: |settings_content| {
                                Some(&dynamic_variants::<settings::Shell>()[
                                    settings_content
                                        .terminal
                                        .as_ref()?
                                        .project
                                        .shell
                                        .as_ref()?
                                        .discriminant() as usize
                                ])
                            },
                            write: |settings_content, value| {
                                let Some(value) = value else {
                                    if let Some(terminal) = settings_content.terminal.as_mut() {
                                        terminal.project.shell = None;
                                    }
                                    return;
                                };
                                let settings_value = settings_content
                                    .terminal
                                    .get_or_insert_default()
                                    .project
                                    .shell
                                    .get_or_insert_with(|| settings::Shell::default());
                                let default_shell = if cfg!(target_os = "windows") {
                                    "powershell.exe"
                                } else {
                                    "sh"
                                };
                                *settings_value = match value {
                                    settings::ShellDiscriminants::System => settings::Shell::System,
                                    settings::ShellDiscriminants::Program => {
                                        let program = match settings_value {
                                            settings::Shell::Program(program) => program.clone(),
                                            settings::Shell::WithArguments { program, .. } => program.clone(),
                                            _ => String::from(default_shell),
                                        };
                                        settings::Shell::Program(program)
                                    }
                                    settings::ShellDiscriminants::WithArguments => {
                                        let (program, args, title_override) = match settings_value {
                                            settings::Shell::Program(program) => (program.clone(), vec![], None),
                                            settings::Shell::WithArguments {
                                                program,
                                                args,
                                                title_override,
                                            } => (program.clone(), args.clone(), title_override.clone()),
                                            _ => (String::from(default_shell), vec![], None),
                                        };
                                        settings::Shell::WithArguments {
                                            program,
                                            args,
                                            title_override,
                                        }
                                    }
                                };
                            },
                        }),
                        metadata: None,
                    },
                    pick_discriminant: |settings_content| {
                        Some(
                            settings_content
                                .terminal
                                .as_ref()?
                                .project
                                .shell
                                .as_ref()?
                                .discriminant() as usize,
                        )
                    },
                    fields: dynamic_variants::<settings::Shell>()
                        .into_iter()
                        .map(|variant| match variant {
                            settings::ShellDiscriminants::System => vec![],
                            settings::ShellDiscriminants::Program => vec![SettingItem {
                                files: USER | PROJECT,
                                title: Cow::Borrowed("Program"),
                                description: Cow::Borrowed("The shell program to use."),
                                field: Box::new(SettingField {
                                    json_path: Some("terminal.shell"),
                                    pick: |settings_content| match settings_content.terminal.as_ref()?.project.shell.as_ref()
                                    {
                                        Some(settings::Shell::Program(program)) => Some(program),
                                        _ => None,
                                    },
                                    write: |settings_content, value| {
                                        let Some(value) = value else {
                                            return;
                                        };
                                        match settings_content
                                            .terminal
                                            .get_or_insert_default()
                                            .project
                                            .shell
                                            .as_mut()
                                        {
                                            Some(settings::Shell::Program(program)) => *program = value,
                                            _ => return,
                                        }
                                    },
                                }),
                                metadata: None,
                            }],
                            settings::ShellDiscriminants::WithArguments => vec![
                                SettingItem {
                                    files: USER | PROJECT,
                                    title: Cow::Borrowed("Program"),
                                    description: Cow::Borrowed("The shell program to run."),
                                    field: Box::new(SettingField {
                                        json_path: Some("terminal.shell.program"),
                                        pick: |settings_content| {
                                            match settings_content.terminal.as_ref()?.project.shell.as_ref() {
                                                Some(settings::Shell::WithArguments { program, .. }) => Some(program),
                                                _ => None,
                                            }
                                        },
                                        write: |settings_content, value| {
                                            let Some(value) = value else {
                                                return;
                                            };
                                            match settings_content
                                                .terminal
                                                .get_or_insert_default()
                                                .project
                                                .shell
                                                .as_mut()
                                            {
                                                Some(settings::Shell::WithArguments { program, .. }) => {
                                                    *program = value
                                                }
                                                _ => return,
                                            }
                                        },
                                    }),
                                    metadata: None,
                                },
                                SettingItem {
                                    files: USER | PROJECT,
                                    title: Cow::Borrowed("Arguments"),
                                    description: Cow::Borrowed("The arguments to pass to the shell program."),
                                    field: Box::new(
                                        SettingField {
                                            json_path: Some("terminal.shell.args"),
                                            pick: |settings_content| {
                                                match settings_content.terminal.as_ref()?.project.shell.as_ref() {
                                                    Some(settings::Shell::WithArguments { args, .. }) => Some(args),
                                                    _ => None,
                                                }
                                            },
                                            write: |settings_content, value| {
                                                let Some(value) = value else {
                                                    return;
                                                };
                                                match settings_content
                                                    .terminal
                                                    .get_or_insert_default()
                                                    .project
                                                    .shell
                                                    .as_mut()
                                                {
                                                    Some(settings::Shell::WithArguments { args, .. }) => *args = value,
                                                    _ => return,
                                                }
                                            },
                                        }
                                        .unimplemented(),
                                    ),
                                    metadata: None,
                                },
                                SettingItem {
                                    files: USER | PROJECT,
                                    title: Cow::Borrowed("Title Override"),
                                    description: Cow::Borrowed("An optional string to override the title of the terminal tab."),
                                    field: Box::new(SettingField {
                                        json_path: Some("terminal.shell.title_override"),
                                        pick: |settings_content| {
                                            match settings_content.terminal.as_ref()?.project.shell.as_ref() {
                                                Some(settings::Shell::WithArguments { title_override, .. }) => {
                                                    title_override.as_ref().or(DEFAULT_EMPTY_STRING)
                                                }
                                                _ => None,
                                            }
                                        },
                                        write: |settings_content, value| {
                                            match settings_content
                                                .terminal
                                                .get_or_insert_default()
                                                .project
                                                .shell
                                                .as_mut()
                                            {
                                                Some(settings::Shell::WithArguments { title_override, .. }) => {
                                                    *title_override = value.filter(|s| !s.is_empty())
                                                }
                                                _ => return,
                                            }
                                        },
                                    }),
                                    metadata: None,
                                },
                            ],
                        })
                        .collect(),
                }),
                SettingsPageItem::DynamicItem(DynamicItem {
                    discriminant: SettingItem {
                        files: USER | PROJECT,
                        title: Cow::Borrowed("Working Directory"),
                        description: Cow::Borrowed("What working directory to use when launching the terminal."),
                        field: Box::new(SettingField {
                            json_path: Some("terminal.working_directory$"),
                            pick: |settings_content| {
                                Some(&dynamic_variants::<settings::WorkingDirectory>()[
                                    settings_content
                                        .terminal
                                        .as_ref()?
                                        .project
                                        .working_directory
                                        .as_ref()?
                                        .discriminant() as usize
                                ])
                            },
                            write: |settings_content, value| {
                                let Some(value) = value else {
                                    if let Some(terminal) = settings_content.terminal.as_mut() {
                                        terminal.project.working_directory = None;
                                    }
                                    return;
                                };
                                let settings_value = settings_content
                                    .terminal
                                    .get_or_insert_default()
                                    .project
                                    .working_directory
                                    .get_or_insert_with(|| settings::WorkingDirectory::CurrentProjectDirectory);
                                *settings_value = match value {
                                    settings::WorkingDirectoryDiscriminants::CurrentProjectDirectory => {
                                        settings::WorkingDirectory::CurrentProjectDirectory
                                    }
                                    settings::WorkingDirectoryDiscriminants::FirstProjectDirectory => {
                                        settings::WorkingDirectory::FirstProjectDirectory
                                    }
                                    settings::WorkingDirectoryDiscriminants::AlwaysHome => {
                                        settings::WorkingDirectory::AlwaysHome
                                    }
                                    settings::WorkingDirectoryDiscriminants::Always => {
                                        let directory = match settings_value {
                                            settings::WorkingDirectory::Always { .. } => return,
                                            _ => String::new(),
                                        };
                                        settings::WorkingDirectory::Always { directory }
                                    }
                                };
                            },
                        }),
                        metadata: None,
                    },
                    pick_discriminant: |settings_content| {
                        Some(
                            settings_content
                                .terminal
                                .as_ref()?
                                .project
                                .working_directory
                                .as_ref()?
                                .discriminant() as usize,
                        )
                    },
                    fields: dynamic_variants::<settings::WorkingDirectory>()
                        .into_iter()
                        .map(|variant| match variant {
                            settings::WorkingDirectoryDiscriminants::CurrentProjectDirectory => vec![],
                            settings::WorkingDirectoryDiscriminants::FirstProjectDirectory => vec![],
                            settings::WorkingDirectoryDiscriminants::AlwaysHome => vec![],
                            settings::WorkingDirectoryDiscriminants::Always => vec![SettingItem {
                                files: USER | PROJECT,
                                title: Cow::Borrowed("Directory"),
                                description: Cow::Borrowed("The directory path to use (will be shell expanded)."),
                                field: Box::new(SettingField {
                                    json_path: Some("terminal.working_directory.always"),
                                    pick: |settings_content| {
                                        match settings_content.terminal.as_ref()?.project.working_directory.as_ref() {
                                            Some(settings::WorkingDirectory::Always { directory }) => Some(directory),
                                            _ => None,
                                        }
                                    },
                                    write: |settings_content, value| {
                                        let value = value.unwrap_or_default();
                                        match settings_content
                                            .terminal
                                            .get_or_insert_default()
                                            .project
                                            .working_directory
                                            .as_mut()
                                        {
                                            Some(settings::WorkingDirectory::Always { directory }) => *directory = value,
                                            _ => return,
                                        }
                                    },
                                }),
                                metadata: None,
                            }],
                        })
                        .collect(),
                }),
                SettingsPageItem::SettingItem(SettingItem {
                    title: Cow::Borrowed("Environment Variables"),
                    description: Cow::Borrowed("Key-value pairs to add to the terminal's environment."),
                    field: Box::new(
                        SettingField {
                            json_path: Some("terminal.env"),
                            pick: |settings_content| settings_content.terminal.as_ref()?.project.env.as_ref(),
                            write: |settings_content, value| {
                                settings_content.terminal.get_or_insert_default().project.env = value;
                            },
                        }
                        .unimplemented(),
                    ),
                    metadata: None,
                    files: USER | PROJECT,
                }),
                SettingsPageItem::SettingItem(SettingItem {
                    title: Cow::Borrowed("Detect Virtual Environment"),
                    description: Cow::Borrowed("Activates the Python virtual environment, if one is found, in the terminal's working directory."),
                    field: Box::new(
                        SettingField {
                            json_path: Some("terminal.detect_venv"),
                            pick: |settings_content| settings_content.terminal.as_ref()?.project.detect_venv.as_ref(),
                            write: |settings_content, value| {
                                settings_content
                                    .terminal
                                    .get_or_insert_default()
                                    .project
                                    .detect_venv = value;
                            },
                        }
                        .unimplemented(),
                    ),
                    metadata: None,
                    files: USER | PROJECT,
                }),
            ]
    }

    fn font_section() -> [SettingsPageItem; 6] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Font")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Font Size"),
                description: Cow::Borrowed("Font size for terminal text. If not set, defaults to buffer font size."),
                field: Box::new(SettingField {
                    json_path: Some("terminal.font_size"),
                    pick: |settings_content| {
                        settings_content
                            .terminal
                            .as_ref()
                            .and_then(|terminal| terminal.font_size.as_ref())
                            .or(settings_content.theme.buffer_font_size.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content.terminal.get_or_insert_default().font_size = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Font Family"),
                description: Cow::Borrowed("Font family for terminal text. If not set, defaults to buffer font family."),
                field: Box::new(SettingField {
                    json_path: Some("terminal.font_family"),
                    pick: |settings_content| {
                        settings_content
                            .terminal
                            .as_ref()
                            .and_then(|terminal| terminal.font_family.as_ref())
                            .or(settings_content.theme.buffer_font_family.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content
                            .terminal
                            .get_or_insert_default()
                            .font_family = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Font Fallbacks"),
                description: Cow::Borrowed("Font fallbacks for terminal text. If not set, defaults to buffer font fallbacks."),
                field: Box::new(
                    SettingField {
                        json_path: Some("terminal.font_fallbacks"),
                        pick: |settings_content| {
                            settings_content
                                .terminal
                                .as_ref()
                                .and_then(|terminal| terminal.font_fallbacks.as_ref())
                                .or(settings_content.theme.buffer_font_fallbacks.as_ref())
                        },
                        write: |settings_content, value| {
                            settings_content
                                .terminal
                                .get_or_insert_default()
                                .font_fallbacks = value;
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Font Weight"),
                description: Cow::Borrowed("Font weight for terminal text in CSS weight units (100-900)."),
                field: Box::new(SettingField {
                    json_path: Some("terminal.font_weight"),
                    pick: |settings_content| {
                        settings_content.terminal.as_ref()?.font_weight.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .terminal
                            .get_or_insert_default()
                            .font_weight = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Font Features"),
                description: Cow::Borrowed("Font features for terminal text."),
                field: Box::new(
                    SettingField {
                        json_path: Some("terminal.font_features"),
                        pick: |settings_content| {
                            settings_content
                                .terminal
                                .as_ref()
                                .and_then(|terminal| terminal.font_features.as_ref())
                                .or(settings_content.theme.buffer_font_features.as_ref())
                        },
                        write: |settings_content, value| {
                            settings_content
                                .terminal
                                .get_or_insert_default()
                                .font_features = value;
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn display_settings_section() -> [SettingsPageItem; 6] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Display Settings")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Line Height"),
                description: Cow::Borrowed("Line height for terminal text."),
                field: Box::new(
                    SettingField {
                        json_path: Some("terminal.line_height"),
                        pick: |settings_content| {
                            settings_content.terminal.as_ref()?.line_height.as_ref()
                        },
                        write: |settings_content, value| {
                            settings_content
                                .terminal
                                .get_or_insert_default()
                                .line_height = value;
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Cursor Shape"),
                description: Cow::Borrowed("Default cursor shape for the terminal (bar, block, underline, or hollow)."),
                field: Box::new(SettingField {
                    json_path: Some("terminal.cursor_shape"),
                    pick: |settings_content| {
                        settings_content.terminal.as_ref()?.cursor_shape.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .terminal
                            .get_or_insert_default()
                            .cursor_shape = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Cursor Blinking"),
                description: Cow::Borrowed("Sets the cursor blinking behavior in the terminal."),
                field: Box::new(SettingField {
                    json_path: Some("terminal.blinking"),
                    pick: |settings_content| settings_content.terminal.as_ref()?.blinking.as_ref(),
                    write: |settings_content, value| {
                        settings_content.terminal.get_or_insert_default().blinking = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Alternate Scroll"),
                description: Cow::Borrowed("Whether alternate scroll mode is active by default (converts mouse scroll to arrow keys in apps like Vim)."),
                field: Box::new(SettingField {
                    json_path: Some("terminal.alternate_scroll"),
                    pick: |settings_content| {
                        settings_content
                            .terminal
                            .as_ref()?
                            .alternate_scroll
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .terminal
                            .get_or_insert_default()
                            .alternate_scroll = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Minimum Contrast"),
                description: Cow::Borrowed("The minimum APCA perceptual contrast between foreground and background colors (0-106)."),
                field: Box::new(SettingField {
                    json_path: Some("terminal.minimum_contrast"),
                    pick: |settings_content| {
                        settings_content
                            .terminal
                            .as_ref()?
                            .minimum_contrast
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .terminal
                            .get_or_insert_default()
                            .minimum_contrast = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn behavior_settings_section() -> [SettingsPageItem; 4] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Behavior Settings")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Option As Meta"),
                description: Cow::Borrowed("Whether the option key behaves as the meta key."),
                field: Box::new(SettingField {
                    json_path: Some("terminal.option_as_meta"),
                    pick: |settings_content| {
                        settings_content.terminal.as_ref()?.option_as_meta.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .terminal
                            .get_or_insert_default()
                            .option_as_meta = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Copy On Select"),
                description: Cow::Borrowed("Whether selecting text in the terminal automatically copies to the system clipboard."),
                field: Box::new(SettingField {
                    json_path: Some("terminal.copy_on_select"),
                    pick: |settings_content| {
                        settings_content.terminal.as_ref()?.copy_on_select.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .terminal
                            .get_or_insert_default()
                            .copy_on_select = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Keep Selection On Copy"),
                description: Cow::Borrowed("Whether to keep the text selection after copying it to the clipboard."),
                field: Box::new(SettingField {
                    json_path: Some("terminal.keep_selection_on_copy"),
                    pick: |settings_content| {
                        settings_content
                            .terminal
                            .as_ref()?
                            .keep_selection_on_copy
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .terminal
                            .get_or_insert_default()
                            .keep_selection_on_copy = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn layout_settings_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Layout Settings")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Default Width"),
                description: Cow::Borrowed("Default width when the terminal is docked to the left or right (in pixels)."),
                field: Box::new(SettingField {
                    json_path: Some("terminal.default_width"),
                    pick: |settings_content| {
                        settings_content.terminal.as_ref()?.default_width.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .terminal
                            .get_or_insert_default()
                            .default_width = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Default Height"),
                description: Cow::Borrowed("Default height when the terminal is docked to the bottom (in pixels)."),
                field: Box::new(SettingField {
                    json_path: Some("terminal.default_height"),
                    pick: |settings_content| {
                        settings_content.terminal.as_ref()?.default_height.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .terminal
                            .get_or_insert_default()
                            .default_height = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn advanced_settings_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Advanced Settings")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Max Scroll History Lines"),
                description: Cow::Borrowed("Maximum number of lines to keep in scrollback history (max: 100,000; 0 disables scrolling)."),
                field: Box::new(SettingField {
                    json_path: Some("terminal.max_scroll_history_lines"),
                    pick: |settings_content| {
                        settings_content
                            .terminal
                            .as_ref()?
                            .max_scroll_history_lines
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .terminal
                            .get_or_insert_default()
                            .max_scroll_history_lines = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Scroll Multiplier"),
                description: Cow::Borrowed("The multiplier for scrolling in the terminal with the mouse wheel"),
                field: Box::new(SettingField {
                    json_path: Some("terminal.scroll_multiplier"),
                    pick: |settings_content| {
                        settings_content
                            .terminal
                            .as_ref()?
                            .scroll_multiplier
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .terminal
                            .get_or_insert_default()
                            .scroll_multiplier = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn toolbar_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Toolbar")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Breadcrumbs"),
                description: Cow::Borrowed("Display the terminal title in breadcrumbs inside the terminal pane."),
                field: Box::new(SettingField {
                    json_path: Some("terminal.toolbar.breadcrumbs"),
                    pick: |settings_content| {
                        settings_content
                            .terminal
                            .as_ref()?
                            .toolbar
                            .as_ref()?
                            .breadcrumbs
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .terminal
                            .get_or_insert_default()
                            .toolbar
                            .get_or_insert_default()
                            .breadcrumbs = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn scrollbar_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Scrollbar")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Show Scrollbar"),
                description: Cow::Borrowed("When to show the scrollbar in the terminal."),
                field: Box::new(SettingField {
                    json_path: Some("terminal.scrollbar.show"),
                    pick: |settings_content| {
                        show_scrollbar_or_editor(settings_content, |settings_content| {
                            settings_content
                                .terminal
                                .as_ref()?
                                .scrollbar
                                .as_ref()?
                                .show
                                .as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        settings_content
                            .terminal
                            .get_or_insert_default()
                            .scrollbar
                            .get_or_insert_default()
                            .show = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    SettingsPage {
        title: Cow::Owned(t("settings-page-terminal")),
        items: concat_sections![
            environment_section(),
            font_section(),
            display_settings_section(),
            behavior_settings_section(),
            layout_settings_section(),
            advanced_settings_section(),
            toolbar_section(),
            scrollbar_section(),
        ],
    }
}

fn version_control_page() -> SettingsPage {
    fn git_integration_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Git Integration")),
            SettingsPageItem::DynamicItem(DynamicItem {
                discriminant: SettingItem {
                    files: USER,
                    title: Cow::Borrowed("Disable Git Integration"),
                    description: Cow::Borrowed("Disable all Git integration features in Zed."),
                    field: Box::new(SettingField::<bool> {
                        json_path: Some("git.disable_git"),
                        pick: |settings_content| {
                            settings_content
                                .git
                                .as_ref()?
                                .enabled
                                .as_ref()?
                                .disable_git
                                .as_ref()
                        },
                        write: |settings_content, value| {
                            settings_content
                                .git
                                .get_or_insert_default()
                                .enabled
                                .get_or_insert_default()
                                .disable_git = value;
                        },
                    }),
                    metadata: None,
                },
                pick_discriminant: |settings_content| {
                    let disabled = settings_content
                        .git
                        .as_ref()?
                        .enabled
                        .as_ref()?
                        .disable_git
                        .unwrap_or(false);
                    Some(if disabled { 0 } else { 1 })
                },
                fields: vec![
                    vec![],
                    vec![
                        SettingItem {
                            files: USER,
                            title: Cow::Borrowed("Enable Git Status"),
                            description: Cow::Borrowed("Show Git status information in the editor."),
                            field: Box::new(SettingField::<bool> {
                                json_path: Some("git.enable_status"),
                                pick: |settings_content| {
                                    settings_content
                                        .git
                                        .as_ref()?
                                        .enabled
                                        .as_ref()?
                                        .enable_status
                                        .as_ref()
                                },
                                write: |settings_content, value| {
                                    settings_content
                                        .git
                                        .get_or_insert_default()
                                        .enabled
                                        .get_or_insert_default()
                                        .enable_status = value;
                                },
                            }),
                            metadata: None,
                        },
                        SettingItem {
                            files: USER,
                            title: Cow::Borrowed("Enable Git Diff"),
                            description: Cow::Borrowed("Show Git diff information in the editor."),
                            field: Box::new(SettingField::<bool> {
                                json_path: Some("git.enable_diff"),
                                pick: |settings_content| {
                                    settings_content
                                        .git
                                        .as_ref()?
                                        .enabled
                                        .as_ref()?
                                        .enable_diff
                                        .as_ref()
                                },
                                write: |settings_content, value| {
                                    settings_content
                                        .git
                                        .get_or_insert_default()
                                        .enabled
                                        .get_or_insert_default()
                                        .enable_diff = value;
                                },
                            }),
                            metadata: None,
                        },
                    ],
                ],
            }),
        ]
    }

    fn git_gutter_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Git Gutter")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Visibility"),
                description: Cow::Borrowed("Control whether Git status is shown in the editor's gutter."),
                field: Box::new(SettingField {
                    json_path: Some("git.git_gutter"),
                    pick: |settings_content| settings_content.git.as_ref()?.git_gutter.as_ref(),
                    write: |settings_content, value| {
                        settings_content.git.get_or_insert_default().git_gutter = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            // todo(settings_ui): Figure out the right default for this value in default.json
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Debounce"),
                description: Cow::Borrowed("Debounce threshold in milliseconds after which changes are reflected in the Git gutter."),
                field: Box::new(SettingField {
                    json_path: Some("git.gutter_debounce"),
                    pick: |settings_content| {
                        settings_content.git.as_ref()?.gutter_debounce.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.git.get_or_insert_default().gutter_debounce = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn inline_git_blame_section() -> [SettingsPageItem; 6] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Inline Git Blame")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Enabled"),
                description: Cow::Borrowed("Whether or not to show Git blame data inline in the currently focused line."),
                field: Box::new(SettingField {
                    json_path: Some("git.inline_blame.enabled"),
                    pick: |settings_content| {
                        settings_content
                            .git
                            .as_ref()?
                            .inline_blame
                            .as_ref()?
                            .enabled
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .git
                            .get_or_insert_default()
                            .inline_blame
                            .get_or_insert_default()
                            .enabled = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Delay"),
                description: Cow::Borrowed("The delay after which the inline blame information is shown."),
                field: Box::new(SettingField {
                    json_path: Some("git.inline_blame.delay_ms"),
                    pick: |settings_content| {
                        settings_content
                            .git
                            .as_ref()?
                            .inline_blame
                            .as_ref()?
                            .delay_ms
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .git
                            .get_or_insert_default()
                            .inline_blame
                            .get_or_insert_default()
                            .delay_ms = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Padding"),
                description: Cow::Borrowed("Padding between the end of the source line and the start of the inline blame in columns."),
                field: Box::new(SettingField {
                    json_path: Some("git.inline_blame.padding"),
                    pick: |settings_content| {
                        settings_content
                            .git
                            .as_ref()?
                            .inline_blame
                            .as_ref()?
                            .padding
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .git
                            .get_or_insert_default()
                            .inline_blame
                            .get_or_insert_default()
                            .padding = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Minimum Column"),
                description: Cow::Borrowed("The minimum column number at which to show the inline blame information."),
                field: Box::new(SettingField {
                    json_path: Some("git.inline_blame.min_column"),
                    pick: |settings_content| {
                        settings_content
                            .git
                            .as_ref()?
                            .inline_blame
                            .as_ref()?
                            .min_column
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .git
                            .get_or_insert_default()
                            .inline_blame
                            .get_or_insert_default()
                            .min_column = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Show Commit Summary"),
                description: Cow::Borrowed("Show commit summary as part of the inline blame."),
                field: Box::new(SettingField {
                    json_path: Some("git.inline_blame.show_commit_summary"),
                    pick: |settings_content| {
                        settings_content
                            .git
                            .as_ref()?
                            .inline_blame
                            .as_ref()?
                            .show_commit_summary
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .git
                            .get_or_insert_default()
                            .inline_blame
                            .get_or_insert_default()
                            .show_commit_summary = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn git_blame_view_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Git Blame View")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Show Avatar"),
                description: Cow::Borrowed("Show the avatar of the author of the commit."),
                field: Box::new(SettingField {
                    json_path: Some("git.blame.show_avatar"),
                    pick: |settings_content| {
                        settings_content
                            .git
                            .as_ref()?
                            .blame
                            .as_ref()?
                            .show_avatar
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .git
                            .get_or_insert_default()
                            .blame
                            .get_or_insert_default()
                            .show_avatar = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn branch_picker_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Branch Picker")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Show Author Name"),
                description: Cow::Borrowed("Show author name as part of the commit information in branch picker."),
                field: Box::new(SettingField {
                    json_path: Some("git.branch_picker.show_author_name"),
                    pick: |settings_content| {
                        settings_content
                            .git
                            .as_ref()?
                            .branch_picker
                            .as_ref()?
                            .show_author_name
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .git
                            .get_or_insert_default()
                            .branch_picker
                            .get_or_insert_default()
                            .show_author_name = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn git_hunks_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Git Hunks")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Hunk Style"),
                description: Cow::Borrowed("How Git hunks are displayed visually in the editor."),
                field: Box::new(SettingField {
                    json_path: Some("git.hunk_style"),
                    pick: |settings_content| settings_content.git.as_ref()?.hunk_style.as_ref(),
                    write: |settings_content, value| {
                        settings_content.git.get_or_insert_default().hunk_style = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Path Style"),
                description: Cow::Borrowed("Should the name or path be displayed first in the git view."),
                field: Box::new(SettingField {
                    json_path: Some("git.path_style"),
                    pick: |settings_content| settings_content.git.as_ref()?.path_style.as_ref(),
                    write: |settings_content, value| {
                        settings_content.git.get_or_insert_default().path_style = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    SettingsPage {
        title: Cow::Owned(t("settings-page-version-control")),
        items: concat_sections![
            git_integration_section(),
            git_gutter_section(),
            inline_git_blame_section(),
            git_blame_view_section(),
            branch_picker_section(),
            git_hunks_section(),
        ],
    }
}

fn collaboration_page() -> SettingsPage {
    fn calls_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Calls")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Mute On Join"),
                description: Cow::Borrowed("Whether the microphone should be muted when joining a channel or a call."),
                field: Box::new(SettingField {
                    json_path: Some("calls.mute_on_join"),
                    pick: |settings_content| settings_content.calls.as_ref()?.mute_on_join.as_ref(),
                    write: |settings_content, value| {
                        settings_content.calls.get_or_insert_default().mute_on_join = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Share On Join"),
                description: Cow::Borrowed("Whether your current project should be shared when joining an empty channel."),
                field: Box::new(SettingField {
                    json_path: Some("calls.share_on_join"),
                    pick: |settings_content| {
                        settings_content.calls.as_ref()?.share_on_join.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.calls.get_or_insert_default().share_on_join = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn experimental_section() -> [SettingsPageItem; 6] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Experimental")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Rodio Audio"),
                description: Cow::Borrowed("Opt into the new audio system."),
                field: Box::new(SettingField {
                    json_path: Some("audio.experimental.rodio_audio"),
                    pick: |settings_content| settings_content.audio.as_ref()?.rodio_audio.as_ref(),
                    write: |settings_content, value| {
                        settings_content.audio.get_or_insert_default().rodio_audio = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Auto Microphone Volume"),
                description: Cow::Borrowed("Automatically adjust microphone volume (requires rodio audio)."),
                field: Box::new(SettingField {
                    json_path: Some("audio.experimental.auto_microphone_volume"),
                    pick: |settings_content| {
                        settings_content
                            .audio
                            .as_ref()?
                            .auto_microphone_volume
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .audio
                            .get_or_insert_default()
                            .auto_microphone_volume = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Auto Speaker Volume"),
                description: Cow::Borrowed("Automatically adjust volume of other call members (requires rodio audio)."),
                field: Box::new(SettingField {
                    json_path: Some("audio.experimental.auto_speaker_volume"),
                    pick: |settings_content| {
                        settings_content
                            .audio
                            .as_ref()?
                            .auto_speaker_volume
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .audio
                            .get_or_insert_default()
                            .auto_speaker_volume = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Denoise"),
                description: Cow::Borrowed("Remove background noises (requires rodio audio)."),
                field: Box::new(SettingField {
                    json_path: Some("audio.experimental.denoise"),
                    pick: |settings_content| settings_content.audio.as_ref()?.denoise.as_ref(),
                    write: |settings_content, value| {
                        settings_content.audio.get_or_insert_default().denoise = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Legacy Audio Compatible"),
                description: Cow::Borrowed("Use audio parameters compatible with previous versions (requires rodio audio)."),
                field: Box::new(SettingField {
                    json_path: Some("audio.experimental.legacy_audio_compatible"),
                    pick: |settings_content| {
                        settings_content
                            .audio
                            .as_ref()?
                            .legacy_audio_compatible
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .audio
                            .get_or_insert_default()
                            .legacy_audio_compatible = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    SettingsPage {
        title: Cow::Owned(t("settings-page-collaboration")),
        items: concat_sections![calls_section(), experimental_section()],
    }
}

fn ai_page() -> SettingsPage {
    fn general_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("General")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Disable AI"),
                description: Cow::Borrowed("Whether to disable all AI features in Zed."),
                field: Box::new(SettingField {
                    json_path: Some("disable_ai"),
                    pick: |settings_content| settings_content.disable_ai.as_ref(),
                    write: |settings_content, value| {
                        settings_content.disable_ai = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn agent_configuration_section() -> [SettingsPageItem; 12] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Agent Configuration")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Always Allow Tool Actions"),
                description: Cow::Borrowed("When enabled, the agent can run potentially destructive actions without asking for your confirmation. This setting has no effect on external agents."),
                field: Box::new(SettingField {
                    json_path: Some("agent.always_allow_tool_actions"),
                    pick: |settings_content| {
                        settings_content
                            .agent
                            .as_ref()?
                            .always_allow_tool_actions
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .agent
                            .get_or_insert_default()
                            .always_allow_tool_actions = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Single File Review"),
                description: Cow::Borrowed("When enabled, agent edits will also be displayed in single-file buffers for review."),
                field: Box::new(SettingField {
                    json_path: Some("agent.single_file_review"),
                    pick: |settings_content| {
                        settings_content.agent.as_ref()?.single_file_review.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .agent
                            .get_or_insert_default()
                            .single_file_review = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Enable Feedback"),
                description: Cow::Borrowed("Show voting thumbs up/down icon buttons for feedback on agent edits."),
                field: Box::new(SettingField {
                    json_path: Some("agent.enable_feedback"),
                    pick: |settings_content| {
                        settings_content.agent.as_ref()?.enable_feedback.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .agent
                            .get_or_insert_default()
                            .enable_feedback = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Notify When Agent Waiting"),
                description: Cow::Borrowed("Where to show notifications when the agent has completed its response or needs confirmation before running a tool action."),
                field: Box::new(SettingField {
                    json_path: Some("agent.notify_when_agent_waiting"),
                    pick: |settings_content| {
                        settings_content
                            .agent
                            .as_ref()?
                            .notify_when_agent_waiting
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .agent
                            .get_or_insert_default()
                            .notify_when_agent_waiting = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Play Sound When Agent Done"),
                description: Cow::Borrowed("Whether to play a sound when the agent has either completed its response, or needs user input."),
                field: Box::new(SettingField {
                    json_path: Some("agent.play_sound_when_agent_done"),
                    pick: |settings_content| {
                        settings_content
                            .agent
                            .as_ref()?
                            .play_sound_when_agent_done
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .agent
                            .get_or_insert_default()
                            .play_sound_when_agent_done = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Expand Edit Card"),
                description: Cow::Borrowed("Whether to have edit cards in the agent panel expanded, showing a Preview of the diff."),
                field: Box::new(SettingField {
                    json_path: Some("agent.expand_edit_card"),
                    pick: |settings_content| {
                        settings_content.agent.as_ref()?.expand_edit_card.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .agent
                            .get_or_insert_default()
                            .expand_edit_card = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Expand Terminal Card"),
                description: Cow::Borrowed("Whether to have terminal cards in the agent panel expanded, showing the whole command output."),
                field: Box::new(SettingField {
                    json_path: Some("agent.expand_terminal_card"),
                    pick: |settings_content| {
                        settings_content
                            .agent
                            .as_ref()?
                            .expand_terminal_card
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .agent
                            .get_or_insert_default()
                            .expand_terminal_card = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Cancel Generation On Terminal Stop"),
                description: Cow::Borrowed("Whether clicking the stop button on a running terminal tool should also cancel the agent's generation. Note that this only applies to the stop button, not to ctrl+c inside the terminal."),
                field: Box::new(SettingField {
                    json_path: Some("agent.cancel_generation_on_terminal_stop"),
                    pick: |settings_content| {
                        settings_content
                            .agent
                            .as_ref()?
                            .cancel_generation_on_terminal_stop
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .agent
                            .get_or_insert_default()
                            .cancel_generation_on_terminal_stop = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Use Modifier To Send"),
                description: Cow::Borrowed("Whether to always use cmd-enter (or ctrl-enter on Linux or Windows) to send messages."),
                field: Box::new(SettingField {
                    json_path: Some("agent.use_modifier_to_send"),
                    pick: |settings_content| {
                        settings_content
                            .agent
                            .as_ref()?
                            .use_modifier_to_send
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .agent
                            .get_or_insert_default()
                            .use_modifier_to_send = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Message Editor Min Lines"),
                description: Cow::Borrowed("Minimum number of lines to display in the agent message editor."),
                field: Box::new(SettingField {
                    json_path: Some("agent.message_editor_min_lines"),
                    pick: |settings_content| {
                        settings_content
                            .agent
                            .as_ref()?
                            .message_editor_min_lines
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .agent
                            .get_or_insert_default()
                            .message_editor_min_lines = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Show Turn Stats"),
                description: Cow::Borrowed("Whether to show turn statistics like elapsed time during generation and final turn duration."),
                field: Box::new(SettingField {
                    json_path: Some("agent.show_turn_stats"),
                    pick: |settings_content| {
                        settings_content.agent.as_ref()?.show_turn_stats.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .agent
                            .get_or_insert_default()
                            .show_turn_stats = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn context_servers_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Context Servers")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Context Server Timeout"),
                description: Cow::Borrowed("Default timeout in seconds for context server tool calls. Can be overridden per-server in context_servers configuration."),
                field: Box::new(SettingField {
                    json_path: Some("context_server_timeout"),
                    pick: |settings_content| {
                        settings_content.project.context_server_timeout.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.project.context_server_timeout = value;
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
        ]
    }

    fn edit_prediction_display_sub_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Display Mode"),
                description: Cow::Borrowed("When to show edit predictions previews in buffer. The eager mode displays them inline, while the subtle mode displays them only when holding a modifier key."),
                field: Box::new(SettingField {
                    json_path: Some("edit_prediction.display_mode"),
                    pick: |settings_content| {
                        settings_content
                            .project
                            .all_languages
                            .edit_predictions
                            .as_ref()?
                            .mode
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project
                            .all_languages
                            .edit_predictions
                            .get_or_insert_default()
                            .mode = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Display In Text Threads"),
                description: Cow::Borrowed("Whether edit predictions are enabled when editing text threads in the agent panel."),
                field: Box::new(SettingField {
                    json_path: Some("edit_prediction.in_text_threads"),
                    pick: |settings_content| {
                        settings_content
                            .project
                            .all_languages
                            .edit_predictions
                            .as_ref()?
                            .enabled_in_text_threads
                            .as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content
                            .project
                            .all_languages
                            .edit_predictions
                            .get_or_insert_default()
                            .enabled_in_text_threads = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    SettingsPage {
        title: Cow::Owned(t("settings-page-ai")),
        items: concat_sections![
            general_section(),
            agent_configuration_section(),
            context_servers_section(),
            edit_prediction_language_settings_section(),
            edit_prediction_display_sub_section()
        ],
    }
}

fn network_page() -> SettingsPage {
    fn network_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Network")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Proxy"),
                description: Cow::Borrowed("The proxy to use for network requests."),
                field: Box::new(SettingField {
                    json_path: Some("proxy"),
                    pick: |settings_content| settings_content.proxy.as_ref(),
                    write: |settings_content, value| {
                        settings_content.proxy = value;
                    },
                }),
                metadata: Some(Box::new(SettingsFieldMetadata {
                    placeholder: Some("socks5h://localhost:10808"),
                    ..Default::default()
                })),
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Server URL"),
                description: Cow::Borrowed("The URL of the Zed server to connect to."),
                field: Box::new(SettingField {
                    json_path: Some("server_url"),
                    pick: |settings_content| settings_content.server_url.as_ref(),
                    write: |settings_content, value| {
                        settings_content.server_url = value;
                    },
                }),
                metadata: Some(Box::new(SettingsFieldMetadata {
                    placeholder: Some("https://zed.dev"),
                    ..Default::default()
                })),
                files: USER,
            }),
        ]
    }

    SettingsPage {
        title: Cow::Owned(t("settings-page-network")),
        items: concat_sections![network_section()],
    }
}

fn language_settings_field<T>(
    settings_content: &SettingsContent,
    get_language_setting_field: fn(&LanguageSettingsContent) -> Option<&T>,
) -> Option<&T> {
    let all_languages = &settings_content.project.all_languages;

    active_language()
        .and_then(|current_language_name| {
            all_languages
                .languages
                .0
                .get(current_language_name.as_ref())
        })
        .and_then(get_language_setting_field)
        .or_else(|| get_language_setting_field(&all_languages.defaults))
}

fn language_settings_field_mut<T>(
    settings_content: &mut SettingsContent,
    value: Option<T>,
    write: fn(&mut LanguageSettingsContent, Option<T>),
) {
    let all_languages = &mut settings_content.project.all_languages;
    let language_content = if let Some(current_language) = active_language() {
        all_languages
            .languages
            .0
            .entry(current_language.to_string())
            .or_default()
    } else {
        &mut all_languages.defaults
    };
    write(language_content, value);
}

fn language_settings_data() -> Box<[SettingsPageItem]> {
    fn indentation_section() -> [SettingsPageItem; 5] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Indentation")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Tab Size"),
                description: Cow::Borrowed("How many columns a tab should occupy."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).tab_size"), // TODO(cameron): not JQ syntax because not URL-safe
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.tab_size.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.tab_size = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Hard Tabs"),
                description: Cow::Borrowed("Whether to indent lines using tab characters, as opposed to multiple spaces."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).hard_tabs"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.hard_tabs.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.hard_tabs = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Auto Indent"),
                description: Cow::Borrowed("Whether indentation should be adjusted based on the context whilst typing."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).auto_indent"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.auto_indent.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.auto_indent = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Auto Indent On Paste"),
                description: Cow::Borrowed("Whether indentation of pasted content should be adjusted based on the context."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).auto_indent_on_paste"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.auto_indent_on_paste.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.auto_indent_on_paste = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
        ]
    }

    fn wrapping_section() -> [SettingsPageItem; 6] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Wrapping")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Soft Wrap"),
                description: Cow::Borrowed("How to soft-wrap long lines of text."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).soft_wrap"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.soft_wrap.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.soft_wrap = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Show Wrap Guides"),
                description: Cow::Borrowed("Show wrap guides in the editor."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).show_wrap_guides"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.show_wrap_guides.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.show_wrap_guides = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Preferred Line Length"),
                description: Cow::Borrowed("The column at which to soft-wrap lines, for buffers where soft-wrap is enabled."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).preferred_line_length"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.preferred_line_length.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.preferred_line_length = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Wrap Guides"),
                description: Cow::Borrowed("Character counts at which to show wrap guides in the editor."),
                field: Box::new(
                    SettingField {
                        json_path: Some("languages.$(language).wrap_guides"),
                        pick: |settings_content| {
                            language_settings_field(settings_content, |language| {
                                language.wrap_guides.as_ref()
                            })
                        },
                        write: |settings_content, value| {
                            language_settings_field_mut(
                                settings_content,
                                value,
                                |language, value| {
                                    language.wrap_guides = value;
                                },
                            )
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Allow Rewrap"),
                description: Cow::Borrowed("Controls where the `editor::rewrap` action is allowed for this language."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).allow_rewrap"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.allow_rewrap.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.allow_rewrap = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
        ]
    }

    fn indent_guides_section() -> [SettingsPageItem; 6] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Indent Guides")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Enabled"),
                description: Cow::Borrowed("Display indent guides in the editor."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).indent_guides.enabled"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language
                                .indent_guides
                                .as_ref()
                                .and_then(|indent_guides| indent_guides.enabled.as_ref())
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.indent_guides.get_or_insert_default().enabled = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Line Width"),
                description: Cow::Borrowed("The width of the indent guides in pixels, between 1 and 10."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).indent_guides.line_width"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language
                                .indent_guides
                                .as_ref()
                                .and_then(|indent_guides| indent_guides.line_width.as_ref())
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.indent_guides.get_or_insert_default().line_width = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Active Line Width"),
                description: Cow::Borrowed("The width of the active indent guide in pixels, between 1 and 10."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).indent_guides.active_line_width"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language
                                .indent_guides
                                .as_ref()
                                .and_then(|indent_guides| indent_guides.active_line_width.as_ref())
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language
                                .indent_guides
                                .get_or_insert_default()
                                .active_line_width = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Coloring"),
                description: Cow::Borrowed("Determines how indent guides are colored."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).indent_guides.coloring"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language
                                .indent_guides
                                .as_ref()
                                .and_then(|indent_guides| indent_guides.coloring.as_ref())
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.indent_guides.get_or_insert_default().coloring = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Background Coloring"),
                description: Cow::Borrowed("Determines how indent guide backgrounds are colored."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).indent_guides.background_coloring"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.indent_guides.as_ref().and_then(|indent_guides| {
                                indent_guides.background_coloring.as_ref()
                            })
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language
                                .indent_guides
                                .get_or_insert_default()
                                .background_coloring = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
        ]
    }

    fn formatting_section() -> [SettingsPageItem; 7] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Formatting")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Format On Save"),
                description: Cow::Borrowed("Whether or not to perform a buffer format before saving."),
                field: Box::new(
                    // TODO(settings_ui): this setting should just be a bool
                    SettingField {
                        json_path: Some("languages.$(language).format_on_save"),
                        pick: |settings_content| {
                            language_settings_field(settings_content, |language| {
                                language.format_on_save.as_ref()
                            })
                        },
                        write: |settings_content, value| {
                            language_settings_field_mut(
                                settings_content,
                                value,
                                |language, value| {
                                    language.format_on_save = value;
                                },
                            )
                        },
                    },
                ),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Remove Trailing Whitespace On Save"),
                description: Cow::Borrowed("Whether or not to remove any trailing whitespace from lines of a buffer before saving it."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).remove_trailing_whitespace_on_save"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.remove_trailing_whitespace_on_save.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.remove_trailing_whitespace_on_save = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Ensure Final Newline On Save"),
                description: Cow::Borrowed("Whether or not to ensure there's a single newline at the end of a buffer when saving it."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).ensure_final_newline_on_save"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.ensure_final_newline_on_save.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.ensure_final_newline_on_save = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Formatter"),
                description: Cow::Borrowed("How to perform a buffer format."),
                field: Box::new(
                    SettingField {
                        json_path: Some("languages.$(language).formatter"),
                        pick: |settings_content| {
                            language_settings_field(settings_content, |language| {
                                language.formatter.as_ref()
                            })
                        },
                        write: |settings_content, value| {
                            language_settings_field_mut(
                                settings_content,
                                value,
                                |language, value| {
                                    language.formatter = value;
                                },
                            )
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Use On Type Format"),
                description: Cow::Borrowed("Whether to use additional LSP queries to format (and amend) the code after every \"trigger\" symbol input, defined by LSP server capabilities"),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).use_on_type_format"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.use_on_type_format.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.use_on_type_format = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Code Actions On Format"),
                description: Cow::Borrowed("Additional code actions to run when formatting."),
                field: Box::new(
                    SettingField {
                        json_path: Some("languages.$(language).code_actions_on_format"),
                        pick: |settings_content| {
                            language_settings_field(settings_content, |language| {
                                language.code_actions_on_format.as_ref()
                            })
                        },
                        write: |settings_content, value| {
                            language_settings_field_mut(
                                settings_content,
                                value,
                                |language, value| {
                                    language.code_actions_on_format = value;
                                },
                            )
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER | PROJECT,
            }),
        ]
    }

    fn autoclose_section() -> [SettingsPageItem; 5] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Autoclose")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Use Autoclose"),
                description: Cow::Borrowed("Whether to automatically type closing characters for you. For example, when you type '(', Zed will automatically add a closing ')' at the correct position."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).use_autoclose"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.use_autoclose.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.use_autoclose = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Use Auto Surround"),
                description: Cow::Borrowed("Whether to automatically surround text with characters for you. For example, when you select text and type '(', Zed will automatically surround text with ()."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).use_auto_surround"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.use_auto_surround.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.use_auto_surround = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Always Treat Brackets As Autoclosed"),
                description: Cow::Borrowed("Controls whether the closing characters are always skipped over and auto-removed no matter how they were inserted."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).always_treat_brackets_as_autoclosed"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.always_treat_brackets_as_autoclosed.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.always_treat_brackets_as_autoclosed = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("JSX Tag Auto Close"),
                description: Cow::Borrowed("Whether to automatically close JSX tags."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).jsx_tag_auto_close"),
                    // TODO(settings_ui): this setting should just be a bool
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.jsx_tag_auto_close.as_ref()?.enabled.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.jsx_tag_auto_close.get_or_insert_default().enabled = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
        ]
    }

    fn whitespace_section() -> [SettingsPageItem; 4] {
        [
            SettingsPageItem::SectionHeader(Cow::Owned(t("settings-section-whitespace"))),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Show Whitespaces"),
                description: Cow::Borrowed("Whether to show tabs and spaces in the editor."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).show_whitespaces"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.show_whitespaces.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.show_whitespaces = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Space Whitespace Indicator"),
                description: Cow::Borrowed("Visible character used to render space characters when show_whitespaces is enabled (default: \"•\")"),
                field: Box::new(
                    SettingField {
                        json_path: Some("languages.$(language).whitespace_map.space"),
                        pick: |settings_content| {
                            language_settings_field(settings_content, |language| {
                                language.whitespace_map.as_ref()?.space.as_ref()
                            })
                        },
                        write: |settings_content, value| {
                            language_settings_field_mut(
                                settings_content,
                                value,
                                |language, value| {
                                    language.whitespace_map.get_or_insert_default().space = value;
                                },
                            )
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Tab Whitespace Indicator"),
                description: Cow::Borrowed("Visible character used to render tab characters when show_whitespaces is enabled (default: \"→\")"),
                field: Box::new(
                    SettingField {
                        json_path: Some("languages.$(language).whitespace_map.tab"),
                        pick: |settings_content| {
                            language_settings_field(settings_content, |language| {
                                language.whitespace_map.as_ref()?.tab.as_ref()
                            })
                        },
                        write: |settings_content, value| {
                            language_settings_field_mut(
                                settings_content,
                                value,
                                |language, value| {
                                    language.whitespace_map.get_or_insert_default().tab = value;
                                },
                            )
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER | PROJECT,
            }),
        ]
    }

    fn completions_section() -> [SettingsPageItem; 7] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Completions")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Show Completions On Input"),
                description: Cow::Borrowed("Whether to pop the completions menu while typing in an editor without explicitly requesting it."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).show_completions_on_input"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.show_completions_on_input.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.show_completions_on_input = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Show Completion Documentation"),
                description: Cow::Borrowed("Whether to display inline and alongside documentation for items in the completions menu."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).show_completion_documentation"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.show_completion_documentation.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.show_completion_documentation = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Words"),
                description: Cow::Borrowed("Controls how words are completed."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).completions.words"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.completions.as_ref()?.words.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.completions.get_or_insert_default().words = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Words Min Length"),
                description: Cow::Borrowed("How many characters has to be in the completions query to automatically show the words-based completions."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).completions.words_min_length"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.completions.as_ref()?.words_min_length.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language
                                .completions
                                .get_or_insert_default()
                                .words_min_length = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Completion Menu Scrollbar"),
                description: Cow::Borrowed("When to show the scrollbar in the completion menu."),
                field: Box::new(SettingField {
                    json_path: Some("editor.completion_menu_scrollbar"),
                    pick: |settings_content| {
                        settings_content.editor.completion_menu_scrollbar.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.editor.completion_menu_scrollbar = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Completion Detail Alignment"),
                description: Cow::Borrowed("Whether to align detail text in code completions context menus left or right."),
                field: Box::new(SettingField {
                    json_path: Some("editor.completion_detail_alignment"),
                    pick: |settings_content| {
                        settings_content.editor.completion_detail_alignment.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.editor.completion_detail_alignment = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn inlay_hints_section() -> [SettingsPageItem; 10] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Inlay Hints")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Enabled"),
                description: Cow::Borrowed("Global switch to toggle hints on and off."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).inlay_hints.enabled"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.inlay_hints.as_ref()?.enabled.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.inlay_hints.get_or_insert_default().enabled = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Show Value Hints"),
                description: Cow::Borrowed("Global switch to toggle inline values on and off when debugging."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).inlay_hints.show_value_hints"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.inlay_hints.as_ref()?.show_value_hints.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language
                                .inlay_hints
                                .get_or_insert_default()
                                .show_value_hints = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Show Type Hints"),
                description: Cow::Borrowed("Whether type hints should be shown."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).inlay_hints.show_type_hints"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.inlay_hints.as_ref()?.show_type_hints.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.inlay_hints.get_or_insert_default().show_type_hints = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Show Parameter Hints"),
                description: Cow::Borrowed("Whether parameter hints should be shown."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).inlay_hints.show_parameter_hints"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.inlay_hints.as_ref()?.show_parameter_hints.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language
                                .inlay_hints
                                .get_or_insert_default()
                                .show_parameter_hints = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Show Other Hints"),
                description: Cow::Borrowed("Whether other hints should be shown."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).inlay_hints.show_other_hints"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.inlay_hints.as_ref()?.show_other_hints.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language
                                .inlay_hints
                                .get_or_insert_default()
                                .show_other_hints = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Show Background"),
                description: Cow::Borrowed("Show a background for inlay hints."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).inlay_hints.show_background"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.inlay_hints.as_ref()?.show_background.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.inlay_hints.get_or_insert_default().show_background = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Edit Debounce Ms"),
                description: Cow::Borrowed("Whether or not to debounce inlay hints updates after buffer edits (set to 0 to disable debouncing)."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).inlay_hints.edit_debounce_ms"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.inlay_hints.as_ref()?.edit_debounce_ms.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language
                                .inlay_hints
                                .get_or_insert_default()
                                .edit_debounce_ms = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Scroll Debounce Ms"),
                description: Cow::Borrowed("Whether or not to debounce inlay hints updates after buffer scrolls (set to 0 to disable debouncing)."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).inlay_hints.scroll_debounce_ms"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.inlay_hints.as_ref()?.scroll_debounce_ms.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language
                                .inlay_hints
                                .get_or_insert_default()
                                .scroll_debounce_ms = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Toggle On Modifiers Press"),
                description: Cow::Borrowed("Toggles inlay hints (hides or shows) when the user presses the modifiers specified."),
                field: Box::new(
                    SettingField {
                        json_path: Some(
                            "languages.$(language).inlay_hints.toggle_on_modifiers_press",
                        ),
                        pick: |settings_content| {
                            language_settings_field(settings_content, |language| {
                                language
                                    .inlay_hints
                                    .as_ref()?
                                    .toggle_on_modifiers_press
                                    .as_ref()
                            })
                        },
                        write: |settings_content, value| {
                            language_settings_field_mut(
                                settings_content,
                                value,
                                |language, value| {
                                    language
                                        .inlay_hints
                                        .get_or_insert_default()
                                        .toggle_on_modifiers_press = value;
                                },
                            )
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER | PROJECT,
            }),
        ]
    }

    fn tasks_section() -> [SettingsPageItem; 4] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Tasks")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Enabled"),
                description: Cow::Borrowed("Whether tasks are enabled for this language."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).tasks.enabled"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.tasks.as_ref()?.enabled.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.tasks.get_or_insert_default().enabled = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Variables"),
                description: Cow::Borrowed("Extra task variables to set for a particular language."),
                field: Box::new(
                    SettingField {
                        json_path: Some("languages.$(language).tasks.variables"),
                        pick: |settings_content| {
                            language_settings_field(settings_content, |language| {
                                language.tasks.as_ref()?.variables.as_ref()
                            })
                        },
                        write: |settings_content, value| {
                            language_settings_field_mut(
                                settings_content,
                                value,
                                |language, value| {
                                    language.tasks.get_or_insert_default().variables = value;
                                },
                            )
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Prefer LSP"),
                description: Cow::Borrowed("Use LSP tasks over Zed language extension tasks."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).tasks.prefer_lsp"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.tasks.as_ref()?.prefer_lsp.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.tasks.get_or_insert_default().prefer_lsp = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
        ]
    }

    fn miscellaneous_section() -> [SettingsPageItem; 6] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Miscellaneous")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Word Diff Enabled"),
                description: Cow::Borrowed("Whether to enable word diff highlighting in the editor. When enabled, changed words within modified lines are highlighted to show exactly what changed."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).word_diff_enabled"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.word_diff_enabled.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.word_diff_enabled = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Debuggers"),
                description: Cow::Borrowed("Preferred debuggers for this language."),
                field: Box::new(
                    SettingField {
                        json_path: Some("languages.$(language).debuggers"),
                        pick: |settings_content| {
                            language_settings_field(settings_content, |language| {
                                language.debuggers.as_ref()
                            })
                        },
                        write: |settings_content, value| {
                            language_settings_field_mut(
                                settings_content,
                                value,
                                |language, value| {
                                    language.debuggers = value;
                                },
                            )
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Middle Click Paste"),
                description: Cow::Borrowed("Enable middle-click paste on Linux."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).editor.middle_click_paste"),
                    pick: |settings_content| settings_content.editor.middle_click_paste.as_ref(),
                    write: |settings_content, value| {
                        settings_content.editor.middle_click_paste = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Extend Comment On Newline"),
                description: Cow::Borrowed("Whether to start a new line with a comment when a previous line is a comment as well."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).extend_comment_on_newline"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.extend_comment_on_newline.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.extend_comment_on_newline = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Colorize Brackets"),
                description: Cow::Borrowed("Whether to colorize brackets in the editor."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).colorize_brackets"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.colorize_brackets.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.colorize_brackets = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
        ]
    }

    fn global_only_miscellaneous_sub_section() -> [SettingsPageItem; 3] {
        [
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Image Viewer"),
                description: Cow::Borrowed("The unit for image file sizes."),
                field: Box::new(SettingField {
                    json_path: Some("image_viewer.unit"),
                    pick: |settings_content| {
                        settings_content
                            .image_viewer
                            .as_ref()
                            .and_then(|image_viewer| image_viewer.unit.as_ref())
                    },
                    write: |settings_content, value| {
                        settings_content.image_viewer.get_or_insert_default().unit = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Auto Replace Emoji Shortcode"),
                description: Cow::Borrowed("Whether to automatically replace emoji shortcodes with emoji characters."),
                field: Box::new(SettingField {
                    json_path: Some("message_editor.auto_replace_emoji_shortcode"),
                    pick: |settings_content| {
                        settings_content
                            .message_editor
                            .as_ref()
                            .and_then(|message_editor| {
                                message_editor.auto_replace_emoji_shortcode.as_ref()
                            })
                    },
                    write: |settings_content, value| {
                        settings_content
                            .message_editor
                            .get_or_insert_default()
                            .auto_replace_emoji_shortcode = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Drop Size Target"),
                description: Cow::Borrowed("Relative size of the drop target in the editor that will open dropped file as a split pane."),
                field: Box::new(SettingField {
                    json_path: Some("drop_target_size"),
                    pick: |settings_content| settings_content.workspace.drop_target_size.as_ref(),
                    write: |settings_content, value| {
                        settings_content.workspace.drop_target_size = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    let is_global = active_language().is_none();

    let lsp_document_colors_item = [SettingsPageItem::SettingItem(SettingItem {
        title: Cow::Borrowed("LSP Document Colors"),
        description: Cow::Borrowed("How to render LSP color previews in the editor."),
        field: Box::new(SettingField {
            json_path: Some("lsp_document_colors"),
            pick: |settings_content| settings_content.editor.lsp_document_colors.as_ref(),
            write: |settings_content, value| {
                settings_content.editor.lsp_document_colors = value;
            },
        }),
        metadata: None,
        files: USER,
    })];

    if is_global {
        concat_sections!(
            indentation_section(),
            wrapping_section(),
            indent_guides_section(),
            formatting_section(),
            autoclose_section(),
            whitespace_section(),
            completions_section(),
            inlay_hints_section(),
            lsp_document_colors_item,
            tasks_section(),
            miscellaneous_section(),
            global_only_miscellaneous_sub_section(),
        )
    } else {
        concat_sections!(
            indentation_section(),
            wrapping_section(),
            indent_guides_section(),
            formatting_section(),
            autoclose_section(),
            whitespace_section(),
            completions_section(),
            inlay_hints_section(),
            tasks_section(),
            miscellaneous_section(),
        )
    }
}

/// LanguageSettings items that should be included in the "Languages & Tools" page
/// not the "Editor" page
fn non_editor_language_settings_data() -> Box<[SettingsPageItem]> {
    fn lsp_section() -> [SettingsPageItem; 5] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("LSP")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Enable Language Server"),
                description: Cow::Borrowed("Whether to use language servers to provide code intelligence."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).enable_language_server"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.enable_language_server.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.enable_language_server = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Language Servers"),
                description: Cow::Borrowed("The list of language servers to use (or disable) for this language."),
                field: Box::new(
                    SettingField {
                        json_path: Some("languages.$(language).language_servers"),
                        pick: |settings_content| {
                            language_settings_field(settings_content, |language| {
                                language.language_servers.as_ref()
                            })
                        },
                        write: |settings_content, value| {
                            language_settings_field_mut(
                                settings_content,
                                value,
                                |language, value| {
                                    language.language_servers = value;
                                },
                            )
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Linked Edits"),
                description: Cow::Borrowed("Whether to perform linked edits of associated ranges, if the LS supports it. For example, when editing opening <html> tag, the contents of the closing </html> tag will be edited as well."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).linked_edits"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.linked_edits.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.linked_edits = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Go To Definition Fallback"),
                description: Cow::Borrowed("Whether to follow-up empty Go to definition responses from the language server."),
                field: Box::new(SettingField {
                    json_path: Some("go_to_definition_fallback"),
                    pick: |settings_content| {
                        settings_content.editor.go_to_definition_fallback.as_ref()
                    },
                    write: |settings_content, value| {
                        settings_content.editor.go_to_definition_fallback = value;
                    },
                }),
                metadata: None,
                files: USER,
            }),
        ]
    }

    fn lsp_completions_section() -> [SettingsPageItem; 4] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("LSP Completions")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Enabled"),
                description: Cow::Borrowed("Whether to fetch LSP completions or not."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).completions.lsp"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.completions.as_ref()?.lsp.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.completions.get_or_insert_default().lsp = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Fetch Timeout (milliseconds)"),
                description: Cow::Borrowed("When fetching LSP completions, determines how long to wait for a response of a particular server (set to 0 to wait indefinitely)."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).completions.lsp_fetch_timeout_ms"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.completions.as_ref()?.lsp_fetch_timeout_ms.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language
                                .completions
                                .get_or_insert_default()
                                .lsp_fetch_timeout_ms = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Insert Mode"),
                description: Cow::Borrowed("Controls how LSP completions are inserted."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).completions.lsp_insert_mode"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.completions.as_ref()?.lsp_insert_mode.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.completions.get_or_insert_default().lsp_insert_mode = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
        ]
    }

    fn debugger_section() -> [SettingsPageItem; 2] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Debuggers")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Debuggers"),
                description: Cow::Borrowed("Preferred debuggers for this language."),
                field: Box::new(
                    SettingField {
                        json_path: Some("languages.$(language).debuggers"),
                        pick: |settings_content| {
                            language_settings_field(settings_content, |language| {
                                language.debuggers.as_ref()
                            })
                        },
                        write: |settings_content, value| {
                            language_settings_field_mut(
                                settings_content,
                                value,
                                |language, value| {
                                    language.debuggers = value;
                                },
                            )
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER | PROJECT,
            }),
        ]
    }

    fn prettier_section() -> [SettingsPageItem; 5] {
        [
            SettingsPageItem::SectionHeader(Cow::Borrowed("Prettier")),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Allowed"),
                description: Cow::Borrowed("Enables or disables formatting with Prettier for a given language."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).prettier.allowed"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.prettier.as_ref()?.allowed.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.prettier.get_or_insert_default().allowed = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Parser"),
                description: Cow::Borrowed("Forces Prettier integration to use a specific parser name when formatting files with the language."),
                field: Box::new(SettingField {
                    json_path: Some("languages.$(language).prettier.parser"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.prettier.as_ref()?.parser.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.prettier.get_or_insert_default().parser = value;
                        })
                    },
                }),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Plugins"),
                description: Cow::Borrowed("Forces Prettier integration to use specific plugins when formatting files with the language."),
                field: Box::new(
                    SettingField {
                        json_path: Some("languages.$(language).prettier.plugins"),
                        pick: |settings_content| {
                            language_settings_field(settings_content, |language| {
                                language.prettier.as_ref()?.plugins.as_ref()
                            })
                        },
                        write: |settings_content, value| {
                            language_settings_field_mut(
                                settings_content,
                                value,
                                |language, value| {
                                    language.prettier.get_or_insert_default().plugins = value;
                                },
                            )
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER | PROJECT,
            }),
            SettingsPageItem::SettingItem(SettingItem {
                title: Cow::Borrowed("Options"),
                description: Cow::Borrowed("Default Prettier options, in the format as in package.json section for Prettier."),
                field: Box::new(
                    SettingField {
                        json_path: Some("languages.$(language).prettier.options"),
                        pick: |settings_content| {
                            language_settings_field(settings_content, |language| {
                                language.prettier.as_ref()?.options.as_ref()
                            })
                        },
                        write: |settings_content, value| {
                            language_settings_field_mut(
                                settings_content,
                                value,
                                |language, value| {
                                    language.prettier.get_or_insert_default().options = value;
                                },
                            )
                        },
                    }
                    .unimplemented(),
                ),
                metadata: None,
                files: USER | PROJECT,
            }),
        ]
    }

    concat_sections!(
        lsp_section(),
        lsp_completions_section(),
        debugger_section(),
        prettier_section(),
    )
}

fn edit_prediction_language_settings_section() -> [SettingsPageItem; 4] {
    [
        SettingsPageItem::SectionHeader(Cow::Borrowed("Edit Predictions")),
        SettingsPageItem::SubPageLink(SubPageLink {
            title: "Configure Providers".into(),
            r#type: Default::default(),
            json_path: Some("edit_predictions.providers"),
            description: Some("Set up different edit prediction providers in complement to Zed's built-in Zeta model.".into()),
            in_json: false,
            files: USER,
            render: render_edit_prediction_setup_page
        }),
        SettingsPageItem::SettingItem(SettingItem {
            title: Cow::Borrowed("Show Edit Predictions"),
            description: Cow::Borrowed("Controls whether edit predictions are shown immediately or manually."),
            field: Box::new(SettingField {
                json_path: Some("languages.$(language).show_edit_predictions"),
                pick: |settings_content| {
                    language_settings_field(settings_content, |language| {
                        language.show_edit_predictions.as_ref()
                    })
                },
                write: |settings_content, value| {
                    language_settings_field_mut(settings_content, value, |language, value| {
                        language.show_edit_predictions = value;
                    })
                },
            }),
            metadata: None,
            files: USER | PROJECT,
        }),
        SettingsPageItem::SettingItem(SettingItem {
            title: Cow::Borrowed("Disable in Language Scopes"),
            description: Cow::Borrowed("Controls whether edit predictions are shown in the given language scopes."),
            field: Box::new(
                SettingField {
                    json_path: Some("languages.$(language).edit_predictions_disabled_in"),
                    pick: |settings_content| {
                        language_settings_field(settings_content, |language| {
                            language.edit_predictions_disabled_in.as_ref()
                        })
                    },
                    write: |settings_content, value| {
                        language_settings_field_mut(settings_content, value, |language, value| {
                            language.edit_predictions_disabled_in = value;
                        })
                    },
                }
                .unimplemented(),
            ),
            metadata: None,
            files: USER | PROJECT,
        }),
    ]
}

fn show_scrollbar_or_editor(
    settings_content: &SettingsContent,
    show: fn(&SettingsContent) -> Option<&settings::ShowScrollbar>,
) -> Option<&settings::ShowScrollbar> {
    show(settings_content).or(settings_content
        .editor
        .scrollbar
        .as_ref()
        .and_then(|scrollbar| scrollbar.show.as_ref()))
}

fn dynamic_variants<T>() -> &'static [T::Discriminant]
where
    T: strum::IntoDiscriminant,
    T::Discriminant: strum::VariantArray,
{
    <<T as strum::IntoDiscriminant>::Discriminant as strum::VariantArray>::VARIANTS
}
