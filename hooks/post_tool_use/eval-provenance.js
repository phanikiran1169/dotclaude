#!/usr/bin/env node
// eval-provenance.js: PostToolUse hook that injects a provenance reminder after a command that
// eval-provenance.js: points a run at a served endpoint, checkpoint, or replay/stub mode.

// A replay or stub server returns recorded ground truth, which is indistinguishable from a perfect
// prediction in the output. The reminder fires when a run is launched, not when its results are
// written up, because the setup is fixed by then.
//
// Advisory only: it adds context and never blocks.

const fs = require('fs');
const path = require('path');

// Details that change what a number means. Reported when present, but their absence is not a
// reason to stay quiet — a run with no flags at all still has a mode and an artifact, and not
// naming them is the problem.
const SIGNALS = [
  { id: 'mode-flag',  regex: /--(?:replay|stub|mock|dry-run|sim|simulate|offline|fake)\b/i,        note: 'a mode flag is set' },
  { id: 'mode-word',  regex: /\b(?:replay|stub[-_]?server|mock[-_]?server|dry[-_]run|sim(?:ulat\w+)?)\b/i, note: 'the command names a replay, stub or simulation component' },
  { id: 'checkpoint', regex: /--(?:ckpt|checkpoint|weights|model[-_]path|resume)[=\s]/i,           note: 'a checkpoint is selected explicitly' },
  { id: 'endpoint',   regex: /--(?:host|port|url|endpoint|server|addr)[=\s]|https?:\/\/(?:localhost|127\.0\.0\.1|0\.0\.0\.0)/i, note: 'the run talks to a served endpoint' },
  { id: 'episode',    regex: /--(?:episode|split|dataset|data[-_]dir|scene|task)[=\s]/i,           note: 'a specific slice of data is selected' },
];

// Commands that launch a run producing numbers to report. Matches an eval-shaped script name
// anywhere in the path, so `scripts/replay_eval.py` and `evaluate_model.py` are covered, not only
// bare verbs. Test runners and linters are excluded below.
const RUN_SHAPED = new RegExp(
  [
    // A script whose name says it runs or measures something.
    String.raw`\b(?:python[\d.]*|node|ros2\s+run|roslaunch)\b[^|;&]*?[\w/.-]*(?:eval|evaluat\w*|infer\w*|rollout|benchmark|predict|replay|sweep|experiment|episode)[\w.-]*\.(?:py|js|ts)\b`,
    // A bare verb form: `make eval`, `./run_eval`. Anchored to a launching command so that
    // `git diff src/eval.py`, `rg "eval" src/` and `wc -l eval.py` do not count as runs.
    String.raw`^\s*(?:\S*\/)?(?:make|python[\d.]*|node|bash|sh|ros2|roslaunch)\b[^|;&]*\b(?:eval|evaluate|inference|rollout|benchmark|sweep)\b`,
    String.raw`\bpython[\d.]*\s+-m\s+\S*(?:eval|infer|rollout|benchmark|train)\S*`,
  ].join('|'),
  'i',
);

// Test runners, linters and package managers produce numbers, or name a package with "eval" in it,
// but none of them is an experiment.
const NOT_AN_EXPERIMENT = new RegExp([
  // Test runners and linters produce numbers but measure code, not a system.
  String.raw`^\s*(?:pytest|ruff|flake8|mypy|black|isort|npm\s+test|cargo\s+test|go\s+test|tox|nox)\b`,
  // Package managers name packages with "eval" in them.
  String.raw`\b(?:pip|pip3|uv|conda|poetry|npm|yarn|pnpm)\s+(?:install|add|remove|uninstall|sync)\b`,
  // A shell loop over files, or running a test script, is not an experiment.
  String.raw`^\s*for\s+\w+\s+in\b`,
  String.raw`\btest-[\w.-]+\.(?:js|py|sh)\b`,
  String.raw`\b(?:test|tests)\/`,
].join('|'), 'i');

const LOG_DIR = path.join(process.env.HOME, '.claude', 'hooks-logs');

function log(data) {
  try {
    if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });
    const file = path.join(LOG_DIR, `${new Date().toISOString().slice(0, 10)}.jsonl`);
    fs.appendFileSync(file, JSON.stringify({ ts: new Date().toISOString(), hook: 'eval-provenance', ...data }) + '\n');
  } catch {}
}

// Returns the signals matched for a run-shaped command. An empty array means the command is not a
// run; `null` is never returned, so callers check length. A run with no signals still fires — see
// `fires()`.
function inspect(cmd) {
  if (!cmd || NOT_AN_EXPERIMENT.test(cmd)) return [];
  if (!RUN_SHAPED.test(cmd)) return [];
  return SIGNALS.filter((s) => s.regex.test(cmd));
}

// Whether the reminder should be injected. Any run-shaped command qualifies: a plain
// `python eval.py --episode 5` names neither its mode nor its artifact, which is exactly the case
// where the setup needs stating.
function fires(cmd) {
  if (!cmd || NOT_AN_EXPERIMENT.test(cmd)) return false;
  if (RUN_SHAPED.test(cmd)) return true;
  // Training is excluded above because a training run is not itself a claim about a number. It
  // still qualifies when pointed at a checkpoint, an endpoint or an explicit mode, since a resumed
  // run can silently use the wrong weights.
  return /\btrain\w*\.(?:py|js|ts)\b|\btrain\b/i.test(cmd) && SIGNALS.some((s) => s.id !== 'episode' && s.regex.test(cmd));
}

function reminder(hits) {
  const observed = hits.length
    ? `This looks like an experimental run: ${hits.map((h) => h.note).join('; ')}.`
    : 'This looks like an experimental run.';
  return [
    observed,
    '',
    'Before reporting any number from it, say in the first sentence what it ran against: real or',
    'simulated, what produced the actions (trained policy, stub, replayed log), which checkpoint or',
    'config, and which data. Check the mode from the output itself, not from the flag you passed. A',
    'replay server returns recorded ground truth, which looks the same as a perfect policy.',
    '',
    'If a caveat would make the number meaningless, it is not a caveat. See the verify skill.',
  ].join('\n');
}

async function main() {
  let input = '';
  for await (const chunk of process.stdin) input += chunk;

  try {
    const data = JSON.parse(input);
    if (data.tool_name !== 'Bash') return console.log('{}');

    const cmd = data.tool_input?.command || '';
    if (!fires(cmd)) return console.log('{}');
    const hits = inspect(cmd);

    log({ level: 'REMINDED', signals: hits.map((h) => h.id), cmd, session_id: data.session_id });
    console.log(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        additionalContext: reminder(hits),
      },
    }));
  } catch (e) {
    log({ level: 'ERROR', error: e.message });
    console.log('{}');
  }
}

if (require.main === module) {
  main();
} else {
  module.exports = { inspect, fires, SIGNALS, RUN_SHAPED, NOT_AN_EXPERIMENT };
}
