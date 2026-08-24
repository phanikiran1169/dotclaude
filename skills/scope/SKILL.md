---
name: scope
description: >-
  Keeps a change to what was actually asked. Use before adding any parameter, flag, config field,
  default, threshold, fallback, retry, or filter; before deleting or hardcoding an existing option;
  before touching a second file, an import, or whitespace not named in the request; and when a
  request could be read as either a runtime setting or a design change. Also use when asked to
  refactor, clean up, tidy, or add error handling, validation, or a guard, and when a task has run
  across several turns and the current edit was not in the original request. For what a comment
  should say, see the code-comments skill; this one governs whether to touch it at all.
---

# Scope

## The default

Fix the thing asked. Nothing else.

## Say it before doing it

One sentence, before the edits: what you are changing, and which files. If the fix requires touching
something beyond the obvious target, say why in the same sentence.

The point is that the plan can be refused before the work happens, not explained afterwards.

## Adjacent problems

When you see something else wrong, name it in one line and leave it alone.

Do not fix it because it is small. Do not fix it because you are already in the file. Telling me
what you noticed is useful. Changing it uninvited is not.

Exception: the asked-for fix genuinely cannot work without the other change. Then say so and get
agreement first.

## Do not invent mechanisms

Never add a parameter, flag, gate, threshold, fallback, or safeguard that was not requested.

The dangerous version is the one that changes behavior silently — a rejection filter, a retry, a
default substitution. If a run then hits that path, the reported results are not what they appear to
be. If a mechanism seems necessary, say so and wait.

## Setting versus design

"Use X for this experiment" is a runtime value. It is not permission to:

- delete the other options from the config or the dataclass
- hardcode the value in a constructor
- remove the code paths that are unused right now

Change the setting. Leave the design alone.


## Formatting and unrelated lines

Do not touch whitespace, blank lines, imports, or comments outside the lines you are changing, even
to satisfy a linter — unless the linter is complaining about a line you just wrote.

## Drift across turns

Approval does not carry over. A yes on turn 1 covers turn 1.

Every few turns, check the current edit against the *original* request, not against the previous
turn. Each step being a reasonable follow-up to the last is exactly how a bug fix becomes a
refactor of a module nobody mentioned.

## When you have already overstepped

Say it the moment you notice, before finishing the work. Not in the summary, not as a footnote.

An unrequested change that alters behavior also invalidates anything you have already reported from
a run that included it. Say that too.

## Reporting

Say what you changed and what you deliberately did not. If you touched anything beyond the target,
that goes first.
