use std::{ops::Range, sync::Arc, time::Duration};

use anyhow::Result;
use cloud_llm_client::CompletionIntent;
use edit_prediction_context::{RelatedExcerptStore, RelatedFile};
use edit_prediction_types::{EditPrediction, EditPredictionDelegate};
use futures::StreamExt;
use gpui::{App, AppContext, Context, Entity, Task};
use language::{
    Anchor, Buffer, BufferSnapshot, EditPreview, ToOffset as _, ToPoint as _,
    language_settings::all_language_settings,
};
use language_model::{LanguageModel, LanguageModelRegistry, LanguageModelRequest, LanguageModelRequestMessage, Role};
use project::Project;
use text::OffsetRangeExt as _;

use crate::cursor_excerpt;

const DEBOUNCE_TIMEOUT: Duration = Duration::from_millis(150);
const DEFAULT_MAX_EDITABLE_TOKENS: usize = 350;
const DEFAULT_MAX_CONTEXT_TOKENS: usize = 150;
const DEFAULT_MAX_COMPLETION_TOKENS: u32 = 256;
const DEFAULT_TEMPERATURE: f32 = 0.2;
const MAX_RELATED_FILES: usize = 3;
const MAX_RELATED_FILE_CHARS: usize = 1500;

#[derive(Clone)]
struct CurrentCompletion {
    snapshot: BufferSnapshot,
    edits: Arc<[(Range<Anchor>, Arc<str>)]>,
    edit_preview: EditPreview,
}

impl CurrentCompletion {
    fn interpolate(&self, new_snapshot: &BufferSnapshot) -> Option<Vec<(Range<Anchor>, Arc<str>)>> {
        edit_prediction_types::interpolate_edits(&self.snapshot, new_snapshot, &self.edits)
    }
}

pub struct LanguageModelEditPredictionDelegate {
    context_store: Entity<RelatedExcerptStore>,
    pending_request: Option<Task<Result<()>>>,
    current_completion: Option<CurrentCompletion>,
}

impl LanguageModelEditPredictionDelegate {
    pub fn new(project: Entity<Project>, cx: &mut Context<Self>) -> Self {
        let context_store = cx.new(|cx| RelatedExcerptStore::new(&project, cx));
        Self {
            context_store,
            pending_request: None,
            current_completion: None,
        }
    }

    fn configured_model(&self, cx: &App) -> Option<Arc<dyn LanguageModel>> {
        let registry = LanguageModelRegistry::read_global(cx);
        let settings = all_language_settings(None, cx);
        if let Some(selection) = settings.edit_predictions.llm.model.as_ref() {
            let provider_id = language_model::LanguageModelProviderId(selection.provider.0.clone().into());
            let model_id = language_model::LanguageModelId(selection.model.clone().into());
            let provider = registry.provider(&provider_id)?;
            let model = provider
                .provided_models(cx)
                .into_iter()
                .find(|model| model.id() == model_id)?;
            return Some(model);
        }

        registry.default_model().map(|configured| configured.model)
    }

    fn related_files_for_context(
        &self,
        buffer: &Entity<Buffer>,
        cursor_position: Anchor,
        use_context: bool,
        cx: &mut Context<Self>,
    ) -> Vec<RelatedFile> {
        if !use_context {
            return Vec::new();
        }

        self.context_store.update(cx, |store, cx| {
            store.refresh(buffer.clone(), cursor_position, cx);
            store.related_files(cx)
        })
    }

