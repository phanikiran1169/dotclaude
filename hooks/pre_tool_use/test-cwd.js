#!/usr/bin/env node
// test-cwd.js: Checks that a delete is judged against the directory the command runs in.
// test-cwd.js: Run with `node hooks/pre_tool_use/test-cwd.js`; exits non-zero on failure.

const { checkCommand } = require('./block-dangerous-commands.js');

// [command, cwd, expected]. The cwd column is what Claude Code passes to the hook.
const CASES = [
  // A relative delete inside a scratch root is scratch, however project-shaped the name looks.
  ['cd /tmp && rm -rf pr484wt && git worktree add --detach /tmp/pr484wt', '/ssd/x', 'allow'],
  ['rm -rf pr484wt', '/tmp', 'allow'],
  ['cd /ssd/x && rm -rf /tmp/fx2 && mkdir -p /tmp/fx2/a', '/ssd/x', 'allow'],
  ['rm -f /tmp/scratch.txt', '/ssd/project', 'allow'],
  ['rm -rf /tmp/build-cache', '/ssd/project', 'allow'],
  ['rm -rf node_modules', '/ssd/project', 'allow'],
  // rmdir and unlink delete too, so they get the same scratch exemption as rm.
  ['rmdir /tmp/scratch-dir', '/ssd/project', 'allow'],
  ['cd /tmp && mkdir -p wt && rmdir wt', '/ssd/project', 'allow'],
  ['rmdir outputs', '/ssd/project', 'BLOCK'],

  // Wiping the working directory stays refused, scratch or not.
  ['rm -rf .', '/tmp', 'BLOCK'],
  ['rm -rf *', '/tmp', 'BLOCK'],
  ['rm -rf ./*', '/tmp', 'BLOCK'],

  // Being in scratch does not license deleting an absolute path elsewhere.
  ['cd /tmp && rm -rf /ssd/project/outputs', '/tmp', 'BLOCK'],
  ['cd /tmp && rm -rf ~/.claude', '/tmp', 'BLOCK'],

  // A project delete is refused with or without a known cwd.
  ['rm -rf outputs', '/ssd/project', 'BLOCK'],
  ['rm -rf outputs', '', 'BLOCK'],
  ['cd /ssd/project && rm -rf outputs', '/ssd/x', 'BLOCK'],
  ['rm -r checkpoints', '/ssd/project', 'BLOCK'],
  ['rm -f checkpoints/best.ckpt', '/ssd/project', 'BLOCK'],
  ['rm outputs/*.json', '/ssd/project', 'BLOCK'],

  // A delete folded onto an unrelated command is refused.
  ['ruff check . && rm -rf outputs', '/ssd/project', 'BLOCK'],
  ['pytest -q ; rm -rf runs', '/ssd/project', 'BLOCK'],

  // Deleting a named source file is unrecoverable, so it is refused even as deliberate cleanup.
  ['cd /ssd/x/boxfit && rm -f fit_and_loss.py && echo done', '/ssd/x', 'BLOCK'],
];

let failures = 0;
for (const [cmd, cwd, want] of CASES) {
  const r = checkCommand(cmd, undefined, cwd);
  const got = r.blocked ? 'BLOCK' : 'allow';
  if (got !== want) {
    failures++;
    console.log(`BAD  ${got} (want ${want})  cwd=${cwd || '-'}  ${cmd}`);
  } else {
    console.log(`ok   ${got.padEnd(6)} cwd=${(cwd || '-').padEnd(14)} ${cmd}`);
  }
}

console.log(`\n${failures === 0 ? 'PASS' : `FAIL - ${failures} problem(s)`}`);
process.exit(failures === 0 ? 0 : 1);
