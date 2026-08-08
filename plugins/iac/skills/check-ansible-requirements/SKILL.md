---
name: check-ansible-requirements
description: Check if Ansible roles in requirements.yml are using the latest versions. Use when the user asks to check, audit, or update Ansible dependencies or requirements.yml.
---

# Check Ansible Requirements

Check if Ansible roles defined in `requirements.yml` are using the latest available versions from their git repositories.

## Instructions

Run from the directory holding `requirements.yml`:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/check-ansible-requirements.sh
```

The script needs `yq` and `git` on PATH. Then summarise which roles need updating in a table.

## Example Output

| Role | Current | Latest | Status |
|------|---------|--------|--------|
| configure-system | v1.0.1 | v1.1.0 | Update available |
| docker | v1.0.0 | v1.0.0 | Up to date |

## Follow-up Actions

After showing the report, ask the user if they would like to update the outdated roles to their latest versions.
