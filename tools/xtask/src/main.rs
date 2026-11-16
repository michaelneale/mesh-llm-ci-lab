//! Repository build tooling: the commands the build, packaging and release
//! scripts call. Run it with `cargo xtool <command>`.

mod artifact;
mod attestation;
mod automation;
mod ci_operations;
mod ci_plan;
mod cli;
mod cli_output;
mod command;
#[allow(dead_code)]
mod command_interrupt;
mod native_policy;
mod no_console_print;
mod prepared_input;
mod product;
mod repo_consistency;
mod repository;

use command::DynResult;
// Transitional: call sites still import supervision as `crate::process`.
use process_supervision as process;

#[cfg(test)]
mod tests;

fn main() {
    if let Err(error) = run() {
        eprintln!("error: {error}");
        std::process::exit(1);
    }
}

fn run() -> DynResult<()> {
    let args = std::env::args().skip(1).collect::<Vec<_>>();
    if args == ["--help"] {
        cli::print_usage();
        return Ok(());
    }
    let parsed = cli::Cli::parse(&args)?;
    let explicit_root = parsed
        .root
        .as_deref()
        .map(|path| repository::RepositoryRoot::resolve(Some(path)))
        .transpose()?;
    let resolve_root = || -> DynResult<std::path::PathBuf> {
        let root = match &explicit_root {
            Some(root) => root.as_path().to_path_buf(),
            None => repository::RepositoryRoot::resolve(None)?
                .as_path()
                .to_path_buf(),
        };
        Ok(root)
    };
    match parsed.command {
        cli::CliCommand::UiBuild(rest) => automation::ui_build::run(rest),
        cli::CliCommand::Artifact(command, rest) => artifact::run(command, rest),
        cli::CliCommand::Native(command, rest) => native_policy::run(command, rest, resolve_root),
        cli::CliCommand::Product(command, rest) => product::run(command, rest),
        cli::CliCommand::CargoTargetDirectory(rest) => repository::cargo_target_directory(rest),
        cli::CliCommand::NoConsolePrint(rest) => {
            no_console_print::check_no_console_print_command(&resolve_root()?, rest)
        }
        cli::CliCommand::GenerateKeypair(rest) => {
            attestation::generate_release_attestation_keypair(rest)
        }
        cli::CliCommand::Stamp(rest) => attestation::stamp_release_attestation(
            rest,
            explicit_root
                .as_ref()
                .map(repository::RepositoryRoot::as_path),
        ),
        cli::CliCommand::Inspect(rest) => attestation::inspect_release_attestation(rest),
    }
}
