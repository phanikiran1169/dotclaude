---
name: pull-request
description: >-
  Writes pull request titles and descriptions. Use when opening a PR, updating a PR body, or asked
  to describe a branch's changes for review. Keeps the description at the system level, excludes
  conversation context and borrowed metrics, and blocks AI attribution.
---

# Pull request descriptions

## Before writing

Run `git log <base>..HEAD --oneline` and `git diff <base>...HEAD --stat` to see what the branch
actually contains. Describe that, not the conversation that produced it.

## Audience

Someone reviewing the diff who was never in the chat. They can already see which files changed and
what the tests do. What they cannot see is why this exists and what it means for the system.

## The two failures to avoid

**Writing about the journey instead of the result.** If the work was "add feature X", and getting
there required debugging Y, the PR is about X. Y gets a line only if the reader needs it to
understand X — usually it needs nothing. What you worked on most recently is usually the least
important part of the change.

**Restating the diff.** "Modified `foo.py` to add a helper, updated tests, added 3 test cases" is
visible on the Files tab. A file-by-file list, a test summary, and a change count are all
free-to-read facts. Describing them spends the reader's attention on something they already have.

## Structure

Title: `<type>(<scope>): <imperative description>`, lowercase, no trailing period.

Body: as short as the change allows.

| Include | When |
|---|---|
| What the change does, at the system level | Always |
| Why it exists — the problem it solves | Always |
| Behavior a caller will notice | If any |
| Breaking changes and migration steps | If behavior changes for a caller |
| Metrics, before and after | Only when the numbers ARE the substance of the change |

| Leave out | Why |
|---|---|
| File-by-file summary | The Files tab shows it |
| Test summary, counts of tests added | The diff shows it |
| How the work went, what was debugged | Not the reader's problem |
| Alternatives considered and rejected | Belongs in review discussion, if anywhere |

## Metrics

Include them when they measure this change. A latency optimization carries its before and after
numbers, because that is what the PR is for.

Exclude metrics borrowed from other work. Test: does this evidence justify or measure *this* change?
If not, it does not belong.

## Never

- No conversation context: no "as discussed", no "per the review", no history of how the change
  came to be.
- No hard line wraps in the body. GitHub renders markdown, so wrapped paragraphs come out ragged.
  The 72-character wrap that applies to commit bodies does not apply here.
- No rationale dumps or rejected alternatives.

Attribution and consent rules are in CLAUDE.md and apply here without being restated.

## One PR, one concern

If the branch contains unrelated changes, say so and propose splitting it. Do not write one
description that covers two concerns.
