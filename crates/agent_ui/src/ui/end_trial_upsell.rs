use std::sync::Arc;

use ai_onboarding::{AgentPanelOnboardingCard, PlanDefinitions};
use client::zed_urls;
use gpui::{AnyElement, App, IntoElement, RenderOnce, Window};
use i18n::t;
use ui::{Divider, Tooltip, prelude::*};

#[derive(IntoElement, RegisterComponent)]
pub struct EndTrialUpsell {
    dismiss_upsell: Arc<dyn Fn(&mut Window, &mut App)>,
}

impl EndTrialUpsell {
    pub fn new(dismiss_upsell: Arc<dyn Fn(&mut Window, &mut App)>) -> Self {
        Self { dismiss_upsell }
    }
}

impl RenderOnce for EndTrialUpsell {
    fn render(self, _window: &mut Window, cx: &mut App) -> impl IntoElement {
        let pro_section = v_flex()
            .gap_1()
            .child(
                h_flex()
                    .gap_2()
                    .child(
                        Label::new(t("ai-plan-pro"))
                            .size(LabelSize::Small)
                            .color(Color::Accent)
                            .buffer_font(cx),
                    )
                    .child(Divider::horizontal()),
            )
            .child(PlanDefinitions.pro_plan())
            .child(
                Button::new("cta-button", t("agent-upgrade-to-pro"))
                    .full_width()
                    .style(ButtonStyle::Tinted(ui::TintColor::Accent))
                    .on_click(move |_, _window, cx| {
                        telemetry::event!("Upgrade To Pro Clicked", state = "end-of-trial");
                        cx.open_url(&zed_urls::upgrade_to_zed_pro_url(cx))
                    }),
            );

        let free_section = v_flex()
            .mt_1p5()
            .gap_1()
            .child(
                h_flex()
                    .gap_2()
                    .child(
                        Label::new(t("ai-plan-free"))
                            .size(LabelSize::Small)
                            .color(Color::Muted)
                            .buffer_font(cx),
                    )
                    .child(
                        Label::new(t("agent-current-plan-label"))
                            .size(LabelSize::Small)
                            .color(Color::Custom(cx.theme().colors().text_muted.opacity(0.6)))
                            .buffer_font(cx),
                    )
                    .child(Divider::horizontal()),
            )
            .child(PlanDefinitions.free_plan());

        AgentPanelOnboardingCard::new()
            .child(Headline::new(t("agent-trial-expired")))
            .child(
                Label::new(t("agent-reset-to-free"))
                    .color(Color::Muted)
                    .mb_2(),
            )
            .child(pro_section)
            .child(free_section)
            .child(
                h_flex().absolute().top_4().right_4().child(
                    IconButton::new("dismiss_onboarding", IconName::Close)
                        .icon_size(IconSize::Small)
                        .tooltip(Tooltip::text(t("dismiss")))
                        .on_click({
                            let callback = self.dismiss_upsell.clone();
                            move |_, window, cx| {
                                telemetry::event!("Banner Dismissed", source = "AI Onboarding");
                                callback(window, cx)
                            }
                        }),
                ),
            )
    }
}

impl Component for EndTrialUpsell {
    fn scope() -> ComponentScope {
        ComponentScope::Onboarding
    }

    fn name() -> &'static str {
        "End of Trial Upsell Banner"
    }

    fn sort_name() -> &'static str {
        "End of Trial Upsell Banner"
    }

    fn preview(_window: &mut Window, _cx: &mut App) -> Option<AnyElement> {
        Some(
            v_flex()
                .child(EndTrialUpsell {
                    dismiss_upsell: Arc::new(|_, _| {}),
                })
                .into_any_element(),
        )
    }
}
