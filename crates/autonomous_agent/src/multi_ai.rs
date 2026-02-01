//! Multi-AI Coordinator - Manages multiple AI models working together

use gpui::App;
use language_model::LanguageModelRegistry;
use collections::HashMap;

/// Represents an AI model that can be used
#[derive(Debug, Clone)]
pub struct AiModel {
    pub id: String,
    pub name: String,
    pub provider: AiProvider,
    pub capabilities: ModelCapabilities,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum AiProvider {
    Anthropic,  // Claude
    OpenAI,     // GPT, Codex
    Google,     // Gemini
    Local,      // Ollama, etc.
    Other(String),
}

#[derive(Debug, Clone, Default)]
pub struct ModelCapabilities {
    /// Good at code generation
    pub code_generation: bool,
    /// Good at code review
    pub code_review: bool,
    /// Good at planning
    pub planning: bool,
    /// Good at debugging
    pub debugging: bool,
    /// Supports vision/images
    pub vision: bool,
    /// Maximum context length
    pub max_context: usize,
}

/// Strategy for using multiple AI models
#[derive(Debug, Clone)]
pub enum MultiAiStrategy {
    /// Use a single model for everything
    Single,
    /// Use different models for different tasks
    TaskBased {
        planner: String,
        coder: String,
        reviewer: String,
    },
    /// Run multiple models in parallel and pick best result
    Parallel {
        models: Vec<String>,
        voting: VotingStrategy,
    },
    /// Use one model to verify another's output
    Verification {
        primary: String,
        verifier: String,
    },
}

#[derive(Debug, Clone)]
pub enum VotingStrategy {
    /// Pick the first successful result
    FirstSuccess,
    /// Pick the most common result
    Majority,
    /// Use another model to pick the best
    JudgeModel(String),
}

/// Coordinates multiple AI models
pub struct MultiAiCoordinator {
    available_models: HashMap<String, AiModel>,
    strategy: MultiAiStrategy,
}

impl MultiAiCoordinator {
    pub fn new(cx: &mut App) -> Self {
        let mut coordinator = Self {
            available_models: HashMap::default(),
            strategy: MultiAiStrategy::Single,
        };
        
        coordinator.discover_models(cx);
        coordinator
    }

    /// Discover available AI models
    fn discover_models(&mut self, cx: &mut App) {
        // Get models from the language model registry
        let registry = LanguageModelRegistry::global(cx);
        
        for provider in registry.read(cx).providers() {
            let provider_id = provider.id().to_string();
            let ai_provider = match provider_id.as_str() {
                "anthropic" => AiProvider::Anthropic,
                "openai" | "open_ai" => AiProvider::OpenAI,
                "google" | "google_ai" => AiProvider::Google,
                "ollama" => AiProvider::Local,
                other => AiProvider::Other(other.to_string()),
            };

            for model in provider.provided_models(cx) {
                // Access the inner SharedString via .0
                let model_id = model.id().0.to_string();
                let model_name = model.name().0.to_string();
                
                self.available_models.insert(
                    model_id.clone(),
                    AiModel {
                        id: model_id,
                        name: model_name,
                        provider: ai_provider.clone(),
                        capabilities: Self::infer_capabilities(&ai_provider),
                    },
                );
            }
        }
    }

    /// Infer model capabilities based on provider
    fn infer_capabilities(provider: &AiProvider) -> ModelCapabilities {
        match provider {
            AiProvider::Anthropic => ModelCapabilities {
                code_generation: true,
                code_review: true,
                planning: true,
                debugging: true,
                vision: true,
                max_context: 200000,
            },
            AiProvider::OpenAI => ModelCapabilities {
                code_generation: true,
                code_review: true,
                planning: true,
                debugging: true,
                vision: true,
                max_context: 128000,
            },
            AiProvider::Google => ModelCapabilities {
                code_generation: true,
                code_review: true,
                planning: true,
                debugging: true,
                vision: true,
                max_context: 1000000,
            },
            AiProvider::Local => ModelCapabilities {
                code_generation: true,
                code_review: false,
                planning: false,
                debugging: false,
                vision: false,
                max_context: 8000,
            },
            AiProvider::Other(_) => ModelCapabilities::default(),
        }
    }

    /// Set the multi-AI strategy
    pub fn set_strategy(&mut self, strategy: MultiAiStrategy) {
        self.strategy = strategy;
    }

    /// Get available models
    pub fn available_models(&self) -> Vec<&AiModel> {
        self.available_models.values().collect()
    }

    /// Get models by provider
    pub fn models_by_provider(&self, provider: &AiProvider) -> Vec<&AiModel> {
        self.available_models
            .values()
            .filter(|m| &m.provider == provider)
            .collect()
    }

    /// Select the best model for a task
    pub fn select_model_for_task(&self, task_type: TaskType) -> Option<&AiModel> {
        match &self.strategy {
            MultiAiStrategy::Single => self.available_models.values().next(),
            MultiAiStrategy::TaskBased { planner, coder, reviewer } => {
                let model_id = match task_type {
                    TaskType::Planning => planner,
                    TaskType::Coding => coder,
                    TaskType::Review => reviewer,
                    _ => return self.available_models.values().next(),
                };
                self.available_models.get(model_id)
            }
            MultiAiStrategy::Parallel { models, .. } => {
                models.first().and_then(|id| self.available_models.get(id))
            }
            MultiAiStrategy::Verification { primary, .. } => {
                self.available_models.get(primary)
            }
        }
    }
}

#[derive(Debug, Clone)]
pub enum TaskType {
    Planning,
    Coding,
    Review,
    #[allow(dead_code)]
    Debugging,
    #[allow(dead_code)]
    Documentation,
    #[allow(dead_code)]
    Testing,
    #[allow(dead_code)]
    Other,
}
