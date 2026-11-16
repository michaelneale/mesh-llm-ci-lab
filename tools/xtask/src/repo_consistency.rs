use crate::command::{DynResult, run_command, trimmed_stderr_or_stdout};
use serde::Deserialize;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

pub(crate) fn default_node_version(repo_root: &Path) -> DynResult<String> {
    host_runtime_package_version(repo_root)
}

pub(crate) fn host_runtime_package_version(repo_root: &Path) -> DynResult<String> {
    let runtime_manifest = repo_root
        .join("mesh/crates")
        .join("mesh-llm-host-runtime")
        .join("Cargo.toml");
    let runtime_contents = fs::read_to_string(runtime_manifest)?;
    if let Some(version) = extract_manifest_string(&runtime_contents, "version")? {
        return Ok(version);
    }
    if has_manifest_bool(&runtime_contents, "version.workspace", true) {
        let workspace_manifest = repo_root.join("Cargo.toml");
        let workspace_contents = fs::read_to_string(workspace_manifest)?;
        return extract_manifest_string(&workspace_contents, "version")?
            .ok_or_else(|| "missing workspace package version".into());
    }
    Err("missing mesh-llm-host-runtime package version".into())
}

fn extract_manifest_string(contents: &str, key: &str) -> DynResult<Option<String>> {
    let prefix = format!("{key} = \"");
    for line in contents.lines().map(str::trim) {
        if let Some(rest) = line.strip_prefix(&prefix) {
            return Ok(Some(
                rest.strip_suffix('"')
                    .ok_or_else(|| format!("malformed manifest {key} value"))?
                    .to_string(),
            ));
        }
    }
    Ok(None)
}

fn has_manifest_bool(contents: &str, key: &str, expected: bool) -> bool {
    let expected_value = if expected { "true" } else { "false" };
    let expected_line = format!("{key} = {expected_value}");
    contents
        .lines()
        .map(str::trim)
        .any(|line| line == expected_line)
}

#[derive(Debug, Deserialize)]
pub(crate) struct CargoMetadata {
    pub(crate) packages: Vec<CargoPackage>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct CargoPackage {
    pub(crate) name: String,
    pub(crate) manifest_path: PathBuf,
    #[serde(default)]
    pub(crate) dependencies: Vec<CargoDependency>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct CargoDependency {
    pub(crate) name: String,
    pub(crate) kind: Option<String>,
}

pub(crate) fn workspace_metadata(repo_root: &Path, context: &str) -> DynResult<CargoMetadata> {
    let mut cargo = Command::new("cargo");
    cargo
        .current_dir(repo_root)
        .arg("metadata")
        .arg("--format-version=1")
        .arg("--no-deps");
    let output = run_command(&mut cargo)?;
    if !output.status.success() {
        return Err(format!(
            "cargo metadata failed while checking {context}: {}",
            trimmed_stderr_or_stdout(&output)
        )
        .into());
    }
    Ok(serde_json::from_slice(&output.stdout)?)
}
