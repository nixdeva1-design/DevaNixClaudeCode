use serde::{Deserialize, Serialize};

/// CuiperSignaal — een bericht op de Zenoh bus
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CuiperSignaal {
    pub key:       String,
    pub payload:   serde_json::Value,
    pub timestamp: u64,
    pub afzender:  String,
}

impl CuiperSignaal {
    pub fn nieuw(key: impl Into<String>, payload: serde_json::Value, afzender: impl Into<String>) -> Self {
        Self {
            key:       key.into(),
            payload,
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_secs())
                .unwrap_or(0),
            afzender:  afzender.into(),
        }
    }
}
