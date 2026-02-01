//! CC-Switch Panel implementation
//!
//! Implements the Panel trait for the left sidebar.

use crate::views::{McpView, ProvidersView, SkillsView};
use crate::{AppType, CcSwitchConfig, CcSwitchSettings, McpServerId, PanelTab, ProviderId, SkillId};
use anyhow::{Context as _, Result};
use db::kvp::KEY_VALUE_STORE;
use gpui::{
    AnyElement, App, AsyncWindowContext, Context, Entity, EventEmitter, FocusHandle, Focusable,
    InteractiveElement, IntoElement, ParentElement, Pixels, Render, Styled,
    Subscription, Task, WeakEntity, Window, actions, div,
};
use i18n::t;
use serde::{Deserialize, Serialize};
use settings::Settings;
use ui::prelude::*;
use ui_input::InputField;
use util::ResultExt;
use workspace::{
    Workspace,
    dock::{DockPosition, Panel, PanelEvent},
};

const CC_SWITCH_PANEL_KEY: &str = "CcSwitchPanel";

actions!(
    cc_switch,
    [
        /// Toggles focus on the CC-Switch panel.
        ToggleFocus,
    ]
);

pub fn init(cx: &mut App) {
    cx.observe_new(Workspace::register_cc_switch_panel).detach();
}

trait WorkspaceExt {
    fn register_cc_switch_panel(&mut self, _window: Option<&mut Window>, cx: &mut Context<Self>)
    where
        Self: Sized;
}

impl WorkspaceExt for Workspace {
    fn register_cc_switch_panel(&mut self, _window: Option<&mut Window>, _cx: &mut Context<Self>) {
        self.register_action(|workspace, _: &ToggleFocus, window, cx| {
            workspace.toggle_panel_focus::<CcSwitchPanel>(window, cx);
        });
    }
}

/// Serialized panel state for persistence
#[derive(Debug, Clone, Serialize, Deserialize)]
struct SerializedCcSwitchPanel {
    width: Option<Pixels>,
    /// Position as string: "left" or "right"
    position: Option<String>,
    active_tab: Option<usize>,
}

/// CC-Switch panel for managing providers, MCP servers, and skills
pub struct CcSwitchPanel {
    focus_handle: FocusHandle,
    workspace: WeakEntity<Workspace>,
    active_tab: PanelTab,
    width: Option<Pixels>,
    position: DockPosition,
    pending_serialization: Task<Option<()>>,
    _settings_subscription: Subscription,
    /// Configuration data for all views
    config: CcSwitchConfig,
    mcp_search_input: Entity<InputField>,
    skills_search_input: Entity<InputField>,
}

impl CcSwitchPanel {
    pub fn new(workspace: &Workspace, window: &mut Window, cx: &mut Context<Self>) -> Self {
        let focus_handle = cx.focus_handle();
        let dock_side = CcSwitchSettings::get_global(cx).dock;
        let position = match dock_side {
            settings::DockSide::Left => DockPosition::Left,
            settings::DockSide::Right => DockPosition::Right,
        };

        let _settings_subscription = cx.observe_global::<settings::SettingsStore>(|_, cx| {
            cx.notify();
        });

        // Load initial config (will be populated later from persistence)
        let config = CcSwitchConfig::default();

        let mcp_search_input = cx.new(|cx| {
            InputField::new(window, cx, &t("cc-search-mcp-servers"))
                .label(&t("search"))
        });

        let skills_search_input = cx.new(|cx| {
            InputField::new(window, cx, &t("cc-search-skills"))
                .label(&t("search"))
        });

        Self {
            focus_handle,
            workspace: workspace.weak_handle(),
            active_tab: PanelTab::default(),
            width: None,
            position,
            pending_serialization: Task::ready(None),
            _settings_subscription,
            config,
            mcp_search_input,
            skills_search_input,
        }
    }

