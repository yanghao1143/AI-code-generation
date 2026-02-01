use gpui::{App, Pixels};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use settings::Settings;

#[derive(Default, Copy, Clone, PartialEq)]
pub struct MultiModelDispatchSettings {
    pub default_width: Pixels,
    pub dock: DockSide,
    pub button: bool,
}

#[derive(Copy, Clone, Debug, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum DockSide {
    Left,
    Right,
}

impl Default for DockSide {
    fn default() -> Self {
        Self::Right
    }
}

impl Settings for MultiModelDispatchSettings {
    fn from_settings(_content: &settings::SettingsContent) -> Self {
        // For now, return default as we haven't added this to the main SettingsContent struct
        // In a real implementation, we would either add it to SettingsContent 
        // or use a mechanism to store/retrieve it from there if it supports dynamic extensions.
        // Given the constraints, we will stick to defaults for this prototype or 
        // assume it might be serialized in a custom way if needed, 
        // but to satisfy the trait we must implement this.
        Self::default()
    }
}

