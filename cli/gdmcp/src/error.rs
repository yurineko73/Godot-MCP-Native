use thiserror::Error;

#[derive(Debug, Error)]
pub enum CliError {
    #[error("invalid arguments: {0}")]
    InvalidArguments(String),
    #[error("configuration error: {0}")]
    Configuration(String),
    #[error("Godot service is unreachable: {0}")]
    Unreachable(String),
    #[error("API request failed: {0}")]
    Api(String),
    #[error("operation requires explicit permission: {0}")]
    Permission(String),
    #[error("API version mismatch: {0}")]
    VersionMismatch(String),
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),
}

impl CliError {
    pub fn exit_code(&self) -> i32 {
        match self {
            Self::InvalidArguments(_) => 2,
            Self::Configuration(_) => 3,
            Self::Unreachable(_) => 4,
            Self::Api(_) => 5,
            Self::Permission(_) => 6,
            Self::VersionMismatch(_) => 8,
            Self::Io(_) | Self::Json(_) | Self::Http(_) => 5,
        }
    }
}
