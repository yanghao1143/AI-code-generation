use gpui::{IntoElement, ParentElement};
use i18n::{t, t_args};
use ui::{List, ListBulletItem, prelude::*};

/// Centralized definitions for Chi Code AI plans
pub struct PlanDefinitions;

impl PlanDefinitions {
    pub const AI_DESCRIPTION: &'static str = "Chi Code offers a complete agentic experience, with robust editing and reviewing features to collaborate with AI.";

    pub fn free_plan(&self) -> impl IntoElement {
        List::new()
            .child(ListBulletItem::new(t_args(
                "ai-accepted-predictions",
                &[("count", "2,000")].into_iter().collect(),
            )))
            .child(ListBulletItem::new(t("ai-unlimited-prompts")))
            .child(ListBulletItem::new(t("ai-unlimited-agents")))
    }

    pub fn pro_trial(&self, period: bool) -> impl IntoElement {
        List::new()
            .child(ListBulletItem::new(t("ai-unlimited-predictions")))
            .child(ListBulletItem::new(t_args(
                "ai-tokens-amount",
                &[("amount", "$20")].into_iter().collect(),
            )))
            .when(period, |this| {
                this.child(ListBulletItem::new(t("ai-trial-days")))
            })
    }

    pub fn pro_plan(&self) -> impl IntoElement {
        List::new()
            .child(ListBulletItem::new(t("ai-unlimited-predictions")))
            .child(ListBulletItem::new(t_args(
                "ai-tokens-amount",
                &[("amount", "$5")].into_iter().collect(),
            )))
            .child(ListBulletItem::new(t_args(
                "ai-usage-billing",
                &[("amount", "$5")].into_iter().collect(),
            )))
    }
}
