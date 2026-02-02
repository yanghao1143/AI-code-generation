use gpui::{Context, IntoElement, ParentElement, Render, StatefulInteractiveElement, Styled, Window};
use i18n::t;
use ui::prelude::*;
use ui::{Icon, IconName, Label};

pub struct ProgressView {
    steps: Vec<Step>,
    logs: Vec<String>,
}

#[derive(Clone, Debug)]
pub struct Step {
    pub description: String,
    pub status: StepStatus,
}

#[derive(Clone, Debug, PartialEq)]
pub enum StepStatus {
    Pending,
    Active,
    Completed,
    Failed,
}

impl ProgressView {
    pub fn new() -> Self {
        Self {
            steps: Vec::new(),
            logs: Vec::new(),
        }
    }

    pub fn set_steps(&mut self, steps: Vec<Step>) {
        self.steps = steps;
    }

    pub fn add_log(&mut self, log: String) {
        self.logs.push(log);
    }
}

impl Render for ProgressView {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        v_flex()
            .flex_grow()
            .id("progress-view")
            .overflow_y_scroll()
            .gap_4()
            .p_2()
            .child(
                v_flex()
                    .gap_2()
                    .children(self.steps.iter().enumerate().map(|(i, step)| {
                        let icon = match step.status {
                            StepStatus::Pending => IconName::Circle, // Placeholder
                            StepStatus::Active => IconName::ArrowRight, // Placeholder for spinner
                            StepStatus::Completed => IconName::Check,
                            StepStatus::Failed => IconName::Close,
                        };

                        let color = match step.status {
                            StepStatus::Pending => Color::Muted,
                            StepStatus::Active => Color::Info,
                            StepStatus::Completed => Color::Success,
                            StepStatus::Failed => Color::Error,
                        };

                        h_flex()
                            .gap_2()
                            .child(Icon::new(icon).color(color))
                            .child(Label::new(format!("{}. {}", i + 1, step.description)))
                    })),
            )
            .child(
                div()
                    .border_t_1()
                    .border_color(cx.theme().colors().border)
                    .pt_2()
                    .child(Label::new(t("agent-logs")).weight(gpui::FontWeight::BOLD))
                    .child(
                        v_flex()
                            .gap_1()
                            .children(self.logs.iter().map(|log| {
                                Label::new(log.clone())
                                    .size(LabelSize::XSmall)
                                    .color(Color::Muted)
                            })),
                    ),
            )
    }
}