    /// Load panel state and configuration from persistence
    pub async fn load(
        workspace: WeakEntity<Workspace>,
        mut cx: AsyncWindowContext,
    ) -> Result<Entity<Self>> {
        let serialized_panel = match workspace
            .read_with(&cx, |workspace, _| Self::serialization_key(workspace))
            .ok()
            .flatten()
        {
            Some(serialization_key) => cx
                .background_spawn(async move { KEY_VALUE_STORE.read_kvp(&serialization_key) })
                .await
                .context("loading cc-switch panel state")
                .log_err()
                .flatten()
                .map(|panel| serde_json::from_str::<SerializedCcSwitchPanel>(&panel))
                .transpose()
                .log_err()
                .flatten(),
            None => None,
        };

        // Load actual configuration data
        let config = cx
            .background_spawn(async move {
                let providers = crate::persistence::load_providers().await.unwrap_or_default();
                let mcp_servers = crate::persistence::load_mcp_servers().await.unwrap_or_default();
                let skills = crate::persistence::load_skills().await.unwrap_or_default();

                let mut config = CcSwitchConfig::default();
                for p in providers {
                    config.upsert_provider(p);
                }
                for s in mcp_servers {
                    config.upsert_mcp_server(s);
                }
                for sk in skills {
                    config.upsert_skill(sk);
                }
                config
            })
            .await;

        workspace.update_in(&mut cx, |workspace, window, cx| {
            let panel = cx.new(|cx| {
                let mut panel = CcSwitchPanel::new(workspace, window, cx);
                panel.config = config;
                panel
            });

            if let Some(serialized_panel) = serialized_panel {
                panel.update(cx, |panel, cx| {
                    panel.width = serialized_panel.width.map(|px| px.round());
                    if let Some(position_str) = serialized_panel.position {
                        panel.position = match position_str.as_str() {
                            "left" => DockPosition::Left,
                            "right" => DockPosition::Right,
                            _ => DockPosition::Left,
                        };
                    }
                    if let Some(tab_index) = serialized_panel.active_tab {
                        panel.active_tab = match tab_index {
                            0 => PanelTab::Providers,
                            1 => PanelTab::Mcp,
                            2 => PanelTab::Skills,
                            _ => PanelTab::default(),
                        };
                    }
                    cx.notify();
                });
            }
            panel
        })
    }

    fn serialization_key(workspace: &Workspace) -> Option<String> {
        workspace
            .database_id()
            .map(|id| i64::from(id).to_string())
            .or(workspace.session_id())
            .map(|id| format!("{}-{:?}", CC_SWITCH_PANEL_KEY, id))
    }

    fn serialize(&mut self, cx: &mut Context<Self>) {
        let Some(serialization_key) = self
            .workspace
            .read_with(cx, |workspace, _| Self::serialization_key(workspace))
            .ok()
            .flatten()
        else {
            return;
        };

        let width = self.width;
        let position = Some(match self.position {
            DockPosition::Left => "left".to_string(),
            DockPosition::Right => "right".to_string(),
            DockPosition::Bottom => "left".to_string(), // Fallback to left
        });
        let active_tab = Some(match self.active_tab {
            PanelTab::Providers => 0,
            PanelTab::Mcp => 1,
            PanelTab::Skills => 2,
        });

        self.pending_serialization = cx.background_spawn(async move {
            KEY_VALUE_STORE
                .write_kvp(
                    serialization_key,
                    serde_json::to_string(&SerializedCcSwitchPanel {
                        width,
                        position,
                        active_tab,
                    })
                    .ok()?,
                )
                .await
                .ok()
        });
    }

    fn save_config(&mut self, cx: &mut Context<Self>) {
        let config = self.config.clone();
        cx.background_spawn(async move {
            let providers: Vec<_> = config.providers.values().cloned().collect();
            let mcp_servers: Vec<_> = config.mcp_servers.values().cloned().collect();
            let skills: Vec<_> = config.skills.values().cloned().collect();
            let current_provider = config
                .current_provider
                .as_ref()
                .and_then(|id| config.providers.get(id))
                .cloned();

            let _ = crate::persistence::save_providers(&providers).await.log_err();
            let _ = crate::persistence::save_mcp_servers(&mcp_servers)
                .await
                .log_err();
            let _ = crate::persistence::save_skills(&skills).await.log_err();

            // Sync to external apps
            let _ = crate::config_sync::sync_all_mcp_servers(&config.mcp_servers)
                .await
                .log_err();
            let _ = crate::config_sync::sync_all_skills(&config.skills)
                .await
                .log_err();

            if let Some(provider) = current_provider {
                for app in AppType::all() {
                    let _ = crate::config_sync::sync_provider_to_app(&provider, app)
                        .await
                        .log_err();
                }
            }
        })
        .detach();
    }

