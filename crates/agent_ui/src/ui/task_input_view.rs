use gpui::{
    App, Context, Entity, FocusHandle, Focusable, IntoElement, ParentElement, Render, Styled,
    Window,
};
use ui::prelude::*;
use ui::{Button, ButtonStyle};
use editor::Editor;
use language::language_settings::SoftWrap;

pub struct TaskInputView {
    editor: Entity<Editor>,
    on_submit: Option<Box<dyn Fn(String, &mut Window, &mut App) + 'static>>,
}

impl TaskInputView {
    pub fn new(
        window: &mut Window,
        cx: &mut Context<Self>,
    ) -> Self {
        let editor = cx.new(|cx| {
            let mut editor = Editor::multi_line(window, cx);
            editor.set_placeholder_text("Describe the task...", window, cx);
            editor.set_soft_wrap_mode(SoftWrap::EditorWidth, cx);
            editor
        });

        Self {
            editor,
            on_submit: None,
        }
    }

    pub fn on_submit(
        mut self,
        callback: impl Fn(String, &mut Window, &mut App) + 'static,
    ) -> Self {
        self.on_submit = Some(Box::new(callback));
        self
    }

    fn handle_submit(&mut self, window: &mut Window, cx: &mut Context<Self>) {
        let text = self.editor.read(cx).text(cx);
        if !text.trim().is_empty() {
            if let Some(callback) = &self.on_submit {
                callback(text, window, cx);
            }
            self.editor.update(cx, |editor, cx| {
                editor.set_text("", window, cx);
            });
        }
    }
}

impl Focusable for TaskInputView {
    fn focus_handle(&self, cx: &App) -> FocusHandle {
        self.editor.focus_handle(cx)
    }
}

impl Render for TaskInputView {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        v_flex()
            .gap_2()
            .child(
                div()
                    .border_1()
                    .border_color(cx.theme().colors().border)
                    .rounded_md()
                    .child(self.editor.clone()),
            )
            .child(
                h_flex()
                    .justify_end()
                    .child(
                        Button::new("start-task", "Start Task")
                            .style(ButtonStyle::Filled)
                            .on_click(cx.listener(move |this, _, window, cx| {
                                this.handle_submit(window, cx);
                            })),
                    ),
            )
    }
}
