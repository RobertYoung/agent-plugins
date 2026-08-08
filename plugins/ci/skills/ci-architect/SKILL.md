---
name: ci-architect
description: Standards for CI/CD and release automation. Use when setting up or reviewing GitHub Actions workflows, adding release automation to a repository, auditing a repo for semver releases and conventional commits, configuring Dependabot, or troubleshooting workflow failures.
---

# CI architect

Every repository releases automatically. A repository without a release workflow is an incomplete repository, and fixing that is the first thing to raise when auditing one.

## The baseline every repository must meet

1. **A release workflow** on push to the default branch that cuts a tag and a GitHub release with generated notes.
2. **Semantic versioning**, derived from commit history, never hand-edited.
3. **Conventional commits**, enforced in CI so the version derivation is trustworthy.
4. **A CI workflow** that lints and tests on pull requests.
5. **Dependabot enabled**, covering `github-actions` and every package ecosystem present in the repository.

When you are asked to work on a repository's CI and any of these is missing, say so and offer to add it. Do not add it silently to a repo whose scope was something else.

## Auditing a repository

Check in this order and report what is missing:

```sh
ls .github/workflows/
test -f .releaserc.json || test -f .releaserc.yml || test -f release-please-config.json
cat .github/dependabot.yml
git log --oneline -30
gh api "repos/{owner}/{repo}/vulnerability-alerts" --silent && echo "dependabot alerts on"
gh api "repos/{owner}/{repo}/automated-security-fixes" --jq '.enabled'
```

- No release workflow: the top finding.
- No `.github/dependabot.yml`, or one that misses an ecosystem the repo actually uses: dependency updates are not happening. Detect the ecosystems from the lockfiles present (`package-lock.json`, `poetry.lock`, `go.sum`, `Gemfile.lock`, `requirements.txt`, `Dockerfile`, `.terraform.lock.hcl`) and check each has an `updates` entry, plus `github-actions`.
- Dependabot alerts or security updates disabled at the repository level: the config file only controls version updates, so both settings need checking too.
- Release workflow present but tags are hand-cut, or versions are written into files by hand: the version source of truth is wrong.
- Recent commit subjects that are not conventional (`update stuff`, `fixes`, `wip`): commit linting is missing or not enforced.
- Actions referenced by tag (`@v4`) rather than commit SHA: supply chain finding.
- No `permissions` block: defaults to overly broad token scope.

## Release automation

Default to `semantic-release` driven by conventional commits. Templates to copy are in this skill's `references/` directory:

- `references/release-workflow.yml` → `.github/workflows/release.yml`
- `references/releaserc.json` → `.releaserc.json` (set `repositoryUrl`)
- `references/dependabot.yml` → `.github/dependabot.yml` (drop the ecosystems that do not apply)

The shape of that workflow, and the reasons it is shaped that way:

- Triggers on `push` to `main` plus `workflow_dispatch` for a manual re-run.
- `permissions: contents: read` at workflow level; the release job widens to `contents: write`, `issues: write`, `pull-requests: write` and nothing else.
- `actions/checkout` with `fetch-depth: 0`, because semantic-release reads the whole history to determine the next version.
- Every action pinned to a full commit SHA with the version in a trailing comment.
- `step-security/harden-runner` first, `egress-policy: audit` until the egress list has been reviewed, then `block`.

For repositories that must carry a version inside a file (a plugin manifest, `package.json`, a chart), add `@semantic-release/exec` to write the version during `prepare` and `@semantic-release/git` to commit it back, and list both in the workflow's `extra_plugins`. Anything that can derive its version from the git tag should do that instead of committing a version.

`release-please` is the alternative when the project wants a release PR to accumulate changes before publishing. Pick one per repository, never both.

## Semantic versioning rules

Version numbers are an output of commit history, not a decision made at release time.

- `fix:`, `perf:`, `refactor:`, `docs:`, `revert:` → patch
- `feat:` → minor
- `BREAKING CHANGE:` footer or `!` after the type → major
- `chore:`, `test:`, `build:`, `ci:` → no release
- `0.x` still means unstable; do not treat a `0.x` minor bump as safe for consumers.

Never hand-edit a version, never move a published tag, and never delete a published release to redo it. A mistake is corrected by the next release.

## Conventional commits

Format: `type(scope): subject`, with `!` before the colon for a breaking change.

Allowed types: `feat`, `fix`, `perf`, `refactor`, `docs`, `style`, `test`, `build`, `ci`, `chore`, `revert`.

Enforcement, in preference order:

1. `commitlint` on PR titles when the repo squash-merges (the PR title becomes the commit).
2. `commitlint` over the PR's commit range when the repo preserves commits.
3. A pre-commit hook, which is a convenience, not enforcement, since it can be skipped.

Squash-merge is the default merge strategy for repositories using this setup: it keeps the released history one commit per change, and makes the PR title the thing that must be linted.

