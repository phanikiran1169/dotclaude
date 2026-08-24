---
name: conventional-commits
description: >-
  Writes git commit messages in Conventional Commits format. Activates when the user asks to
  'commit', 'create a commit', 'save changes', 'write a commit message', 'stage and commit', or any
  git commit task. Also covers rewriting history: squash, rebase, amend, fixup, reword. Enforces types, scopes, breaking-change notation, imperative mood, and a message
  written for someone who was never in the conversation.
---

# Commit messages

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Type

| Type | When |
|---|---|
| `feat` | New feature (MINOR in SemVer) |
| `fix` | Bug fix (PATCH) |
| `perf` | Performance change |
| `refactor` | Restructuring with no behavior change |
| `docs` | Documentation only |
| `test` | Tests only |
| `style` | Formatting only, no meaning change |
| `build` | Build system or dependencies |
| `ci` | CI configuration |
| `chore` | Anything else outside src and tests |
| `revert` | Reverts an earlier commit |

Scope is optional, lowercase, in parentheses, and names the area affected: `fix(auth): ...`

## Description

Imperative, lowercase, no trailing period. Says what changed, not how. The whole first line —
type, scope and description — stays under 72 characters.

## Body

Optional, and only when the "why" is not obvious from the description. One blank line before it.
Wrap at 72 characters, which applies to commit bodies only; PR descriptions are markdown and must
not be hard-wrapped.

## Breaking changes

Either `!` before the colon, or a `BREAKING CHANGE:` footer, or both:

```
feat(api)!: change pagination response format

BREAKING CHANGE: responses return `items` instead of `data`; clients must update
```

`BREAKING CHANGE` is uppercase. Everything else — type, scope, description — is lowercase.

## Audience

Write for someone reading `git log` in six months who was never in the conversation. They can run
`git show` to see what changed. The message says what the change accomplishes.

**Name the destination, not the journey**, and **do not restate the diff**. Both rules are the same
here as for a PR body, with the reasoning in the pull-request skill. In short: if the task was "add
feature X" and it needed debugging Y along the way, the subject is X, and `git show` already lists
the files.

- **No conversation context.** No "as discussed", no "per your request", no metrics borrowed from
  unrelated work.
- **No vague descriptions.** Not "update code", "fix stuff", "misc changes".

## Length

There is no line limit. Test each line instead: it must name something the change does, or
something a reader will run into.

Cut any line that explains how you found the problem, what you tried first, what a log or a diff
showed you, or why the old code was wrong. Those are true and they are not the reader's problem.

| Keep | Cut |
|---|---|
| What it does, one line per part | How you found it |
| Behavior a caller will notice | What you tried first |
| Migration steps for a breaking change | What the log showed |
| A constraint that survived, and why it holds | Why the old code was wrong |

A large change earns a long message when its parts are genuinely separate. It never earns a
narrative. One line is right far more often than it feels.

## Examples

```
fix(auth): resolve token expiration race condition
```

```
refactor(parser): simplify AST node creation

Replace the factory pattern with direct constructor calls. All node types share
the same creation logic, so the factory added indirection without abstraction.
```

## Procedure

1. Read the staged changes: `git diff --cached`
2. Pick the type, and a scope if one applies
3. Write the description; add a body only if the "why" is not obvious
4. Add footers for breaking changes or references (`Refs: #456`)

If the changes cover several unrelated concerns, propose separate commits with explicit file paths
per commit rather than staging everything at once.

Git identity, AI attribution, consent before committing, and `--no-verify` are covered in CLAUDE.md
and apply here without being restated.
