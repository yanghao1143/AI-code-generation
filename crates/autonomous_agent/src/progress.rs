//! Progress Tracker - Monitors and reports task progress

use crate::AutonomousEvent;
use std::sync::Arc;
use parking_lot::RwLock;

/// Tracks progress of autonomous task execution
pub struct ProgressTracker {
    listeners: Arc<RwLock<Vec<Box<dyn Fn(AutonomousEvent) + Send + Sync>>>>,
    history: Arc<RwLock<Vec<AutonomousEvent>>>,
}

impl ProgressTracker {
    pub fn new() -> Self {
        Self {
            listeners: Arc::new(RwLock::new(Vec::new())),
            history: Arc::new(RwLock::new(Vec::new())),
        }
    }

    /// Emit a progress event
    pub fn emit(&self, event: AutonomousEvent) {
        // Store in history
        self.history.write().push(event.clone());

        // Notify listeners
        let listeners = self.listeners.read();
        for listener in listeners.iter() {
            listener(event.clone());
        }
    }

    /// Subscribe to progress events
    pub fn subscribe<F>(&self, callback: F)
    where
        F: Fn(AutonomousEvent) + Send + Sync + 'static,
    {
        self.listeners.write().push(Box::new(callback));
    }

    /// Get all events in history
    pub fn get_history(&self) -> Vec<AutonomousEvent> {
        self.history.read().clone()
    }

    /// Clear history
    pub fn clear_history(&self) {
        self.history.write().clear();
    }

    /// Get the last N events
    pub fn get_recent(&self, count: usize) -> Vec<AutonomousEvent> {
        let history = self.history.read();
        let start = history.len().saturating_sub(count);
        history[start..].to_vec()
    }
}

impl Default for ProgressTracker {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_progress_tracker() {
        let tracker = ProgressTracker::new();
        
        tracker.emit(AutonomousEvent::Progress {
            percent: 50.0,
            message: "Halfway there".to_string(),
        });

        let history = tracker.get_history();
        assert_eq!(history.len(), 1);
    }
}
