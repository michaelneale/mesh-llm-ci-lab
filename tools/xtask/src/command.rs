pub(crate) use ci_controller::child_output::trimmed_stderr_or_stdout;
#[cfg(test)]
pub(crate) use ci_controller::temp_dir::unique_temp_dir;
use std::error::Error;
use std::fs;
use std::path::Path;
use std::process::{Command, Output};

pub(crate) type DynError = Box<dyn Error>;
pub(crate) type DynResult<T> = Result<T, DynError>;

pub(crate) fn write_json_file<T: serde::Serialize>(path: &Path, value: &T) -> DynResult<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, serde_json::to_vec_pretty(value)?)?;
    Ok(())
}

pub(crate) fn print_json<T: serde::Serialize>(value: &T) -> DynResult<()> {
    println!("{}", serde_json::to_string_pretty(value)?);
    Ok(())
}

pub(crate) fn run_command(command: &mut Command) -> DynResult<Output> {
    Ok(command.output()?)
}

pub(crate) fn ensure_eq(expected: &str, actual: &str, context: &str) -> DynResult<()> {
    if expected == actual {
        Ok(())
    } else {
        Err(format!("{context}: expected `{expected}`, got `{actual}`").into())
    }
}
