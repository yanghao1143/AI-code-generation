use std::sync::Arc;
use anyhow::Result;
use gpui::{App, AsyncApp, Task};
use language_model::{LanguageModel, LanguageModelRegistry};
use crate::agent::{Agent, AgentRole};

pub struct Dispatcher {
    agents: Vec<Agent>,
}

impl Dispatcher {
    pub fn new() -> Self {
        Self { agents: Vec::new() }
    }

    pub fn dispatch(&mut self, task: String, cx: &mut App) -> Task<Result<String>> {
        let registry = LanguageModelRegistry::read_global(cx);
        let model: Arc<dyn LanguageModel> = if let Some(configured_model) = registry.default_model() {
             configured_model.model.clone()
        } else {
            return Task::ready(Err(anyhow::anyhow!("No default model configured")));
        };

        let architect = Agent::new("architect".to_string(), AgentRole::Architect, model.clone());
        let coder = Agent::new("coder".to_string(), AgentRole::Coder, model.clone());
        let reviewer = Agent::new("reviewer".to_string(), AgentRole::Reviewer, model.clone());
        
        cx.spawn(|cx: &mut AsyncApp| {
            let cx = cx.clone();
            async move {
                // Step 1: Architect
                let plan = architect.execute(task, &cx).await?;
                
                // Step 2: Coder
                let code = coder.execute(plan.clone(), &cx).await?;
                
                // Step 3: Reviewer
                let review = reviewer.execute(code.clone(), &cx).await?;

                let result = format!(
                    "## Architect Plan\n{}\n\n## Implementation\n{}\n\n## Review\n{}",
                    plan, code, review
                );
                Ok(result)
            }
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_dispatcher_construction() {
        let dispatcher = Dispatcher::new();
        assert!(dispatcher.agents.is_empty());
    }
}