    fn build_user_prompt(
        &self,
        snapshot: &BufferSnapshot,
        cursor_position: Anchor,
        related_files: &[RelatedFile],
        max_completion_tokens: u32,
        max_editable_tokens: usize,
        max_context_tokens: usize,
    ) -> String {
        let cursor_offset = cursor_position.to_offset(snapshot);
        let cursor_point = cursor_offset.to_point(snapshot);

        let (_editable_range, context_range) =
            cursor_excerpt::editable_and_context_ranges_for_cursor_position(
                cursor_point,
                snapshot,
                max_editable_tokens,
                max_context_tokens,
            );
        let context_range = context_range.to_offset(snapshot);

        let excerpt_text = snapshot.text_for_range(context_range.clone()).collect::<String>();
        let cursor_within_excerpt = cursor_offset
            .saturating_sub(context_range.start)
            .min(excerpt_text.len());

        let prefix = &excerpt_text[..cursor_within_excerpt];
        let suffix = &excerpt_text[cursor_within_excerpt..];

        let language_name = snapshot
            .language()
            .map(|language| language.name().to_string())
            .unwrap_or_else(|| "unknown".to_string());
        let file_path = snapshot
            .file()
            .map(|file| file.path().as_unix_str().to_string());

        let mut prompt = String::new();
        prompt.push_str("Complete the code at the cursor.\n");
        prompt.push_str("Return ONLY the text to insert at the cursor. No markdown, no explanation.\n");
        prompt.push_str(&format!(
            "Max completion tokens: {max_completion_tokens}\n"
        ));
        prompt.push_str(&format!("Language: {}\n", language_name));
        if let Some(path) = file_path {
            prompt.push_str(&format!("File: {}\n", path));
        }
        prompt.push_str("<prefix>\n");
        prompt.push_str(prefix);
        prompt.push_str("\n</prefix>\n");
        prompt.push_str("<suffix>\n");
        prompt.push_str(suffix);
        prompt.push_str("\n</suffix>\n");

        if !related_files.is_empty() {
            prompt.push_str("<related_files>\n");
            for file in related_files.iter().take(MAX_RELATED_FILES) {
                let path = file.path.as_os_str().to_string_lossy();
                prompt.push_str(&format!("file: {}\n", path));
                for excerpt in &file.excerpts {
                    let mut text = excerpt.text.as_ref().to_string();
                    if text.len() > MAX_RELATED_FILE_CHARS {
                        text.truncate(MAX_RELATED_FILE_CHARS);
                        text.push_str("\n// ...");
                    }
                    prompt.push_str(&text);
                    prompt.push('\n');
                }
                prompt.push('\n');
            }
            prompt.push_str("</related_files>\n");
        }

        prompt
    }

    fn clean_completion(raw: &str) -> String {
        let trimmed = raw.trim();
        if let Some(block) = extract_code_fence(trimmed) {
            return block.trim_matches(['\n', '\r']).to_string();
        }
        trimmed.trim_matches(['\n', '\r']).to_string()
    }
}

