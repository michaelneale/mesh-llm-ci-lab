---
name: manage-ci
description: Use this skill before inspecting, running, debugging, editing, reviewing, or documenting MeshLLM CI or the release workflow.
---

# Manage CI

CI is two workflows on GitHub's own runners. `ci/ci.md` describes every job;
read it first and update it in the same change.

- `.github/workflows/ci.yml`: pull requests and main.
- `.github/workflows/binaries.yml`: release archives and the GitHub release.

## Rules

- Every job runs a command a contributor can run locally: a `just` recipe or a
  script in `ci/simple/`. Put logic there, not in workflow YAML.
- No self-hosted runners, no planner, and no workflow that must be read from
  main. A pull request runs its own copy of the workflow.
- `CI` is the one required check. It passes when every job that ran passed.
- `ci/simple/changes.sh` decides from the changed paths which jobs a pull
  request needs. Documentation-only changes skip the code jobs.
- Only main saves caches; pull requests read them. The whole set must fit in
  GitHub's 10 GB per repository.
- Pin third-party actions to a commit SHA and check downloads against a SHA-256.
- `tools/xtask` holds only what the build, CI and release call. Do not grow it
  for CI orchestration, and do not add Python tooling.

## Debugging a failure

Confirm the run belongs to the current head commit, read the failing job's log,
and run the same command locally.
