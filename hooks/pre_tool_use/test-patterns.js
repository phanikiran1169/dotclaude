#!/usr/bin/env node
// test-patterns.js: Checks block-dangerous-commands patterns against known cases.
// test-patterns.js: Run with `node hooks/pre_tool_use/test-patterns.js`; exits non-zero on failure.

const { checkCommand } = require('./block-dangerous-commands.js');
const { SHOULD_BLOCK, SHOULD_PASS } = require('./cases.js');

let failures = 0;

for (const cmd of SHOULD_BLOCK) {
  const r = checkCommand(cmd);
  if (!r.blocked) {
    failures++;
    console.log(`MISS      ${cmd}`);
  } else {
    console.log(`blocked   [${r.pattern.id}] ${cmd}`);
  }
}

console.log('');

for (const cmd of SHOULD_PASS) {
  const r = checkCommand(cmd);
  if (r.blocked) {
    failures++;
    console.log(`FALSE+    [${r.pattern.id}] ${cmd}`);
  } else {
    console.log(`allowed   ${cmd}`);
  }
}

console.log(`\n${failures === 0 ? 'PASS' : `FAIL — ${failures} problem(s)`}`);
process.exit(failures === 0 ? 0 : 1);
