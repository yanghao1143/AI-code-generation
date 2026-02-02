use gpui::{
    AnyElement, App, Context, Entity, EventEmitter, FocusHandle, Focusable, InteractiveElement,
    IntoElement, ParentElement, Pixels, Render, Styled, WeakEntity, Window, actions,
    div, Task, AsyncApp
};
use ui::prelude::*;
use ui::{Divider, DividerColor};
use workspace::{
    dock::{DockPosition, Panel, PanelEvent},
    Workspace,
};
use ui_input::InputField;
use std::sync::Arc;
use crate::views::AgentListView;
use crate::dispatcher::Dispatcher;

const MULTI_MODEL_DISPATCH_PANEL_KEY: &str = "MultiModelDispatchPanel";

actions!(
    multi_model_dispatch,
    [
        ToggleFocus,
    ]
);

pub fn init(cx: &mut App) {
    cx.observe_new(Workspace::register_multi_model_dispatch_panel).detach();
}

trait WorkspaceExt {
    fn register_multi_model_dispatch_panel(&mut self, _window: Option<&mut Window>, cx: &mut Context<Self>)
    where
        Self: Sized;
}

impl WorkspaceExt for Workspace {
    fn register_multi_model_dispatch_panel(&mut self, _window: Option<&mut Window>, cx: &mut Context<Self>) {
        self.register_action(|workspace, _: &ToggleFocus, window, cx| {
            workspace.toggle_panel_focus::<MultiModelDispatchPanel>(window, cx);
        });
    }
}

pub struct MultiModelDispatchPanel {
    focus_handle: FocusHandle,
    workspace: WeakEntity<Workspace>,
    width: Option<Pixels>,
    position: DockPosition,
    input_field: Entity<InputField>,
    agents: Vec<AgentState>,
    dispatcher: Dispatcher,
    pending_task: Option<Task<()>>,
}

#[derive(Clone, Debug)]
pub struct AgentState {
    pub id: String,
    pub name: String,
    pub role: AgentRole,
    pub model: String,
    pub status: AgentStatus,
    pub progress: f32,
    pub current_action: String,
}

#[derive(Clone, Debug, PartialEq)]
pub enum AgentRole {
    Architect,
    Coder,
    Reviewer,
}

#[derive(Clone, Debug, PartialEq)]
pub enum AgentStatus {
    Idle,
    Working,
    Completed,
    Error,
}

impl MultiModelDispatchPanel {
    pub fn new(workspace: &Workspace, window: &mut Window, cx: &mut Context<Self>) -> Self {
        let focus_handle = cx.focus_handle();
        // Simple default for now, can be hooked to settings later
        let position = DockPosition::Right; 

        let input_field = cx.new(|cx| {
            InputField::new(window, cx, "Enter task description...")
                .label("Task")
        });

        // Initialize dummy agents
        let agents = vec![
            AgentState {
                id: "agent-1".to_string(),
                name: "Architect".to_string(),
                role: AgentRole::Architect,
                model: "Claude 3.5 Sonnet".to_string(),
                status: AgentStatus::Idle,
                progress: 0.0,
                current_action: "Ready".to_string(),
            },
            AgentState {
                id: "agent-2".to_string(),
                name: "Coder".to_string(),
                role: AgentRole::Coder,
                model: "GPT-4o".to_string(),
                status: AgentStatus::Idle,
                progress: 0.0,
                current_action: "Ready".to_string(),
            },
            AgentState {
                id: "agent-3".to_string(),
                name: "Reviewer".to_string(),
                role: AgentRole::Reviewer,
                model: "Gemini 1.5 Pro".to_string(),
                status: AgentStatus::Idle,
                progress: 0.0,
                current_action: "Ready".to_string(),
            },
        ];

        Self {
            focus_handle,
            workspace: workspace.weak_handle(),
            width: None,
            position,
            input_field,
            agents,
            dispatcher: Dispatcher::new(),
            pending_task: None,
        }
    }

