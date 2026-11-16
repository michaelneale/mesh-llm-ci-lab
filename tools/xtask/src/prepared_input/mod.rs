//! JSON rendering helpers shared by the packaging commands, and the
//! `prepared-input` commands the native SDK packaging scripts call.

pub(crate) mod json_bytes;
pub(crate) mod json_style;
mod sdk_artifact_file;
mod sdk_crate_field;
mod sdk_identity_contract;
mod sdk_manifest;
mod sdk_manifest_writer;
pub(crate) mod text_io;
pub(crate) mod value_format;

use crate::command::DynResult;
use crate::repository::check_report::CheckReport;

const USAGE: &str = "xtask prepared-input {native-sdk-manifest ARTIFACT_DIR MANIFEST | native-sdk-manifest-write MANIFEST ID VERSION TARGET PLATFORM OS ARCH BACKEND FLAVOR PROFILE LIBRARY UNIFFI UPSTREAM PATCHED PATCH_DIGEST | native-sdk-crate-field MANIFEST FIELD}";

/// A rejected input: printed on stderr with status 1.
pub(crate) struct Rejected(pub(crate) String);

pub(crate) type Checked<T> = Result<T, Rejected>;

impl From<String> for Rejected {
    fn from(message: String) -> Self {
        Self(message)
    }
}

impl From<&str> for Rejected {
    fn from(message: &str) -> Self {
        Self(message.to_owned())
    }
}

/// `Ok(stdout)` or a rejection printed on stderr with status 1.
fn report(outcome: Checked<String>) -> CheckReport {
    match outcome {
        Ok(stdout) => CheckReport::success(stdout),
        Err(Rejected(message)) => CheckReport::failure(String::new(), format!("{message}\n")),
    }
}

/// A wrong argument count fails with status 1.
fn positional<'a, const N: usize>(args: &'a [String], names: &str) -> Checked<[&'a str; N]> {
    let values: Vec<&str> = args.iter().map(String::as_str).collect();
    values
        .try_into()
        .map_err(|_| Rejected(format!("expected {N} arguments: {names}")))
}

pub(crate) fn run(args: &[String]) -> DynResult<()> {
    let outcome = match args {
        [command, rest @ ..] if command == "native-sdk-manifest-write" => {
            return sdk_manifest_writer::run(rest);
        }
        [command, rest @ ..] if command == "native-sdk-manifest" => report(sdk_manifest::run(rest)),
        [command, rest @ ..] if command == "native-sdk-crate-field" => {
            report(sdk_crate_field::run(rest))
        }
        _ => CheckReport::usage(USAGE, "unknown prepared-input command"),
    };
    outcome.emit()
}