    fn set_active_tab(&mut self, tab: PanelTab, cx: &mut Context<Self>) {
        self.active_tab = tab;
        self.serialize(cx);
        cx.notify();
    }

    fn toggle_mcp_app(&mut self, server_id: McpServerId, app: AppType, enabled: bool, cx: &mut Context<Self>) {
        if let Some(server) = self.config.mcp_servers.get_mut(&server_id) {
            server.apps.set_enabled_for(&app, enabled);
            self.save_config(cx);
            cx.notify();
        }
    }

    fn upsert_mcp_server(&mut self, server: crate::McpServer, cx: &mut Context<Self>) {
        self.config.upsert_mcp_server(server);
        self.save_config(cx);
        cx.notify();
    }

    fn delete_mcp_server(&mut self, id: McpServerId, cx: &mut Context<Self>) {
        self.config.remove_mcp_server(&id);
        self.save_config(cx);
        cx.notify();
    }

    fn switch_provider(&mut self, provider_id: ProviderId, cx: &mut Context<Self>) {
        self.config.current_provider = Some(provider_id);
        self.save_config(cx);
        cx.notify();
    }

    fn upsert_provider(&mut self, provider: crate::Provider, cx: &mut Context<Self>) {
        self.config.upsert_provider(provider);
        self.save_config(cx);
        cx.notify();
    }

    fn delete_provider(&mut self, id: ProviderId, cx: &mut Context<Self>) {
        self.config.remove_provider(&id);
        self.save_config(cx);
        cx.notify();
    }

    fn toggle_skill_app(&mut self, skill_id: SkillId, app: AppType, enabled: bool, cx: &mut Context<Self>) {
        if let Some(skill) = self.config.skills.get_mut(&skill_id) {
            skill.apps.set_enabled_for(&app, enabled);
            self.save_config(cx);
            cx.notify();
        }
    }

    fn toggle_skill_all_apps(&mut self, skill_id: SkillId, enabled: bool, cx: &mut Context<Self>) {
        if let Some(skill) = self.config.skills.get_mut(&skill_id) {
            if enabled {
                skill.apps = crate::SkillApps::all_enabled();
            } else {
                skill.apps = crate::SkillApps::default();
            }
            self.save_config(cx);
            cx.notify();
        }
    }

    fn reorder_skills(&mut self, source_id: SkillId, target_id: SkillId, cx: &mut Context<Self>) {
        if source_id == target_id {
            return;
        }

        let skills = self.config.skills_sorted();
        let source_pos = skills.iter().position(|s| s.id == source_id);
        let target_pos = skills.iter().position(|s| s.id == target_id);

        if let (Some(source_idx), Some(target_idx)) = (source_pos, target_pos) {
            let mut ids: Vec<SkillId> = skills.iter().map(|s| s.id.clone()).collect();
            let id = ids.remove(source_idx);
            ids.insert(target_idx, id);

            for (idx, id) in ids.into_iter().enumerate() {
                if let Some(skill) = self.config.skills.get_mut(&id) {
                    skill.sort_index = Some(idx);
                }
            }
            self.save_config(cx);
            cx.notify();
        }
    }

    fn uninstall_skill(&mut self, id: SkillId, cx: &mut Context<Self>) {
        if let Some(skill) = self.config.remove_skill(&id) {
            // Also remove from apps
            let directory = skill.directory.clone();
            cx.background_spawn(async move {
                for app in AppType::all() {
                    let _ = crate::config_sync::remove_skill_from_app(&directory, app).log_err();
                }
            })
            .detach();
            self.save_config(cx);
            cx.notify();
        }
    }

