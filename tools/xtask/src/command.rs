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

pub fn trimmed_stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).trim().to_string()
}

pub fn trimmed_stderr_or_stdout(output: &Output) -> String {
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    if !stderr.is_empty() {
        stderr
    } else {
        trimmed_stdout(output)
    }
}

#[cfg(test)]
pub fn unique_temp_dir(prefix: &str) -> std::path::PathBuf {
    use std::sync::atomic::{AtomicU64, Ordering};
    use std::time::{SystemTime, UNIX_EPOCH};
    static SEQUENCE: AtomicU64 = AtomicU64::new(0);
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_nanos())
        .unwrap_or_default();
    let sequence = SEQUENCE.fetch_add(1, Ordering::Relaxed);
    std::env::temp_dir().join(format!(
        ".tmp-{prefix}-{}-{sequence}-{nanos}",
        std::process::id()
    ))
}
