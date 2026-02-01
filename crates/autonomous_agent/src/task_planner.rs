//! Task Planner - Breaks down user requirements into actionable steps

use anyhow::Result;
use gpui::{Context, Task};
use language_model::LanguageModel;
use serde::{Deserialize, Serialize};
use std::sync::Arc;

/// A single step in a task plan
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskStep {
    /// Human-readable description of this step
    pub description: String,
    /// The type of action to perform
    pub action: StepAction,
    /// Dependencies on other steps (by index)
    pub depends_on: Vec<usize>,
    /// Estimated complexity (1-10)
    pub complexity: u8,
    /// Whether this step can be parallelized with others
    pub parallelizable: bool,
}

/// Types of actions that can be performed
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum StepAction {
    /// Analyze existing code or project structure
    Analyze { target: String },
    /// Create a new file
    CreateFile { path: String, content_hint: String },
    /// Modify an existing file
    ModifyFile { path: String, changes: String },
    /// Delete a file
    DeleteFile { path: String },
    /// Run a terminal command
    RunCommand { command: String, working_dir: Option<String> },
    /// Search for something in the codebase
    Search { query: String, scope: SearchScope },
    /// Read and understand a file
    ReadFile { path: String },
    /// Create a directory
    CreateDirectory { path: String },
    /// Run tests
    RunTests { pattern: Option<String> },
    /// Install dependencies
    InstallDependencies { packages: Vec<String> },
    /// Think/plan (internal reasoning step)
    Think { about: String },
    /// Ask user for clarification
    AskUser { question: String },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SearchScope {
    /// Search entire project
    Project,
    /// Search specific directory
    Directory(String),
    /// Search specific file types
    FileTypes(Vec<String>),
}

/// Plans tasks by breaking them down into steps
pub struct TaskPlanner {
    #[allow(dead_code)]
    model: Arc<dyn LanguageModel>,
}

impl TaskPlanner {
    pub fn new(model: Arc<dyn LanguageModel>) -> Self {
        Self { model }
    }

    /// Plan a task by breaking it into steps
    pub fn plan<E>(&self, task_description: &str, cx: &mut Context<E>) -> Task<Result<Vec<TaskStep>>> {
        let description = task_description.to_string();

        cx.background_executor().spawn(async move {
            // For now, create a simple plan
            // In a full implementation, this would use the LLM to generate a plan
            let steps = Self::create_initial_plan(&description);
            Ok(steps)
        })
    }

    /// Create an initial plan for a task
    fn create_initial_plan(description: &str) -> Vec<TaskStep> {
        // This is a simplified version - the real implementation would use
        // the LLM to generate a proper plan based on the task description
        
        vec![
            TaskStep {
                description: "Analyze the current project structure".to_string(),
                action: StepAction::Analyze {
                    target: ".".to_string(),
                },
                depends_on: vec![],
                complexity: 2,
                parallelizable: false,
            },
            TaskStep {
                description: format!("Plan implementation for: {}", description),
                action: StepAction::Think {
                    about: description.to_string(),
                },
                depends_on: vec![0],
                complexity: 3,
                parallelizable: false,
            },
            TaskStep {
                description: "Implement the solution".to_string(),
                action: StepAction::Think {
                    about: "Implementation details".to_string(),
                },
                depends_on: vec![1],
                complexity: 5,
                parallelizable: false,
            },
            TaskStep {
                description: "Verify the implementation".to_string(),
                action: StepAction::RunTests {
                    pattern: None,
                },
                depends_on: vec![2],
                complexity: 2,
                parallelizable: false,
            },
        ]
    }

    /// Refine a plan based on feedback or errors
    #[allow(dead_code)]
    pub fn refine_plan(
        &self,
        current_steps: &[TaskStep],
        _feedback: &str,
        cx: &mut Context<impl gpui::EventEmitter<crate::AutonomousEvent>>,
    ) -> Task<Result<Vec<TaskStep>>> {
        let steps = current_steps.to_vec();

        cx.background_executor().spawn(async move {
            // In a full implementation, this would use the LLM to refine the plan
            // For now, just return the existing steps
            Ok(steps)
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_initial_plan() {
        let steps = TaskPlanner::create_initial_plan("Create a hello world app");
        assert!(!steps.is_empty());
        assert!(steps[0].depends_on.is_empty());
    }
}