    fn upsert_skill(&mut self, skill: crate::InstalledSkill, cx: &mut Context<Self>) {
        let Some(workspace) = self.workspace.upgrade() else {
            return;
        };
        let fs = workspace.read(cx).app_state().fs.clone();

        let task = cx.background_spawn(async move {
            crate::config_sync::install_skill_files(&skill, fs).await?;
            anyhow::Ok(skill)
        });

        cx.spawn(async move |this, cx| {
            if let Ok(skill) = task.await {
                let _ = this.update(cx, |this, cx| {
                    this.config.upsert_skill(skill);
                    this.save_config(cx);
                    cx.notify();
                });
            } else {
                log::error!("Failed to install skill files");
            }
        })
        .detach();
    }

    fn render_tab_bar(&self, cx: &Context<Self>) -> impl IntoElement {
        let tabs = [PanelTab::Providers, PanelTab::Mcp, PanelTab::Skills];

        div()
            .flex()
            .flex_row()
            .w_full()
            .border_b_1()
            .border_color(cx.theme().colors().border)
            .children(tabs.into_iter().map(|tab| {
                let is_active = self.active_tab == tab;
                let label = match tab {
                    PanelTab::Providers => t("cc-providers"),
                    PanelTab::Mcp => t("cc-mcp"),
                    PanelTab::Skills => t("cc-skills-tab"),
                };
                div()
                    .id(tab.label())
                    .px_2()
                    .py_1()
                    .cursor_pointer()
                    .when(is_active, |this| {
                        this.border_b_2()
                            .border_color(cx.theme().colors().border_focused)
                    })
                    .child(Label::new(label).size(LabelSize::Small))
                    .on_click(cx.listener(move |this, _, _, cx| {
                        this.set_active_tab(tab, cx);
                    }))
            }))
    }

