use std::{env, fs, path::PathBuf, time::Duration};

use directories::ProjectDirs;
use serde::Deserialize;

use crate::{cli::Cli, error::CliError};

#[derive(Debug, Clone)]
pub struct Config {
    pub base_url: String,
    pub token: Option<String>,
    pub timeout: Duration,
}

#[derive(Debug, Default, Deserialize)]
struct FileConfig {
    url: Option<String>,
    timeout_seconds: Option<u64>,
    token_env: Option<String>,
}

impl Config {
    pub fn load(cli: &Cli) -> Result<Self, CliError> {
        let file = load_file_config()?;
        let base_url = cli
            .url
            .clone()
            .or_else(|| env::var("GODOT_MCP_URL").ok())
            .or(file.url)
            .unwrap_or_else(|| "http://127.0.0.1:9080".to_string())
            .trim_end_matches('/')
            .to_string();
        if !base_url.starts_with("http://") && !base_url.starts_with("https://") {
            return Err(CliError::Configuration(
                "URL must start with http:// or https://".to_string(),
            ));
        }
        let token_env = cli
            .token_env
            .clone()
            .or(file.token_env)
            .unwrap_or_else(|| "GODOT_MCP_TOKEN".to_string());
        let token = env::var(token_env).ok().filter(|value| !value.is_empty());
        let timeout_seconds = cli
            .timeout
            .or_else(|| {
                env::var("GODOT_MCP_TIMEOUT")
                    .ok()
                    .and_then(|value| value.parse().ok())
            })
            .or(file.timeout_seconds)
            .unwrap_or(30);
        Ok(Self {
            base_url,
            token,
            timeout: Duration::from_secs(timeout_seconds.clamp(1, 300)),
        })
    }
}

fn load_file_config() -> Result<FileConfig, CliError> {
    let Some(project_dirs) = ProjectDirs::from("dev", "GodotMCP", "gdmcp") else {
        return Ok(FileConfig::default());
    };
    let path: PathBuf = project_dirs.config_dir().join("config.toml");
    if !path.exists() {
        return Ok(FileConfig::default());
    }
    let content = fs::read_to_string(path)?;
    toml::from_str(&content).map_err(|error| CliError::Configuration(error.to_string()))
}
