use serde_json::{json, Value};
use crate::{cli::ResourcesCommand, client::ApiClient, error::CliError};
use super::tool_call::call;
pub fn run(client: &ApiClient, command: ResourcesCommand) -> Result<Value, CliError> {
    match command {
        ResourcesCommand::List { resource_type, limit } => {
            let mut arguments=json!({});
            if let Some(resource_type)=resource_type { arguments["type_filter"]=Value::String(resource_type); }
            call(client,"list_project_resources",arguments,false,false,None,limit,None)
        }
    }
}
