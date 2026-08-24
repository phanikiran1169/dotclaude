---
name: code-comments
description: >-
  Writes or revises comments, docstrings, and file headers — prose that lives inside source files.
  Use before adding any comment, when asked to document or explain code in place, and when a comment
  is being corrected for style. Covers what earns a comment, how long it should be, and the specific
  failures: restating the code, conversational traces, and phrasing that reads as unnatural or
  incomplete. For prose outside source files — docs, READMEs, posts — use no-ai-slop instead.
---

# Code comments

## What earns a comment

A comment is worth writing when the code cannot say the thing itself:

- A constant whose value came from measurement, a standard, or hardware. Say where it came from.
- A unit, frame, or convention that the type does not carry: `distance in mm`, `body frame`, `wxyz`.
- A non-obvious constraint: an ordering that matters, a lock that must be held, a range that breaks.
- A deliberate choice that looks like a mistake. Without the note, someone will "fix" it.

Everything else is noise. Do not comment what the code already says.

```python
# Bad — restates the signature
def load_config(path: Path) -> Config:
    """Loads the config from the given path and returns a Config."""

# Good — says what the signature cannot
def load_config(path: Path) -> Config:
    """Reads a config file. Missing optional keys take defaults; missing
    required keys raise ConfigError."""
```

## Length

One or two sentences. If a comment needs a paragraph, the usual cause is that it is explaining
something that belongs in a doc, or the code is unclear and should be changed instead.

When more context is genuinely needed, add one sentence at a time and stop when the next sentence
stops changing what a reader would do. A comment longer than the code it describes is a sign the
explanation is in the wrong place.

## Write plain, complete sentences

Comments are prose. Use full sentences with a subject and a verb, ending in a period. A reader
should not have to reconstruct the grammar.

| Not this | This |
|---|---|
| `// handles the reset case` | `// Resets the accumulator when the phase changes.` |
| `// for perf` | `// Cached because this runs once per frame.` |
| `// note: order matters here` | `// Apply the offset before scaling; the scale assumes a zero base.` |
| `// the thing that does the mapping` | `// Maps sensor ids to calibration entries.` |

Say the specific thing. "Handles", "processes" and "manages" name a category, not an action. The
reader learns nothing from them.

## Never

**Conversational traces.** The comment is read by someone who was not in the conversation.

- No "as we discussed", "per the review", "as requested", "matching the other file".
- No history: "previously this used X", "changed from Y", "was broken before".
- No justification against alternatives: "rather than Z", "X was tried and rejected",
  "otherwise Y would happen".
- No instructions to an imagined reader: "do not swap these arguments", "be careful here".
- No measurement anecdotes: "this took 40 minutes on the test set".

**Temporal references.** "New", "currently", "for now", "recently", "will be removed". They are
wrong within a month. Write what is true and let git hold the history.

**Restating the signature.** The parameter list is visible. A docstring that names each parameter
and its type adds nothing unless it says something the type does not.

## File headers

Two lines, each starting with the filename, saying what the file is for:

```python
# config.py: Loads and validates run configuration.
# config.py: Values not set in the file fall back to the defaults in DEFAULTS.
```

## When correcting a comment

Fix the one comment asked about. Adjacent comments with the same problem get named in one line, not
rewritten. See the scope skill.
