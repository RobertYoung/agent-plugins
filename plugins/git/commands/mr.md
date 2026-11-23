---
description: Create or update a GitLab merge request following standards. Use proactively whenever creating a GitLab merge request or pushing changes to a branch that already has one, even when not asked for by name.
allowed-tools: Bash(git:*), Bash(glab:*)
---

Current branch state:
!`git log main..HEAD --oneline`

Changes summary:
!`git diff main...HEAD --stat`

## Commits

Keep the branch at a single commit. The history should show the change, not the route taken to get there.

- No MR yet: commit the work as one commit. If the branch already has several commits, collapse them with `git reset --soft $(git merge-base main HEAD)` and commit once.
- MR already open (check with `glab mr view`): stage the new changes and `git commit --amend`, then `git push --force-with-lease`. Never add a follow-up commit.
- The commit message states what the change is relative to main, as a conventional commit. It never narrates how the result was reached: no "address review feedback", "fix earlier typo" or lists of iterations. Rewrite the message when amending if the scope of the change has moved.
- Only rewrite commits the user authored. If the branch contains anyone else's commits, stop and ask before amending or force-pushing.

## MR

Create it with `glab mr create`, or bring an existing one back in line with the amended commit using `glab mr update`. The title matches the commit subject. The body has these sections, in this order:

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

The commands run and their results, links to the CI pipelines, and screenshots.

## Links

- Related issues, merge requests and docs, as full URLs.
- Closes group/project#N (Part of group/project#N for one part; leave out with no issue)
```

- Testing: add the CI pipeline links with `glab mr update` once the pipeline runs, and embed at least one screenshot for any change a reviewer can see.
- Describe the change itself. No question ids, quotes of who asked for it or who answered what.

## Screenshots

Capture a web UI with the Orca browser (orca-cli skill) or a headless browser against a test copy of the app with test data, never production. When you start the app yourself, run it in the background on its own port, record its PID and stop it with `kill <pid>`.

Look at every image before uploading it. It must show no secret, token, credential, private hostname or personal data. An uploaded image stays reachable by its URL and is world-readable in a public project.

Host images with GitLab's project uploads API, and embed the `markdown` field of the response:

```sh
glab api -X POST projects/:id/uploads --form "file=@shot.png"
```
