# Agent UI Design

## Overview
This document outlines the design for the Autonomous Agent UI panel within the Zed editor. This panel serves as the primary interface for users to interacting with the autonomous programming capabilities.

## Architecture

### Panel Structure (`AgentPanel`)
The panel will follow the standard `Panel` trait pattern used in Zed.

- **Location:** Dockable (default Right).
- **Key Binding:** `cmd-alt-a` (suggested).

### Components

#### 1. Header
- **Title:** "Autonomous Agent"
- **Actions:**
    - Settings (icon) -> Opens Agent Configuration.
    - History (icon) -> Shows past tasks.

#### 2. Task Input Area (`TaskInputView`)
- **Input Field:** Multi-line text editor for describing the programming task.
- **Attachments:** Ability to context (files, symbols) similar to the assistant panel.
- **Submit Button:** "Start Task" (Primary action).

#### 3. Execution Control (`ExecutionControlView`)
- **Status Display:** Current state (Idle, Thinking, Executing, Paused, Error).
- **Controls:**
    - **Pause/Resume:** Toggle button.
    - **Stop:** Destructive action to cancel the current task.
    - **Step:** (Debug mode) Allow single-step execution.

#### 4. Progress Visualization (`ProgressView`)
- **Step List:** A scrolling list of high-level steps the agent has planned or executed.
    - *Pending:* Greyed out.
    - *Active:* Spinner/Highlight.
    - *Completed:* Green checkmark.
    - *Failed:* Red cross.
- **Detailed Log (Collapsible):** Terminal-like output for tool usage and raw LLM thoughts.

## State Management (`AgentStore` / `AgentModel`)
- The UI will reflect the state of the underlying `AutonomousAgent` logic (likely living in `crates/autonomous_agent` or similar).
- **Observability:** The UI views will observe the `AgentModel` for updates.

## Integration
- **Workspace:** Registered as a workspace panel.
- **Theming:** Uses Zed's standard theme system (`cx.theme()`).

## Mockup Layout
```
+--------------------------------------------------+
| Autonomous Agent                            [⚙️] |
+--------------------------------------------------+
| [ Input Task...                                ] |
| [                                              ] |
| ( START )                                        |
+--------------------------------------------------+
| Status: EXECUTING             ( || Pause ) ( X ) |
+--------------------------------------------------+
| Steps:                                           |
|  [✓] 1. Analyze codebase                         |
|  [⟳] 2. Modify `lib.rs`                          |
|      > Reading file...                           |
|  [ ] 3. Run tests                                |
+--------------------------------------------------+
| Logs:                                            |
| [INFO] Agent started...                          |
+--------------------------------------------------+
```
