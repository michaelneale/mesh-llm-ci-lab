# GitHub CI agent entry point

Read `ci/ci.md` before changing anything under `.github/`. It describes both
workflows and every job.

- `workflows/ci.yml` runs on pull requests and on main. `workflows/binaries.yml`
  builds and publishes a release.
- Every job runs a command a contributor can run locally: a `just` recipe or a
  script in `ci/simple/`. Put logic there, not in workflow YAML.
- GitHub's own runners only. No self-hosted runners, no planner, and no
  workflow that must be read from main: a pull request runs its own copy.
- `CI` is the one required check. Keep it passing when every job that ran passed.
- Only main saves caches, and the whole set must fit in GitHub's 10 GB.
- Update `ci/ci.md` in the same change.
