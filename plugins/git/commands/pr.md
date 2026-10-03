---
description: Create or update a pull request following standards. Use proactively whenever creating a pull request or pushing changes to a branch that already has one, even when not asked for by name.
allowed-tools: Bash(git:*), Bash(gh:*)
---

Current branch state:
!`git log main..HEAD --oneline`

Changes summary:
!`git diff main...HEAD --stat`

## Commits

Keep the branch at a single commit. The history should show the change, not the route taken to get there.

- No PR yet: commit the work as one commit. If the branch already has several commits, collapse them with `git reset --soft $(git merge-base main HEAD)` and commit once.
- PR already open (check with `gh pr view`): stage the new changes and `git commit --amend`, then `git push --force-with-lease`. Never add a follow-up commit.
- The commit message states what the change is relative to main, as a conventional commit. It never narrates how the result was reached: no "address review feedback", "fix earlier typo" or lists of iterations. Rewrite the message when amending if the scope of the change has moved.
- Only rewrite commits the user authored. If the branch contains anyone else's commits, stop and ask before amending or force-pushing.

## PR

Create it with `gh pr create`, or bring an existing one back in line with the amended commit using `gh pr edit`. The title matches the commit subject and the body is:

### Summary

- 1-3 bullet points describing the changes
- Focus on WHAT changed and WHY

Note: No test plan section needed - TDD means tests are already written and passing.
