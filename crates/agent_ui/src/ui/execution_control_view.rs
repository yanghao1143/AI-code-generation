use gpui::{Context, IntoElement, ParentElement, Render, Styled, Window};
use ui::prelude::*;
use ui::Label;

#[derive(Clone, Debug, PartialEq)]
pub enum AgentStatus {
    Idle,
    Thinking,
    Executing,
    Paused,
    Error(String),
}

pub struct ExecutionControlView {
    status: AgentStatus,
    on_stop: Option<Box<dyn Fn(&mut Window, &mut Context<Self>) + 'static>>,
    on_pause_resume: Option<Box<dyn Fn(&mut Window, &mut Context<Self>) + 'static>>,
}

impl ExecutionControlView {
    pub fn new() -> Self {
        Self {
            status: AgentStatus::Idle,
            on_stop: None,
            on_pause_resume: None,
        }
    }

    pub fn set_status(&mut self, status: AgentStatus) {
        self.status = status;
    }

    pub fn on_stop(
        mut self,
        callback: impl Fn(&mut Window, &mut Context<Self>) + 'static,
    ) -> Self {
        self.on_stop = Some(Box::new(callback));
        self
    }

    pub fn on_pause_resume(
        mut self,
        callback: impl Fn(&mut Window, &mut Context<Self>) + 'static,
    ) -> Self {
        self.on_pause_resume = Some(Box::new(callback));
        self
    }
}

impl Render for ExecutionControlView {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let status_label = match &self.status {
            AgentStatus::Idle => "Idle".to_string(),
            AgentStatus::Thinking => "Thinking...".to_string(),
            AgentStatus::Executing => "Executing...".to_string(),
            AgentStatus::Paused => "Paused".to_string(),
            AgentStatus::Error(msg) => msg.clone(),
        };

        let status_color = match &self.status {
            AgentStatus::Idle => Color::Muted,
            AgentStatus::Thinking => Color::Info,
            AgentStatus::Executing => Color::Success,
            AgentStatus::Paused => Color::Warning,
            AgentStatus::Error(_) => Color::Error,
        };

        let is_running = matches!(
            self.status,
            AgentStatus::Thinking | AgentStatus::Executing
        );
        let is_paused = matches!(self.status, AgentStatus::Paused);

        h_flex()
            .justify_between()
            .items_center()
            .p_2()
            .bg(cx.theme().colors().surface_background)
            .border_b_1()
            .border_color(cx.theme().colors().border)
            .child(
                h_flex()
                    .gap_2()
                    .child(Label::new(status_label).color(status_color)),
            )
            .child(
                h_flex()
                    .gap_2()
                    .when(is_running || is_paused, |this| {
                        this.child(
                            Button::new(
                                "pause-resume",
                                if is_paused { "Resume" } else { "Pause" },
                            )
                            .style(ButtonStyle::Subtle)
                            .on_click(cx.listener(|this, _, window, cx| {
                                if let Some(callback) = &this.on_pause_resume {
                                    callback(window, cx);
                                }
                            })),
                        )
                        .child(
                            Button::new("stop", t("stop"))
                                .style(ButtonStyle::Subtle) // Destructive style not available in prelude?
                                .on_click(cx.listener(|this, _, window, cx| {
                                    if let Some(callback) = &this.on_stop {
                                        callback(window, cx);
                                    }
                                })),
                        )
                    }),
            )
    }
}
