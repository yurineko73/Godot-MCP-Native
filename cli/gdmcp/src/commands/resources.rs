use serde_json::{json, Value};

use crate::{cli::ResourcesCommand, client::ApiClient, error::CliError};

use super::tool_call::call_with_options;

pub fn run(client: &ApiClient, command: ResourcesCommand) -> Result<Value, CliError> {
    match command {
        ResourcesCommand::List {
            search_path,
            resource_types,
            limit,
            cursor,
        } => {
            let arguments = json!({
                "search_path": search_path,
                "resource_types": resource_types,
            });
            call_with_options(
                client,
                "list_project_resources",
                arguments,
                false,
                false,
                None,
                limit,
                cursor,
                None,
                None,
            )
        }
    }
}
