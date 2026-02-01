use collab_ui::collab_panel;
use gpui::{App, Menu, MenuItem, OsAction};
use i18n::t;
use release_channel::ReleaseChannel;
use terminal_view::terminal_panel;
use zed_actions::{ToggleFocus as ToggleDebugPanel, dev};

pub fn app_menus(cx: &mut App) -> Vec<Menu> {
    use zed_actions::Quit;

    let mut view_items = vec![
        MenuItem::action(
            &t("menu-zoom-in"),
            zed_actions::IncreaseBufferFontSize { persist: false },
        ),
        MenuItem::action(
            &t("menu-zoom-out"),
            zed_actions::DecreaseBufferFontSize { persist: false },
        ),
        MenuItem::action(
            &t("menu-reset-zoom"),
            zed_actions::ResetBufferFontSize { persist: false },
        ),
        MenuItem::action(
            &t("menu-reset-all-zoom"),
            zed_actions::ResetAllZoom { persist: false },
        ),
        MenuItem::separator(),
        MenuItem::action(&t("menu-toggle-left-dock"), workspace::ToggleLeftDock),
        MenuItem::action(&t("menu-toggle-right-dock"), workspace::ToggleRightDock),
        MenuItem::action(&t("menu-toggle-bottom-dock"), workspace::ToggleBottomDock),
        MenuItem::action(&t("menu-toggle-all-docks"), workspace::ToggleAllDocks),
        MenuItem::submenu(Menu {
            name: t("menu-editor-layout").into(),
            items: vec![
                MenuItem::action(&t("menu-split-up"), workspace::SplitUp::default()),
                MenuItem::action(&t("menu-split-down"), workspace::SplitDown::default()),
                MenuItem::action(&t("menu-split-left"), workspace::SplitLeft::default()),
                MenuItem::action(&t("menu-split-right"), workspace::SplitRight::default()),
            ],
        }),
        MenuItem::separator(),
        MenuItem::action(&t("menu-project-panel"), zed_actions::project_panel::ToggleFocus),
        MenuItem::action(&t("menu-outline-panel"), outline_panel::ToggleFocus),
        MenuItem::action(&t("menu-collab-panel"), collab_panel::ToggleFocus),
        MenuItem::action(&t("menu-terminal-panel"), terminal_panel::ToggleFocus),
        MenuItem::action(&t("menu-debugger-panel"), ToggleDebugPanel),
        MenuItem::separator(),
        MenuItem::action(&t("menu-diagnostics"), diagnostics::Deploy),
        MenuItem::separator(),
    ];

    if ReleaseChannel::try_global(cx) == Some(ReleaseChannel::Dev) {
        view_items.push(MenuItem::action(
            &t("menu-toggle-inspector"),
            dev::ToggleInspector,
        ));
        view_items.push(MenuItem::separator());
    }

    vec![
        Menu {
            name: t("menu-app-name").into(),
            items: vec![
                MenuItem::action(&t("menu-about"), zed_actions::About),
                MenuItem::action(&t("menu-check-updates"), auto_update::Check),
                MenuItem::separator(),
                MenuItem::submenu(Menu {
                    name: t("menu-settings").into(),
                    items: vec![
                        MenuItem::action(&t("menu-open-settings"), zed_actions::OpenSettings),
                        MenuItem::action(&t("menu-open-settings-file"), super::OpenSettingsFile),
                        MenuItem::action(&t("menu-open-project-settings"), zed_actions::OpenProjectSettings),
                        MenuItem::action(
                            &t("menu-open-project-settings-file"),
                            super::OpenProjectSettingsFile,
                        ),
                        MenuItem::action(&t("menu-open-default-settings"), super::OpenDefaultSettings),
                        MenuItem::separator(),
                        MenuItem::action(&t("menu-open-keymap"), zed_actions::OpenKeymap),
                        MenuItem::action(&t("menu-open-keymap-file"), zed_actions::OpenKeymapFile),
                        MenuItem::action(
                            &t("menu-open-default-keybindings"),
                            zed_actions::OpenDefaultKeymap,
                        ),
                        MenuItem::separator(),
                        MenuItem::action(
                            &t("menu-select-theme"),
                            zed_actions::theme_selector::Toggle::default(),
                        ),
                        MenuItem::action(
                            &t("menu-select-icon-theme"),
                            zed_actions::icon_theme_selector::Toggle::default(),
                        ),
                    ],
                }),
                MenuItem::separator(),
                #[cfg(target_os = "macos")]
                MenuItem::os_submenu("Services", gpui::SystemMenuType::Services),
                MenuItem::separator(),
                MenuItem::action(&t("menu-extensions"), zed_actions::Extensions::default()),
                #[cfg(not(target_os = "windows"))]
                MenuItem::action(&t("menu-install-cli"), install_cli::InstallCliBinary),
                MenuItem::separator(),
                #[cfg(target_os = "macos")]
                MenuItem::action(&t("menu-hide-app"), super::Hide),
                #[cfg(target_os = "macos")]
                MenuItem::action(&t("menu-hide-others"), super::HideOthers),
                #[cfg(target_os = "macos")]
                MenuItem::action(&t("menu-show-all"), super::ShowAll),
                MenuItem::separator(),
                MenuItem::action(&t("menu-quit"), Quit),
            ],
        },
        Menu {
            name: t("menu-file").into(),
            items: vec![
                MenuItem::action(&t("menu-new"), workspace::NewFile),
                MenuItem::action(&t("menu-new-window"), workspace::NewWindow),
                MenuItem::separator(),
                #[cfg(not(target_os = "macos"))]
                MenuItem::action(&t("menu-open-file"), workspace::OpenFiles),
                #[cfg(not(target_os = "macos"))]
                MenuItem::action(&t("menu-open-folder"), workspace::Open),
                #[cfg(target_os = "macos")]
                MenuItem::action(&t("menu-open"), workspace::Open),
                MenuItem::action(
                    &t("menu-open-recent"),
                    zed_actions::OpenRecent {
                        create_new_window: false,
                    },
                ),
                MenuItem::action(
                    &t("menu-open-remote"),
                    zed_actions::OpenRemote {
                        create_new_window: false,
                        from_existing_connection: false,
                    },
                ),
                MenuItem::separator(),
                MenuItem::action(&t("menu-add-folder-to-project"), workspace::AddFolderToProject),
                MenuItem::separator(),
                MenuItem::action(&t("menu-save"), workspace::Save { save_intent: None }),
                MenuItem::action(&t("menu-save-as"), workspace::SaveAs),
                MenuItem::action(&t("menu-save-all"), workspace::SaveAll { save_intent: None }),
                MenuItem::separator(),
                MenuItem::action(
                    &t("menu-close-editor"),
                    workspace::CloseActiveItem {
                        save_intent: None,
                        close_pinned: true,
                    },
                ),
                MenuItem::action(&t("menu-close-project"), workspace::CloseProject),
                MenuItem::action(&t("menu-close-window"), workspace::CloseWindow),
            ],
        },
        Menu {
            name: t("menu-edit").into(),
            items: vec![
                MenuItem::os_action(&t("menu-undo"), editor::actions::Undo, OsAction::Undo),
                MenuItem::os_action(&t("menu-redo"), editor::actions::Redo, OsAction::Redo),
                MenuItem::separator(),
                MenuItem::os_action(&t("menu-cut"), editor::actions::Cut, OsAction::Cut),
                MenuItem::os_action(&t("menu-copy"), editor::actions::Copy, OsAction::Copy),
                MenuItem::action(&t("menu-copy-trim"), editor::actions::CopyAndTrim),
                MenuItem::os_action(&t("menu-paste"), editor::actions::Paste, OsAction::Paste),
                MenuItem::separator(),
                MenuItem::action(&t("menu-find"), search::buffer_search::Deploy::find()),
                MenuItem::action(&t("menu-find-in-project"), workspace::DeploySearch::find()),
                MenuItem::separator(),
                MenuItem::action(
                    &t("menu-toggle-comment"),
                    editor::actions::ToggleComments::default(),
                ),
            ],
        },
        Menu {
            name: t("menu-selection").into(),
            items: vec![
                MenuItem::os_action(
                    &t("menu-select-all"),
                    editor::actions::SelectAll,
                    OsAction::SelectAll,
                ),
                MenuItem::action(&t("menu-expand-selection"), editor::actions::SelectLargerSyntaxNode),
                MenuItem::action(&t("menu-shrink-selection"), editor::actions::SelectSmallerSyntaxNode),
                MenuItem::action(&t("menu-select-next-sibling"), editor::actions::SelectNextSyntaxNode),
                MenuItem::action(
                    &t("menu-select-prev-sibling"),
                    editor::actions::SelectPreviousSyntaxNode,
                ),
                MenuItem::separator(),
                MenuItem::action(
                    &t("menu-add-cursor-above"),
                    editor::actions::AddSelectionAbove {
                        skip_soft_wrap: true,
                    },
                ),
                MenuItem::action(
                    &t("menu-add-cursor-below"),
                    editor::actions::AddSelectionBelow {
                        skip_soft_wrap: true,
                    },
                ),
                MenuItem::action(
                    &t("menu-select-next-occurrence"),
                    editor::actions::SelectNext {
                        replace_newest: false,
                    },
                ),
                MenuItem::action(
                    &t("menu-select-prev-occurrence"),
                    editor::actions::SelectPrevious {
                        replace_newest: false,
                    },
                ),
                MenuItem::action(&t("menu-select-all-occurrences"), editor::actions::SelectAllMatches),
                MenuItem::separator(),
                MenuItem::action(&t("menu-move-line-up"), editor::actions::MoveLineUp),
                MenuItem::action(&t("menu-move-line-down"), editor::actions::MoveLineDown),
                MenuItem::action(&t("menu-duplicate-selection"), editor::actions::DuplicateLineDown),
            ],
        },
        Menu {
            name: t("menu-view").into(),
            items: view_items,
        },
        Menu {
            name: t("menu-go").into(),
            items: vec![
                MenuItem::action(&t("menu-back"), workspace::GoBack),
                MenuItem::action(&t("menu-forward"), workspace::GoForward),
                MenuItem::separator(),
                MenuItem::action(&t("menu-command-palette"), zed_actions::command_palette::Toggle),
                MenuItem::separator(),
                MenuItem::action(&t("menu-go-to-file"), workspace::ToggleFileFinder::default()),
                // MenuItem::action("Go to Symbol in Project", project_symbols::Toggle),
                MenuItem::action(
                    &t("menu-go-to-symbol"),
                    zed_actions::outline::ToggleOutline,
                ),
                MenuItem::action(&t("menu-go-to-line"), editor::actions::ToggleGoToLine),
                MenuItem::separator(),
                MenuItem::action(&t("menu-go-to-definition"), editor::actions::GoToDefinition),
                MenuItem::action(&t("menu-go-to-declaration"), editor::actions::GoToDeclaration),
                MenuItem::action(&t("menu-go-to-type-definition"), editor::actions::GoToTypeDefinition),
                MenuItem::action(
                    &t("menu-find-all-references"),
                    editor::actions::FindAllReferences::default(),
                ),
                MenuItem::separator(),
                MenuItem::action(&t("menu-next-problem"), editor::actions::GoToDiagnostic::default()),
                MenuItem::action(
                    &t("menu-prev-problem"),
                    editor::actions::GoToPreviousDiagnostic::default(),
                ),
            ],
        },
        Menu {
            name: t("menu-run").into(),
            items: vec![
                MenuItem::action(
                    &t("menu-spawn-task"),
                    zed_actions::Spawn::ViaModal {
                        reveal_target: None,
                    },
                ),
                MenuItem::action(&t("menu-start-debugger"), debugger_ui::Start),
                MenuItem::separator(),
                MenuItem::action(&t("menu-edit-tasks"), crate::zed::OpenProjectTasks),
                MenuItem::action(&t("menu-edit-debug"), zed_actions::OpenProjectDebugTasks),
                MenuItem::separator(),
                MenuItem::action(&t("menu-continue"), debugger_ui::Continue),
                MenuItem::action(&t("menu-step-over"), debugger_ui::StepOver),
                MenuItem::action(&t("menu-step-into"), debugger_ui::StepInto),
                MenuItem::action(&t("menu-step-out"), debugger_ui::StepOut),
                MenuItem::separator(),
                MenuItem::action(&t("menu-toggle-breakpoint"), editor::actions::ToggleBreakpoint),
                MenuItem::action(&t("menu-edit-breakpoint"), editor::actions::EditLogBreakpoint),
                MenuItem::action(&t("menu-clear-breakpoints"), debugger_ui::ClearAllBreakpoints),
            ],
        },
        Menu {
            name: t("menu-window").into(),
            items: vec![
                MenuItem::action(&t("menu-minimize"), super::Minimize),
                MenuItem::action(&t("menu-zoom"), super::Zoom),
                MenuItem::separator(),
            ],
        },
        Menu {
            name: t("menu-help").into(),
            items: vec![
                MenuItem::action(
                    &t("menu-release-notes"),
                    auto_update_ui::ViewReleaseNotesLocally,
                ),
                MenuItem::action(&t("menu-view-telemetry"), zed_actions::OpenTelemetryLog),
                MenuItem::action(&t("menu-view-licenses"), zed_actions::OpenLicenses),
                MenuItem::action(&t("menu-show-welcome"), onboarding::ShowWelcome),
                MenuItem::separator(),
                MenuItem::action(&t("menu-file-bug"), zed_actions::feedback::FileBugReport),
                MenuItem::action(&t("menu-request-feature"), zed_actions::feedback::RequestFeature),
                MenuItem::action(&t("menu-email-us"), zed_actions::feedback::EmailZed),
                MenuItem::separator(),
                MenuItem::action(
                    &t("menu-documentation"),
                    super::OpenBrowser {
                        url: "https://vip.chiddns.com/docs".into(),
                    },
                ),
                MenuItem::action(&t("menu-repository"), feedback::OpenZedRepo),
                MenuItem::action(
                    &t("menu-twitter"),
                    super::OpenBrowser {
                        url: "https://twitter.com/zeddotdev".into(),
                    },
                ),
                MenuItem::action(
                    &t("menu-join-team"),
                    super::OpenBrowser {
                        url: "https://vip.chiddns.com/jobs".into(),
                    },
                ),
            ],
        },
    ]
}
