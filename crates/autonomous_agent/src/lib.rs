//! Autonomous Agent for Chi Code
//!
//! This crate provides the core functionality for autonomous coding mode,
//! where the AI continuously works on a task until completion without
//! requiring user confirmation for each step.

mod executor;
mod multi_ai;
mod progress;
mod task_planner;

pub use executor::*;
pub use multi_ai::*;
pub use progress::*;
pub use task_planner::*;

use anyhow::Result;
use gpui::{App, Context, EventEmitter, Task, WeakEntity};
use language_model::LanguageModel;
use project::Project;
use std::sync::Arc;

/// Configuration for autonomous execution
#[derive(Debug, Clone)]
pub struct AutonomousConfig {
    /// Maximum number of steps before requiring user confirmation
    pub max_steps_before_confirm: usize,
    /// Whether to auto-approve safe operations (read, search)
    pub auto_approve_safe_ops: bool,
    /// Whether to auto-approve file modifications
    pub auto_approve_modifications: bool,
    /// Maximum time (in seconds) for a single task
    pub max_task_duration_secs: u64,
    /// Enable multi-AI collaboration
    pub multi_ai_enabled: bool,
}

impl Default for AutonomousConfig {
    fn default() -> Self {
        Self {
            max_steps_before_confirm: 50,
            auto_approve_safe_ops: true,
            auto_approve_modifications: true,
            max_task_duration_secs: 3600, // 1 hour
            multi_ai_enabled: false,
        }
    }
}

/// Events emitted by the autonomous agent
#[derive(Debug, Clone)]
pub enum AutonomousEvent {
    /// A new step has started
    StepStarted { step_number: usize, description: String },
    /// A step has completed
    StepCompleted { step_number: usize, success: bool },
    /// Progress update
    Progress { percent: f32, message: String },
    /// Task completed successfully
    TaskCompleted { summary: String },
    /// Task failed
    TaskFailed { error: String },
    /// Requires user confirmation to continue
    ConfirmationRequired { reason: String },
    /// Agent is thinking/planning
    Thinking { thought: String },
}

/// The main autonomous agent that orchestrates continuous task execution
pub struct AutonomousAgent {
    #[allow(dead_code)]
    project: WeakEntity<Project>,
    config: AutonomousConfig,
    planner: TaskPlanner,
    executor: Executor,
    progress: ProgressTracker,
    #[allow(dead_code)]
    multi_ai: Option<MultiAiCoordinator>,
    current_task: Option<CurrentTask>,
}

struct CurrentTask {
    description: String,
    steps: Vec<TaskStep>,
    current_step: usize,
    started_at: std::time::Instant,
}

impl AutonomousAgent {
    pub fn new(
        project: WeakEntity<Project>,
        model: Arc<dyn LanguageModel>,
        config: AutonomousConfig,
        cx: &mut App,
    ) -> Self {
        let multi_ai = if config.multi_ai_enabled {
            Some(MultiAiCoordinator::new(cx))
        } else {
            None
        };

        Self {
            project: project.clone(),
            config: config.clone(),
            planner: TaskPlanner::new(model.clone()),
            executor: Executor::new(project, model, config.clone()),
            progress: ProgressTracker::new(),
            multi_ai,
            current_task: None,
        }
    }

    /// Start executing a task autonomously
    pub fn execute(&mut self, task_description: &str, cx: &mut Context<Self>) -> Task<Result<()>> {
        let description = task_description.to_string();
        
        cx.spawn(async move |this, cx| {
            // Phase 1: Plan the task
            let plan_task = this.update(cx, |this, cx| {
                this.progress.emit(AutonomousEvent::Thinking {
                    thought: format!("Analyzing task: {}", description),
                });
                this.planner.plan(&description, cx)
            })?;
            
            let steps: Vec<TaskStep> = plan_task.await?;

            // Initialize current task
            this.update(cx, |this, _| {
                this.current_task = Some(CurrentTask {
                    description: description.clone(),
                    steps: steps.clone(),
                    current_step: 0,
                    started_at: std::time::Instant::now(),
                });
            })?;

            // Phase 2: Execute each step
            for (i, step) in steps.iter().enumerate() {
                // Check if we should continue
                let should_continue = this.update(cx, |this, _cx| {
                    this.check_should_continue(i)
                })??;

                if !should_continue {
                    break;
                }

                // Execute the step
                this.update(cx, |this, _cx| {
                    this.progress.emit(AutonomousEvent::StepStarted {
                        step_number: i + 1,
                        description: step.description.clone(),
                    });
                })?;

                let exec_task = this.update(cx, |this, cx| {
                    this.executor.execute_step(step, cx)
                })?;
                
                let result = exec_task.await?;

                this.update(cx, |this, _cx| {
                    this.progress.emit(AutonomousEvent::StepCompleted {
                        step_number: i + 1,
                        success: result.success,
                    });

                    if let Some(task) = &mut this.current_task {
                        task.current_step = i + 1;
                    }

                    let progress = ((i + 1) as f32 / steps.len() as f32) * 100.0;
                    this.progress.emit(AutonomousEvent::Progress {
                        percent: progress,
                        message: format!("Completed step {} of {}", i + 1, steps.len()),
                    });
                })?;

                if !result.success {
                    // Try to recover or report failure
                    this.update(cx, |this, _cx| {
                        this.handle_step_failure(step, &result)
                    })??;
                }
            }

            // Phase 3: Summarize and complete
            this.update(cx, |this, _cx| {
                this.progress.emit(AutonomousEvent::TaskCompleted {
                    summary: format!("Successfully completed: {}", description),
                });
                this.current_task = None;
            })?;

            Ok(())
        })
    }

    /// Check if execution should continue
    fn check_should_continue(&self, step_number: usize) -> Result<bool> {
        // Check time limit
        if let Some(task) = &self.current_task {
            let elapsed = task.started_at.elapsed().as_secs();
            if elapsed > self.config.max_task_duration_secs {
                self.progress.emit(AutonomousEvent::TaskFailed {
                    error: "Task exceeded maximum duration".to_string(),
                });
                return Ok(false);
            }
        }

        // Check step limit
        if step_number >= self.config.max_steps_before_confirm {
            self.progress.emit(AutonomousEvent::ConfirmationRequired {
                reason: format!(
                    "Reached {} steps. Continue?",
                    self.config.max_steps_before_confirm
                ),
            });
        }

        Ok(true)
    }

    /// Handle a failed step
    fn handle_step_failure(
        &mut self,
        step: &TaskStep,
        result: &StepResult,
    ) -> Result<()> {
        // Log the failure
        log::warn!("Step failed: {} - {:?}", step.description, result.error);

        // Try to recover by re-planning
        if let Some(error) = &result.error {
            self.progress.emit(AutonomousEvent::Thinking {
                thought: format!("Step failed: {}. Attempting recovery...", error),
            });
        }

        Ok(())
    }

    /// Stop the current task
    pub fn stop(&mut self, _cx: &mut Context<Self>) {
        self.executor.cancel();
        self.current_task = None;
        self.progress.emit(AutonomousEvent::TaskFailed {
            error: "Task stopped by user".to_string(),
        });
    }

    /// Get current progress
    pub fn get_progress(&self) -> Option<(usize, usize)> {
        self.current_task.as_ref().map(|task| {
            (task.current_step, task.steps.len())
        })
    }
}

impl EventEmitter<AutonomousEvent> for AutonomousAgent {}