    fn render_content(&self, _window: &mut Window, cx: &mut Context<Self>) -> AnyElement {
        let this = cx.weak_entity();
        let workspace = self.workspace.clone();
        let config = self.config.clone();

        match self.active_tab {
            PanelTab::Providers => {
                // ... (Providers implementation remains same)
                let mut view = ProvidersView::new(config.clone());

                // on_switch callback
                let this_switch = this.clone();
                view = view.on_switch(move |id, _window, cx| {
                    if let Some(this) = this_switch.upgrade() {
                        this.update(cx, |this, cx| {
                            this.switch_provider(id, cx);
                        });
                    }
                });

                // on_add callback
                let workspace_add = workspace.clone();
                let this_add = this.clone();
                view = view.on_add(move |window, cx| {
                    let panel = this_add.clone();
                    if let Some(workspace) = workspace_add.upgrade() {
                        workspace.update(cx, |workspace, cx| {
                            workspace.toggle_modal(window, cx, |window, cx| {
                                crate::views::AddProviderModal::new(window, cx, None, move |provider, _window, cx| {
                                    if let Some(panel) = panel.upgrade() {
                                        panel.update(cx, |panel, cx| {
                                            panel.upsert_provider(provider, cx);
                                        });
                                    }
                                })
                            });
                        });
                    }
                });

                // on_edit callback
                let workspace_edit = workspace.clone();
                let config_edit = config.clone();
                let this_edit = this.clone();
                view = view.on_edit(move |id, window, cx| {
                    let panel = this_edit.clone();
                    if let Some(provider) = config_edit.providers.get(&id).cloned() {
                        if let Some(workspace) = workspace_edit.upgrade() {
                            workspace.update(cx, |workspace, cx| {
                                workspace.toggle_modal(window, cx, |window, cx| {
                                    crate::views::AddProviderModal::new(window, cx, Some(provider), move |provider, _window, cx| {
                                        if let Some(panel) = panel.upgrade() {
                                            panel.update(cx, |panel, cx| {
                                                panel.upsert_provider(provider, cx);
                                            });
                                        }
                                    })
                                });
                            });
                        }
                    }
                });

                // on_delete callback
                let this_delete = this.clone();
                view = view.on_delete(move |id, _window, cx| {
                    if let Some(this) = this_delete.upgrade() {
                        this.update(cx, |this, cx| {
                            this.delete_provider(id, cx);
                        });
                    }
                });

                view.render_content(cx)
            }
            PanelTab::Mcp => {
                let mcp_query = self.mcp_search_input.read(cx).text(cx).to_lowercase();
                let servers = self.config.mcp_servers_sorted()
                    .into_iter()
                    .filter(|s| s.name.to_lowercase().contains(&mcp_query) || s.description.as_ref().map_or(false, |d| d.to_lowercase().contains(&mcp_query)))
                    .cloned()
                    .collect();
                
                let mut view = McpView::new(servers);

                // on_toggle_app callback
                let this_toggle = this.clone();
                view = view.on_toggle_app(move |id, app, enabled, _window, cx| {
                    if let Some(this) = this_toggle.upgrade() {
                        this.update(cx, |this, cx| {
                            this.toggle_mcp_app(id, app, enabled, cx);
                        });
                    }
                });

                // on_add callback
                let workspace_add = workspace.clone();
                let this_add = this.clone();
                view = view.on_add(move |window, cx| {
                    let panel = this_add.clone();
                    if let Some(workspace) = workspace_add.upgrade() {
                        workspace.update(cx, |workspace, cx| {
                            workspace.toggle_modal(window, cx, |window, cx| {
                                crate::views::AddMcpServerModal::new(window, cx, None, move |server, _window, cx| {
                                    if let Some(panel) = panel.upgrade() {
                                        panel.update(cx, |panel, cx| {
                                            panel.upsert_mcp_server(server, cx);
                                        });
                                    }
                                })
                            });
                        });
                    }
                });

                // on_edit callback
                let workspace_edit = workspace.clone();
                let config_edit = config.clone();
                let this_edit_mcp = this.clone();
                view = view.on_edit(move |id, window, cx| {
                    let panel = this_edit_mcp.clone();
                    if let Some(server) = config_edit.mcp_servers.get(&id).cloned() {
                        if let Some(workspace) = workspace_edit.upgrade() {
                            workspace.update(cx, |workspace, cx| {
                                workspace.toggle_modal(window, cx, |window, cx| {
                                    crate::views::AddMcpServerModal::new(window, cx, Some(server), move |server, _window, cx| {
                                        if let Some(panel) = panel.upgrade() {
                                            panel.update(cx, |panel, cx| {
                                                panel.upsert_mcp_server(server, cx);
                                            });
                                        }
                                    })
                                });
                            });
                        }
                    }
                });

                // on_delete callback
                let this_delete = this.clone();
                view = view.on_delete(move |id, _window, cx| {
                    if let Some(this) = this_delete.upgrade() {
                        this.update(cx, |this, cx| {
                            this.delete_mcp_server(id, cx);
                        });
                    }
                });

                v_flex()
                    .size_full()
                    .child(
                        div()
                            .p_2()
                            .child(self.mcp_search_input.clone())
                    )
                    .child(view.render_content(cx))
                    .into_any_element()
            }
            PanelTab::Skills => {
                let skills_query = self.skills_search_input.read(cx).text(cx).to_lowercase();
                
                // Create a temporary config with filtered skills
                // Note: This is slightly inefficient as we clone the config, but SkillsView expects Config.
                // Better would be if SkillsView accepted Vec<InstalledSkill>.
                // For now, we can filter in the view or here. 
                // Since SkillsView uses config.skills_sorted(), we should probably filter here and pass a modified config 
                // OR modify SkillsView to accept a filtered list.
                // Let's modify SkillsView constructor to take list? 
                // No, it takes Config.
                // Let's modify config.
                
                let mut filtered_config = config.clone();
                filtered_config.skills = filtered_config.skills.into_iter().filter(|(_, s)| {
                    s.name.to_lowercase().contains(&skills_query) || 
                    s.description.as_ref().map_or(false, |d| d.to_lowercase().contains(&skills_query))
                }).collect();

                let mut view = SkillsView::new(filtered_config);

                // on_toggle_app callback
                let this_toggle = this.clone();
                view = view.on_toggle_app(move |id, app, enabled, _window, cx| {
                    if let Some(this) = this_toggle.upgrade() {
                        this.update(cx, |this, cx| {
                            this.toggle_skill_app(id, app, enabled, cx);
                        });
                    }
                });

                // on_toggle_all_apps callback
                let this_toggle_all = this.clone();
                view = view.on_toggle_all_apps(move |id, enabled, _window, cx| {
                    if let Some(this) = this_toggle_all.upgrade() {
                        this.update(cx, |this, cx| {
                            this.toggle_skill_all_apps(id, enabled, cx);
                        });
                    }
                });

                // on_reorder callback
                let this_reorder = this.clone();
                view = view.on_reorder(move |source, target, _window, cx| {
                    if let Some(this) = this_reorder.upgrade() {
                        this.update(cx, |this, cx| {
                            this.reorder_skills(source, target, cx);
                        });
                    }
                });

                // on_install callback
                let workspace_install = workspace.clone();
                let this_install = this.clone();
                view = view.on_install(move |window, cx| {
                    let panel = this_install.clone();
                    if let Some(workspace) = workspace_install.upgrade() {
                        workspace.update(cx, |workspace, cx| {
                            workspace.toggle_modal(window, cx, |window, cx| {
                                crate::views::AddSkillModal::new(window, cx, move |skill, _window, cx| {
                                    if let Some(panel) = panel.upgrade() {
                                        panel.update(cx, |panel, cx| {
                                            panel.upsert_skill(skill, cx);
                                        });
                                    }
                                })
                            });
                        });
                    }
                });

                // on_uninstall callback
                let this_uninstall = this.clone();
                view = view.on_uninstall(move |id, _window, cx| {
                    if let Some(this) = this_uninstall.upgrade() {
                        this.update(cx, |this, cx| {
                            this.uninstall_skill(id, cx);
                        });
                    }
                });

                v_flex()
                    .size_full()
                    .child(
                        div()
                            .p_2()
                            .child(self.skills_search_input.clone())
                    )
                    .child(view.render_content(cx))
                    .into_any_element()
            }
        }
    }
}

