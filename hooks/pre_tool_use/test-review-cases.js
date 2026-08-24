// Re-checks the specific false positives and bypasses reported by the hook review.
const { checkCommand } = require('./block-dangerous-commands.js');

const FP_CLAIMS = [
  'rm -rf node_modules', 'rm -rf __pycache__', 'rm -rf .pytest_cache', 'rm -rf .mypy_cache',
  'rm -rf .ruff_cache', 'rm -rf build dist', 'rm -rf .venv', 'rm -rf target', 'rm -rf coverage',
  'rm -rf /tmp/build-cache', 'rm -rf ./node_modules', 'rm -rf src/__pycache__',
  'rm -rf node_modules/*', 'make && rm -rf build', 'npm test; rm -rf node_modules',
  'cargo build && rm -rf target/debug/incremental', 'rm -f /tmp/*.log', 'rm /tmp/*.json',
  'rm -f __pycache__/*.pyc', 'pytest -q && rm -f /tmp/pytest.log',
  'curl -s "https://api.example.com/v1/items?api_key=$MY_KEY"',
];

const BYPASS_CLAIMS = [
  'rm train.py', 'rm outputs/results.csv', 'rm -f checkpoints/best.ckpt',
  'rm data/train.npy data/val.npy',
  'python -c "import os; os.remove(\'train.py\')"',
  'python -c "import shutil; shutil.rmtree(\'outputs\')"',
  'node -e "require(\'fs\').rmSync(\'outputs\',{recursive:true})"',
  "perl -e 'unlink \"train.py\"'",
  'rsync -a --delete src/ outputs/',
  "sed -i 's/.*//' train.py",
  "perl -pi -e 's/.*//' train.py",
  'git checkout -- .', 'git restore .', 'git checkout .', 'git stash drop',
  'git branch -D feature', 'git push origin +main', 'git push --delete origin main',
  'echo hi >| train.py', 'echo hi > train.PY',
];

// Must stay blocked: the real deletions from the retrospective.
const REGRESSION = [
  'rm -rf outputs', 'rm -r checkpoints', 'rm -rf run_20240115', 'rm outputs/*.json',
  'rm -rf ~', 'flake8 . ; rm -rf outputs', 'rm -rf build outputs',
];

let bad = 0;
const run = (label, cases, want) => {
  console.log(`\n=== ${label} (want: ${want}) ===`);
  for (const c of cases) {
    const r = checkCommand(c);
    const got = r.blocked ? 'BLOCK' : 'allow';
    const ok = got === want;
    if (!ok) bad++;
    console.log(`${ok ? 'ok  ' : 'BAD '}${got} ${r.blocked ? `[${r.pattern.id}]`.padEnd(24) : ''.padEnd(24)} ${c}`);
  }
};

run('claimed false positives', FP_CLAIMS, 'allow');
run('claimed bypasses', BYPASS_CLAIMS, 'BLOCK');
run('regression: real deletions', REGRESSION, 'BLOCK');
console.log(`\n${bad === 0 ? 'ALL CLAIMS RESOLVED' : `${bad} unresolved`}`);
process.exit(bad === 0 ? 0 : 1);
