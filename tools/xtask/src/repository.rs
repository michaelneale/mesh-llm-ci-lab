mod cargo_projection;
pub(crate) mod check_report;
pub(crate) mod text;

use crate::command::DynResult;

/// Prints the Cargo target directory from `cargo metadata` JSON on stdin.
pub(crate) fn cargo_target_directory(args: &[String]) -> DynResult<()> {
    cargo_projection::run(args)
}

pub(crate) use ci_controller::repository::RepositoryRoot;
