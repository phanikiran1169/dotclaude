#!/usr/bin/env node
// test-eval-provenance.js: Checks the provenance reminder fires on experimental runs only.
// test-eval-provenance.js: Run with `node hooks/post_tool_use/test-eval-provenance.js`.

const { fires, inspect } = require('./eval-provenance.js');

// Runs pointed at a server, checkpoint, or explicit mode. These are the ones where a number can
// silently mean something other than it appears to.
const SHOULD_FIRE = [
  'python eval.py --host localhost --port 8000',
  'python eval.py --ckpt checkpoints/best.pth',
  'python run_eval.py --replay',
  'python serving/stub_server.py --mode replay & python eval.py',
  'python infer.py --endpoint http://localhost:8080',
  'python benchmark.py --checkpoint ckpt/latest --port 9000',
  'python rollout.py --model-path ckpt/x.pt',
  'python train.py --resume ckpt/step_5000.pt',
  'python evaluate.py --url http://127.0.0.1:8000/act',
  'python run_experiment.py --dry-run',
  // A run naming no mode or artifact still needs its setup stated — this is the common shape, and
  // the one the hook was silent on.
  'python eval.py --episode 5',
  'python scripts/eval.py --episode 5',
  'python evaluate_model.py --episode 5',
  'python scripts/replay_eval.py --episode 5',
  'python -m pkg.eval --split val',
  // Training counts only when pointed at a checkpoint or endpoint.
  'python train.py --resume ckpt/step_5000.pt',
];

// Ordinary commands, including ones that print plenty of numbers.
const SHOULD_NOT_FIRE = [
  'pytest -q',
  'pytest tests/test_eval.py -v',
  'ruff check .',
  'flake8 .',
  'mypy src/',
  'npm test',
  'cargo test',
  'ls -la outputs/',
  'git status',
  'python train.py',
  'python -c "print(2+2)"',
  'python plots/fig_pred_set.py',
  'rg "TODO"',
  'nvidia-smi',
  'python setup.py install',
  'docker compose up -d',
  'curl -s http://localhost:8080/health',
  'tensorboard --logdir runs/',
  // A plain training run is not a claim about a number.
  'python train.py --config config.yaml',
  'python train.py --epochs 30',
  'colcon build --symlink-install',
  'python setup.py install',
  'python scripts/summarize.py > results.csv',
];

let failures = 0;

for (const cmd of SHOULD_FIRE) {
  if (!fires(cmd)) {
    failures++;
    console.log(`MISS      ${cmd}`);
  } else {
    const ids = inspect(cmd).map((h) => h.id).join(',') || 'no signals named';
    console.log(`reminds   [${ids}] ${cmd}`);
  }
}

console.log('');

for (const cmd of SHOULD_NOT_FIRE) {
  if (fires(cmd)) {
    failures++;
    console.log(`FALSE+    ${cmd}`);
  } else {
    console.log(`quiet     ${cmd}`);
  }
}

console.log(`\n${failures === 0 ? 'PASS' : `FAIL — ${failures} problem(s)`}`);
process.exit(failures === 0 ? 0 : 1);
