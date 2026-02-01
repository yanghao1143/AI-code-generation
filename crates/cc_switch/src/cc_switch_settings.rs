//! CC-Switch settings
//!
//! Panel configuration including dock position and default width.

use gpui::Pixels;
use settings::RegisterSetting;
pub use settings::{DockSide, Settings};

#[derive(Debug, Clone, Copy, PartialEq, RegisterSetting)]
pub struct CcSwitchSettings {
    pub button: bool,
    pub default_width: Pixels,
    pub dock: DockSide,
}

impl Default for CcSwitchSettings {
    fn default() -> Self {
        Self {
            button: true,
            default_width: gpui::px(280.0),
            dock: DockSide::Left,
        }
    }
}

impl Settings for CcSwitchSettings {
    fn from_settings(content: &settings::SettingsContent) -> Self {
        let panel = content.cc_switch.as_ref();
        Self {
            button: panel.and_then(|p| p.button).unwrap_or(true),
            default_width: panel
                .and_then(|p| p.default_width)
                .map(gpui::px)
                .unwrap_or(gpui::px(280.0)),
            dock: panel.and_then(|p| p.dock).unwrap_or(DockSide::Left),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_settings() {
        let settings = CcSwitchSettings::default();
        assert!(settings.button);
        assert_eq!(settings.default_width, gpui::px(280.0));
        assert_eq!(settings.dock, DockSide::Left);
    }

    #[test]
    fn test_settings_clone() {
        let settings = CcSwitchSettings {
            button: false,
            default_width: gpui::px(300.0),
            dock: DockSide::Right,
        };
        let cloned = settings.clone();
        assert_eq!(settings.button, cloned.button);
        assert_eq!(settings.default_width, cloned.default_width);
        assert_eq!(settings.dock, cloned.dock);
    }

    #[test]
    fn test_settings_equality() {
        let a = CcSwitchSettings::default();
        let b = CcSwitchSettings::default();
        assert_eq!(a, b);

        let c = CcSwitchSettings {
            button: false,
            ..Default::default()
        };
        assert_ne!(a, c);
    }
}
