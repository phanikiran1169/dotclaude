#!/usr/bin/env node
// test-coverage.js: Reports which block-dangerous-commands rules no test case reaches.
// test-coverage.js: An unreached rule has never been shown to work; run after adding patterns.

const { PATTERNS, checkCommand } = require('./block-dangerous-commands.js');
const { SHOULD_BLOCK } = require('./cases.js');

// Rules that fire only as a first match are invisible when an earlier rule catches the same
// command, so each case is attributed to the rule that actually claimed it.
const claimed = new Set();
for (const cmd of SHOULD_BLOCK) {
  const r = checkCommand(cmd);
  if (r.blocked) claimed.add(r.pattern.id);
}

// A rule whose own regex matches a case that a broader rule claimed first is redundant, not
// missing: the command is still refused. Only a rule nothing matches is a real gap.
const unreached = PATTERNS.filter((p) => !claimed.has(p.id));
const shadowed = unreached.filter((p) => SHOULD_BLOCK.some((cmd) => p.regex.test(cmd)));
const uncovered = unreached.filter((p) => !shadowed.includes(p));

console.log(`${claimed.size} of ${PATTERNS.length} rules claim a case, from ${SHOULD_BLOCK.length} block cases.`);

if (shadowed.length) {
  console.log('\nShadowed — matched, but a broader rule fires first. The command still blocks:');
  for (const p of shadowed) console.log(`  [${p.level}] ${p.id}`);
}

if (uncovered.length) {
  console.log('\nUNCOVERED — no case matches these at all. Each is untested:');
  for (const p of uncovered) console.log(`  [${p.level}] ${p.id} — ${p.reason}`);
} else {
  console.log('\nNo uncovered rules.');
}

// Reporting only. Some rules are shadowed by a broader rule matching first and cannot be reached
// without contriving a command, which is worth knowing but not worth failing a build over.
process.exit(0);
