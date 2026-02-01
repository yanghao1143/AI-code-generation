//! Agents view component
//!
//! Displays a list of AI agents (Architect, Coder, Reviewer, etc.) and their status.

use gpui::{
    Context, IntoElement, ParentElement, Render, Styled, Window, div,
};
use ui::prelude::*;
use crate::multi_model_dispatch::{AgentState, AgentRole, AgentStatus};

pub struct AgentListView {
    agents: Vec<AgentState>,
}

impl AgentListView {
    pub fn new(agents: Vec<AgentState>) -> Self {
        Self { agents }
    }

    fn render_agent_item(&self, agent: &AgentState, cx: &Context<Self>) -> impl IntoElement {
        let icon = match agent.role {
            AgentRole::Architect => IconName::Sparkle, // Placeholder
            AgentRole::Coder => IconName::FileCode,
            AgentRole::Reviewer => IconName::Check,
        };

        let status_color = match agent.status {
            AgentStatus::Idle => Color::Muted,
            AgentStatus::Working => Color::Warning,
            AgentStatus::Completed => Color::Success,
            AgentStatus::Error => Color::Error,
        };

        div()
            .border_1()
            .border_color(cx.theme().colors().border)
            .rounded_md()
            .p_2()
            .child(
                v_flex()
                    .gap_2()
                    .child(
                        h_flex()
                            .justify_between()
                            .child(
                                h_flex()
                                    .gap_2()
                                    .child(Icon::new(icon).size(IconSize::Small).color(Color::Default))
                                    .child(Label::new(agent.name.clone()).weight(gpui::FontWeight::MEDIUM))
                            )
                            .child(
                                // Simple text for model for now, can be dropdown later
                                Label::new(agent.model.clone())
                                    .size(LabelSize::XSmall)
                                    .color(Color::Muted)
                            )
                    )
                    .child(
                         h_flex()
                            .justify_between()
                            .child(
                                Label::new(agent.current_action.clone())
                                    .size(LabelSize::XSmall)
                                    .color(Color::Muted)
                            )
                            .child(
                                Icon::new(IconName::Circle) // Placeholder for status dot
                                    .size(IconSize::XSmall)
                                    .color(status_color)
                            )
                    )
            )
    }
}

impl Render for AgentListView {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .flex()
            .flex_col()
            .gap_1()
            .p_2()
            .children(self.agents.iter().map(|agent| self.render_agent_item(agent, cx)))
    }
}