impl EventEmitter<PanelEvent> for CcSwitchPanel {}

impl Focusable for CcSwitchPanel {
    fn focus_handle(&self, _cx: &App) -> FocusHandle {
        self.focus_handle.clone()
    }
}

impl Panel for CcSwitchPanel {
    fn persistent_name() -> &'static str {
        "CC Switch"
    }

    fn panel_key() -> &'static str {
        CC_SWITCH_PANEL_KEY
    }

    fn position(&self, _window: &Window, _cx: &App) -> DockPosition {
        self.position
    }

    fn position_is_valid(&self, position: DockPosition) -> bool {
        matches!(position, DockPosition::Left | DockPosition::Right)
    }

    fn set_position(
        &mut self,
        position: DockPosition,
        _window: &mut Window,
        cx: &mut Context<Self>,
    ) {
        self.position = position;
        self.serialize(cx);
        cx.notify();
    }

    fn size(&self, _window: &Window, cx: &App) -> Pixels {
        self.width
            .unwrap_or_else(|| CcSwitchSettings::get_global(cx).default_width)
    }

    fn set_size(&mut self, size: Option<Pixels>, window: &mut Window, cx: &mut Context<Self>) {
        self.width = size;
        cx.defer_in(window, |this, _, cx| {
            this.serialize(cx);
        });
        cx.notify();
    }

    fn icon(&self, _window: &Window, cx: &App) -> Option<IconName> {
        Some(IconName::Settings).filter(|_| CcSwitchSettings::get_global(cx).button)
    }

    fn icon_tooltip(&self, _window: &Window, _cx: &App) -> Option<&'static str> {
        Some("CC Switch - AI Provider Manager")
    }

    fn toggle_action(&self) -> Box<dyn gpui::Action> {
        Box::new(ToggleFocus)
    }

    fn activation_priority(&self) -> u32 {
        7
    }
}

impl Render for CcSwitchPanel {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .key_context(CC_SWITCH_PANEL_KEY)
            .track_focus(&self.focus_handle)
            .flex()
            .flex_col()
            .size_full()
            .bg(cx.theme().colors().panel_background)
            .child(self.render_tab_bar(cx))
            .child(self.render_content(window, cx))
    }
}
