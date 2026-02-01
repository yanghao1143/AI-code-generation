use std::sync::Arc;
use anyhow::{Result, anyhow};
use gpui::AsyncApp;
use language_model::{LanguageModel, LanguageModelRequest, LanguageModelCompletionEvent, Role, MessageContent};
use futures::StreamExt;

#[derive(Clone, Debug, PartialEq)]
pub enum AgentRole {
    Architect,
    Coder,
    Reviewer,
}

pub struct Agent {
    id: String,
    role: AgentRole,
    model: Arc<dyn LanguageModel>,
}

impl Agent {
    pub fn new(id: String, role: AgentRole, model: Arc<dyn LanguageModel>) -> Self {
        Self { id, role, model }
    }

    pub fn id(&self) -> &str {
        &self.id
    }

    pub fn role(&self) -> &AgentRole {
        &self.role
    }

    pub fn model(&self) -> &Arc<dyn LanguageModel> {
        &self.model
    }

    pub async fn execute(&self, task: String, cx: &AsyncApp) -> Result<String> {
        let model = self.model.clone();
        let role = self.role.clone();
        
        let prompt = match role {
            AgentRole::Architect => format!("You are a Software Architect. Plan the following task:\n{}", task),
            AgentRole::Coder => format!("You are a Senior Developer. Implement the following task based on the plan:\n{}", task),
            AgentRole::Reviewer => format!("You are a Code Reviewer. Review the following code/task:\n{}", task),
        };

        let request = LanguageModelRequest {
            messages: vec![language_model::LanguageModelRequestMessage {
                content: vec![MessageContent::Text(prompt)],
                role: Role::User,
                cache: false,
                reasoning_details: None,
            }],
            ..Default::default()
        };

        let stream = model.stream_completion(request, cx).await?;
        let mut stream = stream.fuse();
        let mut response = String::new();

        while let Some(event) = stream.next().await {
            match event {
                Ok(LanguageModelCompletionEvent::Text(text)) => {
                    response.push_str(&text);
                }
                Err(e) => return Err(anyhow!(e)),
                _ => {}
            }
        }

        Ok(response)
    }
}
