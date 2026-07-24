use serde_json::{json, Value};

use crate::{cli::ProjectCommand, client::ApiClient, error::CliError};

use super::tool_call::call;

pub fn run(client: &ApiClient, command: ProjectCommand) -> Result<Value, CliError> {
    match command {
        ProjectCommand::Info => call(
            client,
            "get_project_info",
            json!({}),
            false,
            false,
            None,
            None,
            None,
        ),
        ProjectCommand::Settings { filter } => {
            let filter = filter.ok_or_else(|| {
                CliError::InvalidArguments(
                    "project settings requires --filter <prefix> because the full settings set can be large".to_string(),
                )
            })?;
            if filter.trim().is_empty() {
                return Err(CliError::InvalidArguments(
                    "project settings requires a non-empty --filter <prefix>".to_string(),
                ));
            }
            let filter = filter.trim().to_string();
            call(
                client,
                "get_project_settings",
                json!({"filter": filter}),
                false,
                false,
                None,
                None,
                None,
            )
        }
        ProjectCommand::Run => call(
            client,
            "run_project",
            json!({}),
            false,
            false,
            None,
            None,
            None,
        ),
        ProjectCommand::Stop => call(
            client,
            "stop_project",
            json!({}),
            false,
            false,
            None,
            None,
            None,
        ),
    }
}