    fn render_header(&self, cx: &Context<Self>) -> impl IntoElement {
        div()
            .flex()
            .flex_row()
            .justify_between()
            .items_center()
            .p_2()
            .border_b_1()
            .border_color(cx.theme().colors().border)
            .child(Label::new("Intelligent Dispatch").weight(gpui::FontWeight::BOLD))
            .child(
                IconButton::new("settings", IconName::Settings)
                    .style(ButtonStyle::Subtle)
                    .icon_size(IconSize::Small)
            )
    }

    fn render_input_section(&self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .p_2()
            .flex()
            .flex_col()
            .gap_2()
            .child(self.input_field.clone())
            .child(
                h_flex()
                    .justify_end()
                    .child(
                        Button::new("dispatch-btn", "Dispatch")
                            .style(ButtonStyle::Filled)
                            .on_click(cx.listener(|this, _, _, cx| {
                                this.start_dispatch(cx);
                            }))
                    )
            )
    }

    fn start_dispatch(&mut self, cx: &mut Context<Self>) {
        let task_text = self.input_field.read(cx).text(cx).to_string();
        if task_text.trim().is_empty() {
            return;
        }

        // Update agents status
        for agent in &mut self.agents {
            agent.status = AgentStatus::Working;
            agent.current_action = "Analyzing...".to_string();
            agent.progress = 0.1;
        }
        cx.notify();

        let task = self.dispatcher.dispatch(task_text, cx);
        
        self.pending_task = Some(cx.spawn(|this: WeakEntity<MultiModelDispatchPanel>, cx: &mut AsyncApp| {
            let mut cx = cx.clone();
            async move {
                let result = task.await;
                this.update(&mut cx, |this, cx: &mut Context<Self>| {
                    match result {
                        Ok(plan) => {
                            // Update UI with plan/result
                            for agent in &mut this.agents {
                                agent.status = AgentStatus::Completed;
                                agent.current_action = "Task Completed".to_string();
                                agent.progress = 1.0;
                            }
                            // TODO: Display plan somewhere? For now just log/notify.
                            log::info!("Dispatch result: {}", plan);
                        }
                        Err(err) => {
                            for agent in &mut this.agents {
                                agent.status = AgentStatus::Error;
                                agent.current_action = "Failed".to_string();
                            }
                            log::error!("Dispatch failed: {:?}", err);
                        }
                    }
                    cx.notify();
                }).ok();
            }
        }));
    }
}

impl Panel for MultiModelDispatchPanel {
    fn persistent_name() -> &'static str {
        "Multi Model Dispatch"
    }

    fn panel_key() -> &'static str {
        MULTI_MODEL_DISPATCH_PANEL_KEY
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
        cx.notify();
    }

    fn size(&self, _window: &Window, _cx: &App) -> Pixels {
        self.width.unwrap_or(px(300.))
    }

    fn set_size(&mut self, size: Option<Pixels>, _window: &mut Window, cx: &mut Context<Self>) {
        self.width = size;
        cx.notify();
    }

    fn icon(&self, _window: &Window, _cx: &App) -> Option<IconName> {
        Some(IconName::Server) 
    }

    fn icon_tooltip(&self, _window: &Window, _cx: &App) -> Option<SharedString> {
        Some("Intelligent Dispatch".into())
    }

    fn toggle_action(&self) -> Box<dyn gpui::Action> {
        Box::new(ToggleFocus)
    }

    fn activation_priority(&self) -> u32 {
        8
    }
}

impl EventEmitter<PanelEvent> for MultiModelDispatchPanel {}

impl Focusable for MultiModelDispatchPanel {
    fn focus_handle(&self, _cx: &App) -> FocusHandle {
        self.focus_handle.clone()
    }
}

impl Render for MultiModelDispatchPanel {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .key_context(MULTI_MODEL_DISPATCH_PANEL_KEY)
            .track_focus(&self.focus_handle)
            .flex()
            .flex_col()
            .size_full()
            .bg(cx.theme().colors().panel_background)
            .child(self.render_header(cx))
            .child(self.render_input_section(window, cx))
            .child(Divider::horizontal().color(DividerColor::Border))
            .child(
                div()
                    .id("agent-list")
                    .flex_1()
                    .overflow_y_scroll()
                    .child(cx.new(|_| AgentListView::new(self.agents.clone())))
            )
    }
}
