# agent-plugins

A [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) holding my personal engineering standards, so the same conventions apply in every repository without copying a `CLAUDE.md` around.

## Plugins

| Plugin | Contents | What it covers |
| :----- | :------- | :------------- |
| `ci` | skill `ci-architect` | Every repo releases automatically: semver from conventional commits, hardened GitHub Actions, security scanning, Dependabot enabled |
| `iac` | skills `terraform-standards`, `check-ansible-requirements`<br>agents `terraform-architect`, `ansible-architect` | Terraform and OpenTofu conventions, Ansible role and playbook design, dependency freshness |
| `github` | agent `github-repo-enhancer` | Community health files: README, CODEOWNERS, SECURITY.md, CONTRIBUTING.md, issue and PR templates |
| `security` | agent `security-auditor` | Secrets, vulnerable dependencies, insecure configuration |
| `git` | commands `pr`, `mr` | Opening pull requests on GitHub and merge requests on GitLab |

## Install

### From GitHub

```
/plugin marketplace add RobertYoung/agent-plugins
/plugin install ci@robertyoung-agent-plugins
/plugin install iac@robertyoung-agent-plugins
/plugin install github@robertyoung-agent-plugins
/plugin install security@robertyoung-agent-plugins
/plugin install git@robertyoung-agent-plugins
```

The `owner/repo` shorthand resolves to GitHub. To use the full HTTPS URL instead, or to pin to a tag:

```
/plugin marketplace add https://github.com/RobertYoung/agent-plugins.git
/plugin marketplace add https://github.com/RobertYoung/agent-plugins.git#v1.0.0
```

The `.git` suffix matters: without it Claude Code treats the URL as a direct link to a hosted `marketplace.json`.

### From a local checkout

Useful when developing the plugins themselves, since edits take effect without pushing.

```sh
git clone https://github.com/RobertYoung/agent-plugins.git ~/git/github.com/RobertYoung/agent-plugins
```

Then, in Claude Code:

```
/plugin marketplace add ~/git/github.com/RobertYoung/agent-plugins
/plugin install ci@robertyoung-agent-plugins
```

A relative path works too (`/plugin marketplace add ./agent-plugins`), resolved from the current working directory.

Each user can register only one marketplace per name, so adding the local checkout replaces a previously added GitHub copy, and vice versa. Remove the other one first if you want to be explicit:

```
/plugin marketplace remove robertyoung-agent-plugins
```

### For a whole project

To have collaborators prompted to install these, commit to the project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "robertyoung-agent-plugins": {
      "source": {
        "source": "github",
        "repo": "RobertYoung/agent-plugins"
      }
    }
  },
  "enabledPlugins": {
    "ci@robertyoung-agent-plugins": true,
    "iac@robertyoung-agent-plugins": true,
    "security@robertyoung-agent-plugins": true
  }
}
```

### After installing

If the install summary says `Run /reload-plugins to activate.`, run it.

Components are namespaced by plugin. Skills and commands appear as `/ci:ci-architect`, `/iac:terraform-standards`, `/git:pr`; agents as `security:security-auditor`. Claude also invokes them on its own when a task matches the description.

These replace the equivalents in `~/.claude/agents`, `~/.claude/skills` and `~/.claude/commands`. Delete the user-scoped copies once installed, or they load twice.

## Updating

```
/plugin marketplace update robertyoung-agent-plugins
```

Third-party marketplaces have auto-update off by default; turn it on per marketplace from the **Marketplaces** tab in `/plugin`.

Plugins carry a `version` in their manifest, so `/plugin update` only moves you when a release bumps it. That version is written by `scripts/sync-version.sh` during the release, driven by the commit history. Do not edit it by hand.

## Repository layout

```
.claude-plugin/marketplace.json    # marketplace catalog
plugins/<plugin>/
├── .claude-plugin/plugin.json     # plugin manifest
├── skills/<skill>/SKILL.md        # the standard itself, plus references/ templates
├── agents/<agent>.md              # subagents
├── commands/<command>.md          # flat slash commands
└── scripts/                       # referenced as ${CLAUDE_PLUGIN_ROOT}/scripts/...
scripts/validate-manifests.sh      # manifest and frontmatter checks, run in CI
scripts/sync-version.sh            # writes the released version into the manifests
```

## Developing

Point the marketplace at your local checkout (see above), edit, then `/plugin marketplace update robertyoung-agent-plugins` and `/reload-plugins`.

Before opening a PR:

```sh
./scripts/validate-manifests.sh
for p in plugins/*/; do claude plugin validate "$p" --strict; done
```

`claude plugin validate` catches things the manifest checker cannot, notably agent frontmatter that fails to parse. An agent whose `description` contains an unquoted `: ` loads with **empty metadata** and is silently never invoked, so run it before committing a new agent.

If skills do not appear after an update, clear the cache with `rm -rf ~/.claude/plugins/cache` and restart.

## Releases

This repository follows the standards the `ci` plugin describes. Commits use [conventional commits](https://www.conventionalcommits.org/), the PR title is linted because merges are squashed, and `semantic-release` cuts a semver tag and GitHub release on every push to `main`. Versions are never hand-edited.

## Licence

MIT. See [LICENSE](LICENSE).
