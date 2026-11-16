mod cargo_projection;
pub(crate) mod check_args;
pub(crate) mod check_report;
pub(crate) mod conventional_commit;
pub(crate) mod text;

use crate::command::DynResult;
use std::path::{Path, PathBuf};

/// Prints the Cargo target directory from `cargo metadata` JSON on stdin.
pub(crate) fn cargo_target_directory(args: &[String]) -> DynResult<()> {
    cargo_projection::run(args)
}

/// Separates xtask's optional leading repository root from its command tail.
pub fn parse_root_prefix(args: &[String]) -> DynResult<(Option<PathBuf>, &[String])> {
    match args {
        [flag, value, rest @ ..] if flag == "--repo-root" => {
            if value.starts_with("--") {
                return Err("missing value for --repo-root".into());
            }
            Ok((Some(Path::new(value).to_path_buf()), rest))
        }
        [flag, ..] if flag == "--repo-root" => Err("missing value for --repo-root".into()),
        _ => Ok((None, args)),
    }
}

#[derive(Debug, Clone)]
pub struct RepositoryRoot(PathBuf);

impl RepositoryRoot {
    pub fn resolve(explicit: Option<&Path>) -> DynResult<Self> {
        let start = match explicit {
            Some(path) => path
                .canonicalize()
                .map_err(|error| format!("invalid repo root {}: {error}", path.display()))?,
            None => std::env::current_dir()?,
        };
        let root = match explicit {
            Some(_) => Some(start.as_path()),
            None => start.ancestors().find(|path| Self::has_markers(path)),
        }
        .ok_or_else(|| format!("could not find repo root from {}", start.display()))?;
        if !Self::has_markers(root) {
            return Err(format!(
                "invalid repo root {}: missing workspace markers",
                root.display()
            )
            .into());
        }
        Ok(Self(root.to_path_buf()))
    }

    fn has_markers(path: &Path) -> bool {
        path.join("Cargo.toml").is_file() && path.join("tools/xtask/Cargo.toml").is_file()
    }

    pub fn as_path(&self) -> &Path {
        &self.0
    }
}