impl EditPredictionDelegate for LanguageModelEditPredictionDelegate {
    fn name() -> &'static str {
        "llm"
    }

    fn display_name() -> &'static str {
        "LLM"
    }

    fn show_predictions_in_menu() -> bool {
        true
    }

    fn is_enabled(&self, _buffer: &Entity<Buffer>, _cursor_position: Anchor, cx: &App) -> bool {
        let Some(model) = self.configured_model(cx) else {
            return false;
        };
        let registry = LanguageModelRegistry::read_global(cx);
        let provider = registry.provider(&model.provider_id());
        provider.map(|provider| provider.is_authenticated(cx)).unwrap_or(false)
    }

    fn is_refreshing(&self, _cx: &App) -> bool {
        self.pending_request.is_some()
    }

    fn refresh(
        &mut self,
        buffer: Entity<Buffer>,
        cursor_position: Anchor,
        debounce: bool,
        cx: &mut Context<Self>,
    ) {
        let Some(model) = self.configured_model(cx) else {
            log::warn!("LLM edit prediction: no model configured");
            return;
        };

        let snapshot = buffer.read(cx).snapshot();

        if let Some(current_completion) = self.current_completion.as_ref() {
            if current_completion.interpolate(&snapshot).is_some() {
                return;
            }
        }

        let settings = all_language_settings(None, cx).edit_predictions.clone();
        let llm_settings = settings.llm.clone();

        let max_editable_tokens = llm_settings
            .max_editable_tokens
            .map(|value| value as usize)
            .unwrap_or(DEFAULT_MAX_EDITABLE_TOKENS);
        let max_context_tokens = llm_settings
            .max_context_tokens
            .map(|value| value as usize)
            .unwrap_or(DEFAULT_MAX_CONTEXT_TOKENS);
        let max_completion_tokens = llm_settings
            .max_tokens
            .unwrap_or(DEFAULT_MAX_COMPLETION_TOKENS);
        let temperature = llm_settings.temperature.or(Some(DEFAULT_TEMPERATURE));

        let related_files = self.related_files_for_context(
            &buffer,
            cursor_position,
            settings.use_context,
            cx,
        );

        let user_prompt = self.build_user_prompt(
            &snapshot,
            cursor_position,
            &related_files,
            max_completion_tokens,
            max_editable_tokens,
            max_context_tokens,
        );

        let request = LanguageModelRequest {
            thread_id: None,
            prompt_id: None,
            intent: Some(CompletionIntent::InlineAssist),
            messages: vec![
                LanguageModelRequestMessage {
                    role: Role::System,
                    content: vec![
                        "You are a code completion engine. Return only the text to insert at the cursor."
                            .into(),
                    ],
                    cache: false,
                    reasoning_details: None,
                },
                LanguageModelRequestMessage {
                    role: Role::User,
                    content: vec![user_prompt.into()],
                    cache: false,
                    reasoning_details: None,
                },
            ],
            tools: Vec::new(),
            tool_choice: None,
            stop: Vec::new(),
            temperature,
            thinking_allowed: false,
        };

        self.pending_request = Some(cx.spawn(async move |this, cx| {
            if debounce {
                cx.background_executor().timer(DEBOUNCE_TIMEOUT).await;
            }

            let completion = match model
                .stream_completion_text(request, cx)
                .await
            {
                Ok(stream) => {
                    let mut output = String::new();
                    let mut stream = stream.stream;
                    while let Some(chunk) = stream.next().await {
                        output.push_str(&chunk?);
                    }
                    output
                }
                Err(err) => {
                    log::error!("LLM edit prediction: completion failed: {}", err);
                    this.update(cx, |this, cx| {
                        this.pending_request = None;
                        cx.notify();
                    })?;
                    return Err(anyhow::anyhow!(err));
                }
            };

            let completion_text = Self::clean_completion(&completion);
            if completion_text.is_empty() {
                this.update(cx, |this, cx| {
                    this.pending_request = None;
                    cx.notify();
                })?;
                return Ok(());
            }

            let edits: Arc<[(Range<Anchor>, Arc<str>)]> =
                vec![(cursor_position..cursor_position, completion_text.into())].into();

            let edit_preview = buffer
                .read_with(cx, |buffer, cx| buffer.preview_edits(edits.clone(), cx))
                .await;

            this.update(cx, |this, cx| {
                this.current_completion = Some(CurrentCompletion {
                    snapshot,
                    edits,
                    edit_preview,
                });
                this.pending_request = None;
                cx.notify();
            })?;

            Ok(())
        }));
    }

    fn accept(&mut self, _cx: &mut Context<Self>) {
        self.pending_request = None;
        self.current_completion = None;
    }

    fn discard(&mut self, _cx: &mut Context<Self>) {
        self.pending_request = None;
        self.current_completion = None;
    }

    fn suggest(
        &mut self,
        buffer: &Entity<Buffer>,
        _cursor_position: Anchor,
        cx: &mut Context<Self>,
    ) -> Option<EditPrediction> {
        let current_completion = self.current_completion.as_ref()?;
        let buffer = buffer.read(cx);
        let edits = current_completion.interpolate(&buffer.snapshot())?;
        if edits.is_empty() {
            return None;
        }
        Some(EditPrediction::Local {
            id: None,
            edits,
            edit_preview: Some(current_completion.edit_preview.clone()),
        })
    }
}

fn extract_code_fence(text: &str) -> Option<&str> {
    let mut fences = text.match_indices("```");
    let (start_ix, _) = fences.next()?;
    let (end_ix, _) = fences.next()?;
    let mut block = &text[start_ix + 3..end_ix];
    if let Some(first_newline) = block.find('\n') {
        let language_hint = &block[..first_newline];
        if !language_hint.trim().is_empty() {
            block = &block[first_newline + 1..];
        }
    }
    Some(block)
}
