---
description: Create or update a pull request following standards. Use proactively whenever creating a pull request or pushing changes to a branch that already has one, even when not asked for by name.
allowed-tools: Bash(git:*), Bash(gh:*), Bash(base64:*), Bash(tr:*)
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

Create it with `gh pr create`, or bring an existing one back in line with the amended commit using `gh pr edit`. The title matches the commit subject. The body has these sections, in this order:

```markdown
## Description

One or two sentences on what the change is.

## What changed

- One bullet per change.

## Why

The problem and its impact, with evidence or links.

## How

The approach taken.

## Testing

The commands run and their results, links to the CI runs, and screenshots.

## Links

- Related issues, pull requests and docs, as full URLs.
- Closes owner/repo#N (Part of owner/repo#N for one part; leave out with no issue)
```

- Testing: add the CI run links with `gh pr edit` once the checks run, and embed at least one screenshot for any change a reviewer can see.
- Describe the change itself. No question ids, quotes of who asked for it or who answered what.

## Screenshots

Capture a web UI with the Orca browser (orca-cli skill) or a headless browser against a test copy of the app with test data, never production. When you start the app yourself, run it in the background on its own port, record its PID and stop it with `kill <pid>`.

Look at every image before pushing it. It must show no secret, token, credential, private hostname or personal data. A pushed image stays in the repository's history for good and is world-readable in a public repository.

Host images on an orphan `pr-assets` branch in the same repository, never merged, under `pr-assets/<number>/` for a PR or issue of the same repository, or `pr-assets/<repo>-<number>/` for an issue in another repository. Never delete a `pr-assets` branch.

Write the image as base64 to a file first, since a large PNG passed inline exceeds the argument length limit:

```sh
base64 < shot.png | tr -d '\n' > shot.b64
```

When the branch exists, push each image with the Contents API in one call, with no clone or worktree, and read `.commit.sha` from the response:

```sh
gh api -X PUT repos/<owner/repo>/contents/pr-assets/<number>/<name>.png -f message="docs: add <name> screenshot" -f branch=pr-assets -F content=@shot.b64 --jq .commit.sha
```

When it does not exist yet, create it with the first image as a parentless commit through the Git Data API, and use that commit's SHA:

```sh
blob=$(gh api repos/<owner/repo>/git/blobs -f encoding=base64 -F content=@shot.b64 --jq .sha)
tree=$(gh api repos/<owner/repo>/git/trees -f 'tree[][path]=pr-assets/<number>/<name>.png' -f 'tree[][mode]=100644' -f 'tree[][type]=blob' -f "tree[][sha]=$blob" --jq .sha)
commit=$(gh api repos/<owner/repo>/git/commits -f message="docs: add <name> screenshot" -f tree="$tree" --jq .sha)
gh api repos/<owner/repo>/git/refs -f ref=refs/heads/pr-assets -f sha="$commit"
```

Embed it on github.com pinned by that commit SHA, never through raw.githubusercontent.com:

```markdown
![<alt text>](https://github.com/<owner/repo>/blob/<commit sha>/pr-assets/<number>/<name>.png?raw=true)
```
