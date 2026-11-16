use crate::ci_plan::document::Json;

pub fn repr(value: Option<&Json>) -> String {
    value.map_or_else(
        || "missing".to_owned(),
        |value| value.to_value().to_string(),
    )
}

pub fn display(value: Option<&Json>) -> String {
    match value {
        Some(Json::String(text)) => text.clone(),
        other => repr(other),
    }
}