## Workflow authoring rules

- Pin every action to a full 40-character commit SHA, with the human-readable version in a trailing comment so Dependabot can bump it.
- Declare `permissions` explicitly at workflow level and widen per job. Start from `contents: read`.
- Never interpolate untrusted input (`github.event.pull_request.title`, issue bodies, branch names) directly into a `run:` block. Pass it through `env:` and reference the variable.
- Use `concurrency` with `cancel-in-progress: true` on PR workflows; do not cancel in-progress release or deploy runs.
- Set a `timeout-minutes` on every job.
- `pull_request_target` only when a fork PR genuinely needs secrets, and never with a checkout of the PR head.
- Prefer a reusable workflow or composite action over the same block copy-pasted into three repositories.
- Deployments to shared environments run from the default branch through a GitHub Environment with required reviewers, not from a laptop.
- Cache dependencies with the language setup action's built-in caching before reaching for `actions/cache` by hand.
- Use a matrix when the project genuinely supports multiple versions or platforms. A matrix that always runs one combination is noise.
- Do not write inline comments that restate the step name or the YAML. Comment only where a reader would otherwise ask why: a non-obvious `fetch-depth`, a pinned-back version, a permission that looks too wide.

## Security scanning

Layer scans rather than relying on one tool, and run them on pull requests plus a weekly schedule:

- **Dependencies**: Dependabot, covered below.
- **Static analysis**: CodeQL for supported languages, or Semgrep where CodeQL has no analyser.
- **Secrets**: GitHub secret scanning with push protection enabled, plus `gitleaks` or `trufflehog` in CI for history.
- **Containers**: `trivy` or `grype` on built images before push.
- **IaC**: `tfsec`, `trivy config`, or `checkov` for Terraform; `ansible-lint` for Ansible.

Upload results as SARIF so findings land in the Security tab rather than only in a log. Gate merges on the scans that produce reliable signal; a gate that is routinely overridden trains people to ignore it.

**OSSF Scorecard** (`ossf/scorecard-action`) on a schedule measures the repository's security posture and tracks it over time. The checks that usually move the score first are branch protection, pinned dependencies, token permissions, a security policy, and signed releases. Publish the results to the Security tab and add the badge.

**SLSA provenance** applies once the repository publishes artifacts (containers, packages, binaries). Use `slsa-framework/slsa-github-generator` to produce signed attestations alongside the release, and document the SLSA level reached and the verification command consumers should run. A repository that publishes nothing does not need this.

## Badges

Add to the top of `README.md` for any repository with workflows: build/CI status, release status, OSSF Scorecard score, licence, and coverage where it is measured. Use the native GitHub badge URLs or shields.io consistently, and fix them when a workflow is renamed. A permanently red or broken badge is worse than no badge.

## Ecosystem specifics

- **Ansible**: `ansible-lint` and `yamllint` on every PR; `molecule` for role testing where roles are the unit; test against the Ansible versions actually supported; scan playbooks and vars for hardcoded secrets.
- **Terraform**: `terraform fmt -check`, `terraform validate`, `tflint`, and a security scanner. Plan on PR, apply from the default branch through a protected environment.
- **Containers**: build once, scan, then promote the same digest through environments rather than rebuilding per stage.

## Dependabot

Dependabot is required, not optional. Three things have to be true, and the config file only covers the first:

1. **Version updates**: `.github/dependabot.yml` exists and covers `github-actions` plus every package ecosystem present in the repo. Copy `references/dependabot.yml` and delete the ecosystems that do not apply.
2. **Security alerts**: enabled on the repository.
3. **Security updates**: enabled, so Dependabot opens PRs for vulnerable dependencies rather than only alerting.

Enable the repository-level settings with:

```sh
gh api -X PUT "repos/{owner}/{repo}/vulnerability-alerts"
gh api -X PUT "repos/{owner}/{repo}/automated-security-fixes"
```

These change repository settings, so confirm before running them against a repo you were not asked to change.

Config conventions:

- Weekly schedule, grouped so minor and patch updates arrive as one PR per ecosystem instead of a flood.
- `github-actions` updates are what keep SHA-pinned actions current; without this entry the pinning strategy rots.
- Conventional commit prefixes, so Dependabot PRs flow through the release pipeline correctly: `chore` for dev dependencies and lockfile churn (no release), `fix` for runtime dependencies that should ship a patch.
- Cap `open-pull-requests-limit` at a number the repo can actually review; unreviewed Dependabot PRs are worse than none.

## When something fails

Read the actual failing step's log before theorising. Common causes, in the order they are usually true: a missing or too-narrow `permissions` block; `fetch-depth` defaulting to 1 when the job needs history; a secret that is not exposed to fork PRs; an action pinned to a SHA that no longer exists on a rewritten branch; a commit that produced no release because its type was in the no-release list, which is correct behaviour and not a bug.
