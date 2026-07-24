use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecuteRequest {
    pub arguments: Value,
    #[serde(default)]
    pub dry_run: bool,
    #[serde(default)]
    pub apply_confirmed: bool,
    #[serde(default)]
    pub allow_open_world: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fields: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub limit: Option<usize>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cursor: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub depth: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_bytes: Option<usize>,
}

#[derive(Debug, Deserialize)]
pub struct ApiErrorBody {
    pub code: String,
    pub message: String,
}
