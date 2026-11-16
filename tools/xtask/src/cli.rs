use crate::command::DynResult;
use std::path::PathBuf;

const USAGE: &str = "usage:
  cargo xtool artifact <command> ...
  cargo xtool native <command> ...
  cargo xtool product <command> ...
  cargo xtool repository cargo-target-directory < cargo-metadata.json
  cargo xtool repository conventional-commits [--message MESSAGE] [--range RANGE] [file]
  cargo xtool repo-consistency no-console-print
  cargo xtool release-attestation {generate-keypair|stamp|inspect} ...";

pub(crate) fn print_usage() {
    println!("{USAGE}");
}

pub(crate) struct Cli<'a> {
    pub(crate) root: Option<PathBuf>,
    pub(crate) command: CliCommand<'a>,
}

pub(crate) enum CliCommand<'a> {
    Artifact(crate::artifact::ArtifactCommand, &'a [String]),
    Native(crate::native_policy::NativeCommand, &'a [String]),
    Product(crate::product::ProductCommand, &'a [String]),
    CargoTargetDirectory(&'a [String]),
    ConventionalCommits(&'a [String]),
    NoConsolePrint(&'a [String]),
    GenerateKeypair(&'a [String]),
    Stamp(&'a [String]),
    Inspect(&'a [String]),
}

impl<'a> Cli<'a> {
    pub(crate) fn parse(args: &'a [String]) -> DynResult<Self> {
        let (root, command_args) = crate::repository::parse_root_prefix(args)?;
        let command = match command_args {
            [domain, scope, rest @ ..] if domain == "artifact" => {
                match crate::artifact::ArtifactCommand::parse(scope) {
                    Some(command) => CliCommand::Artifact(command, rest),
                    None => return Err(USAGE.into()),
                }
            }
            [domain, scope, rest @ ..] if domain == "native" => {
                match crate::native_policy::NativeCommand::parse(scope) {
                    Some(command) => CliCommand::Native(command, rest),
                    None => return Err(USAGE.into()),
                }
            }
            [domain, scope, rest @ ..] if domain == "product" => {
                match crate::product::ProductCommand::parse(scope) {
                    Some(command) => CliCommand::Product(command, rest),
                    None => return Err(USAGE.into()),
                }
            }
            [domain, scope, rest @ ..]
                if domain == "repository" && scope == "cargo-target-directory" =>
            {
                CliCommand::CargoTargetDirectory(rest)
            }
            [domain, scope, rest @ ..]
                if domain == "repository" && scope == "conventional-commits" =>
            {
                CliCommand::ConventionalCommits(rest)
            }
            [domain, scope, rest @ ..]
                if domain == "repo-consistency" && scope == "no-console-print" =>
            {
                CliCommand::NoConsolePrint(rest)
            }
            [domain, scope, rest @ ..]
                if domain == "release-attestation" && scope == "generate-keypair" =>
            {
                CliCommand::GenerateKeypair(rest)
            }
            [domain, scope, rest @ ..] if domain == "release-attestation" && scope == "stamp" => {
                CliCommand::Stamp(rest)
            }
            [domain, scope, rest @ ..] if domain == "release-attestation" && scope == "inspect" => {
                CliCommand::Inspect(rest)
            }
            _ => return Err(USAGE.into()),
        };
        Ok(Self { root, command })
    }
}
