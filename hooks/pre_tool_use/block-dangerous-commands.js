#!/usr/bin/env node
// block-dangerous-commands.js: PreToolUse hook that blocks dangerous Bash commands
// block-dangerous-commands.js: Based on karanb192/claude-code-hooks with additional patterns

const fs = require('fs');
const path = require('path');

// 'strict' includes every rule. Lowering this silently disables whole rules, so the count of
// patterns it would drop is logged on every invocation rather than left to a code reading.
// Override with CLAUDE_HOOK_SAFETY_LEVEL for a single session if a rule is genuinely in the way.
const SAFETY_LEVEL = process.env.CLAUDE_HOOK_SAFETY_LEVEL || 'strict';

// Directories that regenerate from a build or install step. Deleting these is routine, and blocking
// it is what gets a hook switched off. Anything else — an output folder, a checkpoint, a dataset —
// is not assumed disposable.
const REGENERABLE = String.raw`node_modules|__pycache__|\.pytest_cache|\.mypy_cache|\.ruff_cache|\.ipynb_checkpoints|\.tox|\.venv|venv|build|dist|target|\.next|\.nuxt|\.turbo|coverage|htmlcov|\.eggs|[^\s/]*\.egg-info|\.cache|\.gradle|\.terraform`;
const SAFE_TARGET = new RegExp(String.raw`^(?:(?:\/|\.\/)?(?:[^\s;&|]*\/)?(?:${REGENERABLE})(?:\/[^\s;&|]*)?|(?:\/tmp|\/var\/tmp|\$\{?TMPDIR\}?)\/[^\s;&|]*)$`);

// True only when every path passed to every rm in the command is regenerable or scratch. One
// non-disposable argument means the whole command still gets blocked. A `..` anywhere in a target
// disqualifies it, because `build/../outputs` matches the regenerable prefix while deleting
// something else.
// Scratch roots. A relative target is scratch when the shell is already inside one, which is how
// `cd /tmp && rm -rf worktree` reads even though the path alone looks like a project directory.
const SCRATCH_ROOT = /^(?:\/tmp|\/var\/tmp|\/private\/tmp)(?:\/|$)/;

// The directory a command runs in: the last `cd` in the command if there is one, else the session's
// cwd as reported by the hook input.
function effectiveCwd(cmd, cwd) {
  const cds = [...cmd.matchAll(/\bcd\s+([^\s;&|]+)/g)];
  if (cds.length === 0) return cwd || '';
  const target = cds[cds.length - 1][1].replace(/['"]/g, '');
  return target.startsWith('/') ? target : `${cwd || ''}/${target}`;
}

function rmTargetsAllSafe(cmd, cwd) {
  const invocations = cmd.split(/[;&|]+|\n/).filter((s) => /(^|\s)(sudo\s+)?(?:rm|rmdir|unlink|shred)(\s|$)/.test(s));
  if (invocations.length === 0) return false;
  const inScratch = SCRATCH_ROOT.test(effectiveCwd(cmd, cwd));
  return invocations.every((seg) => {
    const toks = seg.trim().split(/\s+/);
    const i = toks.findIndex((t) => /^(?:rm|rmdir|unlink|shred)$/.test(t) || /\/(?:rm|rmdir|unlink|shred)$/.test(t));
    if (i === -1) return false;
    const args = toks.slice(i + 1).filter((t) => !t.startsWith('-'));
    if (args.length === 0) return false;
    return args.every((a) => {
      const target = a.replace(/['"]/g, '');
      if (target.split('/').includes('..')) return false;
      // `rm -rf .` and `rm -rf *` stay refused even in scratch: they wipe whatever is there.
      if (/^(?:\.\.?|\*|\.\/\*?)$/.test(target)) return false;
      if (/^(?:~|\$HOME|\$\{HOME\})/.test(target)) return false;
      if (inScratch && !target.startsWith('/')) return true;
      return SAFE_TARGET.test(target);
    });
  });
}

// Rules suppressed when every rm target is regenerable.
const RM_RULES = new Set(['rm-recursive', 'rm-chained', 'rm-glob', 'rm-file', 'rmdir-unlink']);

// Rules that must always see the raw command, because their evidence is the quoted text itself:
// an inline script body or a sed expression is data to the shell but is exactly what these match.
// curl-creds-url is here because a literal secret is normally written inside quotes; masking would
// hide the one thing it looks for.
const RAW_RULES = new Set(['runtime-delete', 'interp-system', 'module-delete', 'sed-in-place', 'fork-bomb', 'reverse-shell', 'curl-creds-url', 'echo-secret', 'cat-secrets', 'cat-env']);

// `git` accepts global options before the subcommand, so `git -C /repo reset --hard` and
// `git -c x=y push --force` must match the same rules as the bare forms. GIT replaces a literal
// `git ` at the start of every git pattern.
const GIT = String.raw`\bgit\s+(?:-[cC]\s+\S+\s+|--(?:git-dir|work-tree|exec-path|namespace|literal-pathspecs)=\S+\s+|--no-pager\s+|-p\s+)*`;

const PATTERNS = [
  // CRITICAL - Catastrophic, unrecoverable
  { level: 'critical', id: 'rm-home',          regex: /\brm\s+(-.+\s+)*["']?~\/?["']?(\s|$|[;&|])/,                        reason: 'rm targeting home directory' },
  { level: 'critical', id: 'rm-home-var',      regex: /\brm\s+(-.+\s+)*["']?\$HOME["']?(\s|$|[;&|])/,                      reason: 'rm targeting $HOME' },
  { level: 'critical', id: 'rm-home-trailing', regex: /\brm\s+.+\s+["']?(~\/?|\$HOME)["']?(\s*$|[;&|])/,                   reason: 'rm with trailing ~/ or $HOME' },
  { level: 'critical', id: 'rm-root',          regex: /\brm\s+(-.+\s+)*\/(\*|\s|$|[;&|])/,                                 reason: 'rm targeting root filesystem' },
  { level: 'critical', id: 'rm-system',        regex: /\brm\s+(-.+\s+)*\/(etc|usr|var|bin|sbin|lib|boot|dev|proc|sys)(\/|\s|$)/, reason: 'rm targeting system directory' },
  { level: 'critical', id: 'rm-cwd',           regex: /\brm\s+(-.+\s+)*(\.\/?|\*|\.\/\*)(\s|$|[;&|])/,                     reason: 'rm deleting current directory contents' },
  { level: 'critical', id: 'dd-disk',          regex: /\bdd\b.+of=\/dev\/(sd[a-z]|nvme|hd[a-z]|vd[a-z]|xvd[a-z])/,         reason: 'dd writing to disk device' },
  { level: 'critical', id: 'mkfs',             regex: /\bmkfs(\.\w+)?\s+\/dev\/(sd[a-z]|nvme|hd[a-z]|vd[a-z])/,            reason: 'mkfs formatting disk' },
  { level: 'critical', id: 'fork-bomb',        regex: /:\(\)\s*\{.*:\s*\|\s*:.*&/,                                         reason: 'fork bomb detected' },
  { level: 'critical', id: 'reverse-shell',    regex: /\bnc\s+-l.*-e\s*\/bin\/(bash|sh)/,                                  reason: 'reverse shell detected' },

  // HIGH - Significant risk, data loss, security
  { level: 'high', id: 'rm-recursive',   regex: /\brm\s+(-\S*\s+)*-\S*[rR]\S*\s/,                                          reason: 'recursive rm — ask before deleting a directory, including your own' },
  { level: 'high', id: 'rm-chained',     regex: /[;&|]{1,2}\s*(?:sudo\s+)?rm\s+(?:-\S*[rR]\S*\s+|-\S+\s+)*(?:[^\s;&|]*[*?]|[^\s;&|]+\/\s*)(?:\s|$|[;&|])/,                                             reason: 'rm chained onto another command — run deletions on their own so they can be refused' },
  { level: 'high', id: 'rm-glob',        regex: /\brm\s+(-\S+\s+)*[^|;&]*\*/,                                              reason: 'rm with a glob — enumerate the matches first' },
  { level: 'high', id: 'mv-overwrite',   regex: /\bmv\s+(-\S*f\S*\s+)/,                                                    reason: 'mv -f overwrites the destination' },
  // Only hand-written source. Generating data, configs or model artifacts by redirect
  // (`ros2 param dump > params.yaml`, `xacro a.xacro > a.urdf`, `export.py > model.onnx`) is
  // routine and must stay allowed, or this pattern gets switched off.
  { level: 'high', id: 'truncate-source', regex: /(?<![>\d\w])>\|?\s*(?!\/dev\/|\/tmp\/)[^\s>|&;'"]*\.(py|js|ts|tsx|jsx|c|cc|cpp|h|hpp|rs|go|java|rb|sh|ipynb)\b/i, reason: 'redirect truncates a source file — use Write or Edit, or confirm the overwrite' },
  // Deleting one checkpoint, dataset or source file is the most likely real loss, and every other
  // rm rule needs -r, a glob, or a chain to fire.
  { level: 'high', id: 'rm-file',         regex: /\brm\s+(?:-\S+\s+)*(?!(?:\/tmp\/|\/var\/tmp\/))[^\s;&|]*\.(?:py|js|ts|tsx|jsx|c|cc|cpp|h|hpp|rs|go|java|rb|sh|ya?ml|toml|json|md|csv|ckpt|pth|pt|onnx|safetensors|npy|npz|urdf|xacro|proto|ipynb)\b/i, reason: 'rm deleting a named source or data file' },
  // The obvious next move once a shell delete is refused.
  // Covers combined flags (`python -Bc`) and a heredoc body, not only a bare `-c`.
  { level: 'high', id: 'runtime-delete',  regex: /\b(?:python[\d.]*|node|perl|ruby)\b[^|;&]*(?:\s-[A-Za-z]*[ceEr][A-Za-z]*\b|\s*<<)[\s\S]*?(?:os\.remove|os\.unlink|os\.rmdir|shutil\.rmtree|\.unlink\(|rmSync|unlinkSync|rmdirSync|File\.delete|FileUtils\.rm|\brmtree\b|\bunlink\b)/, reason: 'deleting files from an inline script — ask first' },
  { level: 'high', id: 'interp-system',   regex: new RegExp([
    // awk hands a string to the shell.
    String.raw`\bawk\b[\s\S]*?system\s*\(`,
    // A subprocess call whose argv starts with a delete command.
    String.raw`subprocess\.(?:run|call|Popen|check_output)\s*\(\s*\[?\s*['\"](?:rm|rmdir|shred|unlink)['\"]`,
    // Other interpreters with their own delete primitives.
    String.raw`\b(?:php|lua|tclsh)\b[\s\S]*?(?:unlink|os\.remove|file\s+delete)\s*\(`,
  ].join('|')), reason: 'deleting through an interpreter call — ask first' },
  { level: 'high', id: 'module-delete',   regex: /\b(?:python[\d.]*\s+-m\s+shutil\b[^|;&]*\b(?:rmtree|move)|perl\s+(?:-\S+\s+)*-MFile::Path\b)/, reason: 'deleting files through a module invocation — ask first' },
  { level: 'high', id: 'rsync-delete',    regex: /\brsync\b[^|;&]*--delete(?:-\w+)?\b/,                                   reason: 'rsync --delete removes files missing from the source' },
  { level: 'high', id: 'sed-in-place',    regex: /\b(?:sed|perl)\b[^|;&]*\s-(?:i|pi|-in-place)(?:\.\S+|'')?(?:\s|$)/,     reason: 'in-place edit bypasses Write/Edit review' },
  { level: 'high', id: 'git-discard',     regex: new RegExp(GIT + String.raw`checkout\s+(?:-f|--force)\b|` + GIT + String.raw`(?:checkout|restore)\b[^|;&]*\s--(?:\s|$)|` + GIT + String.raw`checkout\s+\.\s*(?:$|[;&|])|` + GIT + String.raw`restore\s+(?:-\S+\s+)*[^\s;&|-][^\s;&|]*|` + GIT + String.raw`stash\s+drop\b|` + GIT + String.raw`branch\s+-D\b`), reason: 'discards uncommitted work or deletes a branch' },
  { level: 'high', id: 'git-push-force-refspec', regex: new RegExp(GIT + String.raw`push\b[^|;&]*\s\+\S*(?:main|master|HEAD)|` + GIT + String.raw`push\b[^|;&]*--delete\b`), reason: 'force push via + refspec, or remote branch deletion' },
  { level: 'high', id: 'rmdir-unlink',    regex: /\b(rmdir|unlink|shred|trash)\s+(-\S+\s+)*[^\s;&|]/,                      reason: 'deletes a file or directory — ask first' },
  // Relocating a results directory or checkpoint loses it just as effectively as deleting it.
  { level: 'high', id: 'mv-away',          regex: /\bmv\s+(?:-\S+\s+)*(?!\/tmp|\/var\/tmp|~\/Downloads|build\/|dist\/|node_modules)(?:(?:[^\s;&|]*\/)?(?:outputs?|runs?|checkpoints?|ckpt|logs?|data|datasets?|results?)(?:\/[^\s;&|]*)?(?=\s)|[^\s;&|]*\.(?:ckpt|pth|pt|onnx|safetensors|npy|npz|csv|parquet|bag|db))\s+(?:\/tmp|\/var\/tmp|~\/\.?[Tt]rash)/, reason: 'moving something out of the project into scratch or trash — ask first' },
  // truncate-source only sees redirects. These overwrite a file without one.
  { level: 'high', id: 'overwrite-source', regex: /\b(?:cp|install)\s+(?:-\S*f\S*\s+)(?!\/tmp\/)[^\s;&|]+\s+(?!\/tmp\/)[^\s;&|]*\.(?:py|js|ts|tsx|rs|go|c|cc|cpp|h|hpp|java|rb|sh|ipynb)\s*$|\b(?:cp|install)\s+(?:-\S+\s+)*(?!\/tmp\/)[^\s;&|]*?([^\s;&|\/]+)\.(?:py|js|ts|tsx|rs|go|c|cc|cpp|h|hpp|java|rb|sh|ipynb)\s+(?!\/tmp\/)[^\s;&|]*\1\.(?:py|js|ts|tsx|rs|go|c|cc|cpp|h|hpp|java|rb|sh|ipynb)\s*$|\bln\s+(?:-\S*f\S*\s+)[^\s;&|]+\s+[^\s;&|]*\.(?:py|js|ts|tsx|rs|go|c|cc|cpp|h|hpp|java|rb|sh|ipynb)\b|\btee\s+(?:(?!-a\b|--append\b)-\S+\s+)*(?!\/tmp\/|\/dev\/)[^\s;&|-][^\s;&|]*\.(?:py|js|ts|tsx|rs|go|c|cc|cpp|h|hpp|java|rb|sh|ipynb)\b/i, reason: 'overwrites a file in place — use Write or Edit' },
  // Killing a long run discards hours of unwritten work.
  { level: 'high', id: 'kill-run',         regex: /\b(?:pkill|killall)\s+(?:-\S+\s+)*\S*(?:train(?:ing)?|eval(?:uate)?|rollout|experiment|sweep|benchmark)(?:[._-]?(?:py|sh|job|run|worker)\b|\b)/i, reason: 'killing a long run loses unwritten work — confirm first' },
  // History and stash destruction, and the colon-refspec form of a remote branch delete.
  { level: 'high', id: 'git-history-loss', regex: new RegExp(GIT + String.raw`stash\s+clear\b|` + GIT + String.raw`reflog\s+expire\b|` + GIT + String.raw`gc\b[^|;&]*--prune|` + GIT + String.raw`update-ref\s+-d\b|` + GIT + String.raw`filter-branch\b|` + GIT + String.raw`worktree\s+remove\b[^|;&]*(?:\s-f\b|\s--force\b)|` + GIT + String.raw`push\b[^|;&]*\s:\S*(?:main|master)`), reason: 'destroys git history, stashes, or a remote branch' },
  // Extracting over the working tree overwrites whatever the archive contains.
  { level: 'high', id: 'extract-overwrite', regex: /\btar\s+(?:-[A-Za-z]*x[A-Za-z]*|--extract)\b(?![^|;&]*-C\s*(?:\/tmp|\/var\/tmp))[^|;&]*(?:-C\s*\.(?:\s|$)|$)|\bunzip\s+(?:-\S+\s+)*-o\b(?![^|;&]*-d\s*(?:\/tmp|\/var\/tmp))|\bgunzip\s+-\S*f/, reason: 'extraction overwrites files in the working tree' },
  // Remote and container-managed data.
  { level: 'high', id: 'remote-data-loss', regex: /\baws\s+s3\s+(?:rm|sync)\b[^|;&]*(?:--recursive|--delete)|\bkubectl\s+delete\s+(?:pvc|pv|persistentvolume\w*|namespace|ns|statefulset|sts|secret|configmap)\b|\bkubectl\s+delete\b[^|;&]*--all\b|\bdocker\s+compose\s+down\b[^|;&]*-v|\bdocker\s+(?:container|builder|volume)\s+prune\b/, reason: 'deletes remote or persistent data' },
  { level: 'high', id: 'find-delete',     regex: /\bfind\b.*(-delete|-exec\s+(rm|unlink|shred)\b)/,                       reason: 'find deleting matches — enumerate them first' },
  { level: 'high', id: 'xargs-rm',        regex: /\|\s*(sudo\s+)?xargs\b.*\b(rm|unlink|shred)\b/,                         reason: 'xargs deleting a piped list — enumerate it first' },
  { level: 'high', id: 'truncate-cmd',    regex: /\btruncate\s+(-\S+\s+)*-s\s*0/,                                         reason: 'truncate -s 0 empties a file' },
  { level: 'high', id: 'curl-pipe-sh',   regex: /\b(curl|wget)\b.+\|\s*(ba)?sh\b/,                                        reason: 'piping URL to shell (RCE risk)' },
  { level: 'high', id: 'git-force-main', regex: new RegExp(GIT + String.raw`push\b(?!.+--force-with-lease).+(--force|-f)\b.+\b(main|master)\b`), reason: 'force push to main/master' },
  { level: 'high', id: 'git-no-verify',  regex: /\bgit\b[^|;&]*(?:--no-verify|-c\s+core\.hooksPath\s*=)/,                                   reason: 'bypasses pre-commit hooks, fix the cause instead' },
  { level: 'high', id: 'git-reset-hard', regex: new RegExp(GIT + String.raw`reset\s+--hard`),                                                 reason: 'git reset --hard loses uncommitted work' },
  { level: 'high', id: 'git-clean-f',    regex: new RegExp(GIT + String.raw`clean\s+(-\w*f|-f)`),                                             reason: 'git clean -f deletes untracked files' },
  { level: 'high', id: 'chmod-777',      regex: /\bchmod\b.+\b777\b/,                                                     reason: 'chmod 777 is a security risk' },
  { level: 'high', id: 'chown-root',     regex: /\bchown\b.*-R.*root\s+\//,                                               reason: 'recursive chown to root' },
  { level: 'high', id: 'cat-env',        regex: /\b(cat|less|head|tail|more)\s+\.env\b/,                                  reason: 'reading .env file exposes secrets' },
  // Matches secret-bearing files, not prose about them: docs/credentials_flow.md and
  // notes/secrets_design.md are documentation and stay readable.
  { level: 'high', id: 'cat-secrets',    regex: /\b(cat|less|head|tail|more)\b.+(\.pem|\.key|\.p12|\.pfx|id_rsa|id_ed25519|id_ecdsa|\.aws\/credentials|\.netrc|\.htpasswd|(^|[\/\s])(credentials|secrets?)(\.\w+)?(\s|$))/i, reason: 'reading secrets file' },
  // A bare dump only. `env | grep ROS_DOMAIN_ID` and `printenv PATH` name what they want.
  { level: 'high', id: 'env-dump',       regex: /(^|[;&|]\s*)(printenv|env)\s*([;&]|$)/,                                   reason: 'full environment dump may expose secrets' },
  { level: 'high', id: 'echo-secret',    regex: /\becho\b.+\$\w*(SECRET|KEY|TOKEN|PASSWORD|API_|PRIVATE)/i,               reason: 'echoing secret variable' },
  // A literal secret in a URL leaks into shell history and logs. Passing a variable is the correct
  // pattern and is exempt.
  { level: 'high', id: 'curl-creds-url', regex: /\bcurl\b.*(?:api_key|apikey|password|secret|token)=(?!\$|%24)[^\s&"']/i, reason: 'literal credential in a URL — pass it in a variable or header' },
  { level: 'high', id: 'docker-vol-rm',  regex: /\bdocker\s+volume\s+(rm|prune)/,                                         reason: 'docker volume deletion loses data' },
  { level: 'high', id: 'rm-ssh',         regex: /\brm\b.+\.ssh\/(id_|authorized_keys|known_hosts)/,                       reason: 'deleting SSH keys' },

  // STRICT - Cautionary, context-dependent
  { level: 'strict', id: 'git-force-any',    regex: new RegExp(GIT + String.raw`push\b(?!.+--force-with-lease).+(--force|-f)\b`),              reason: 'force push (use --force-with-lease)' },
  { level: 'strict', id: 'git-checkout-dot', regex: new RegExp(GIT + String.raw`checkout\s+\.`),                                               reason: 'git checkout . discards changes' },
  { level: 'strict', id: 'sudo-rm',          regex: /\bsudo\s+rm\b/,                                                       reason: 'sudo rm has elevated privileges' },
  { level: 'strict', id: 'docker-prune',     regex: /\bdocker\s+(system|image)\s+prune/,                                   reason: 'docker prune removes images' },
  { level: 'strict', id: 'crontab-r',        regex: /\bcrontab\s+-r/,                                                      reason: 'removes all cron jobs' },
];

const LEVELS = { critical: 1, high: 2, strict: 3 };
const LOG_DIR = path.join(process.env.HOME, '.claude', 'hooks-logs');

function log(data) {
  try {
    if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });
    const file = path.join(LOG_DIR, `${new Date().toISOString().slice(0, 10)}.jsonl`);
    fs.appendFileSync(file, JSON.stringify({ ts: new Date().toISOString(), ...data }) + '\n');
  } catch {}
}

// Commands that hand their quoted argument to a shell or an interpreter, so the text inside the
// quotes is executed rather than passed as data.
const EXECUTES_ARGUMENT = new RegExp([
  // A shell or interpreter given its program as an argument. The flag may be combined with others,
  // as in the login-shell form `bash -lc`, or `python -Bc`.
  String.raw`\b(?:ba|z|k|da|fi)?sh\s+(?:-\S+\s+)*-[A-Za-z]*c[A-Za-z]*\b`,
  String.raw`\b(?:python[\d.]*|node|perl|ruby|php|lua|tclsh)\s+(?:-\S+\s+)*-[A-Za-z]*[ceEr][A-Za-z]*\b`,
  // Commands whose whole purpose is running a supplied command line.
  // These take a command string that a shell will parse.
  String.raw`\bssh\b`,
  String.raw`(?:^|[;&|]\s*)(?:eval|su|runuser|doas)\b`,
  String.raw`(?:^|[;&|]\s*)(?:at|batch)\s+(?:-\S+\s+)*(?:\d|now|noon|midnight|teatime)`,
  String.raw`\b(?:script|watch|screen)\b[^|;&]*["']`,
  // `tmux send-keys` types text into a pane; it does not hand it to a shell.
  String.raw`\btmux\s+(?!(?:send-keys|display-message|list-)\b)[\w-]+\b[^|;&]*["']`,
  // The argv-exec wrappers hand their arguments straight to the program, so a quoted argument is
  // data unless a shell is named in it.
  String.raw`\b(?:env|timeout|nohup|setsid|stdbuf|flock)\s+(?:\S+\s+)*?(?:ba|z|k|da|fi)?sh\b`,
  // `xargs` and `sudo` only hand their argument to a shell when a shell is named. Matching them
  // bare would treat `sudo grep` and `xargs grep` as shell and flag their search patterns.
  String.raw`\b(?:xargs|sudo)\s+(?:-\S+\s+)*(?:ba|z|k|da|fi)?sh\b`,
  String.raw`\bdocker\s+(?:exec|run)\b`,
  // A quoted string piped or fed into a shell is that shell's program.
  String.raw`\|\s*(?:sudo\s+)?(?:ba|z|k|da)?sh\b`,
  String.raw`(?:ba|z|k|da)?sh\s*<<<`,
].join('|'));

// Blanks the contents of quoted strings so a `>` or `rm` inside an argument (`rg "x -> y.py"`,
// `git commit -m "fix rm -rf guard"`) is read as data rather than as shell.
//
// Left unmasked when the command executes its argument: in `bash -c "rm -rf /"` the quoted text is
// the command, and blanking it hides the only thing worth matching. Deciding this per command
// rather than per rule is what keeps both cases correct.
function maskQuoted(cmd) {
  if (EXECUTES_ARGUMENT.test(cmd)) return cmd;
  return cmd.replace(/'[^']*'|"[^"]*"/g, (m) => m[0] + ' '.repeat(m.length - 2) + m[0]);
}

// Names the rules a given safety level switches off, so a lowered level is visible in the log
// instead of only in the source.
function disabledRules(safetyLevel = SAFETY_LEVEL) {
  const threshold = LEVELS[safetyLevel] || 2;
  return PATTERNS.filter((p) => LEVELS[p.level] > threshold).map((p) => p.id);
}

function checkCommand(cmd, safetyLevel = SAFETY_LEVEL, cwd = '') {
  const threshold = LEVELS[safetyLevel] || 2;
  const masked = maskQuoted(cmd);
  const rmSafe = rmTargetsAllSafe(masked, cwd);
  for (const p of PATTERNS) {
    if (rmSafe && RM_RULES.has(p.id)) continue;
    const subject = RAW_RULES.has(p.id) ? cmd : masked;
    if (LEVELS[p.level] <= threshold && p.regex.test(subject)) {
      return { blocked: true, pattern: p };
    }
  }
  return { blocked: false, pattern: null };
}

async function main() {
  let input = '';
  for await (const chunk of process.stdin) input += chunk;

  try {
    const data = JSON.parse(input);
    const { tool_name, tool_input, session_id, cwd, permission_mode } = data;
    if (tool_name !== 'Bash') return console.log('{}');

    const cmd = tool_input?.command || '';
    const result = checkCommand(cmd, SAFETY_LEVEL, cwd);

    const off = disabledRules();
    if (off.length) log({ level: 'DEGRADED', safety_level: SAFETY_LEVEL, disabled: off, session_id });

    if (result.blocked) {
      const p = result.pattern;
      log({ level: 'BLOCKED', id: p.id, priority: p.level, cmd, session_id, cwd, permission_mode });
      return console.log(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'PreToolUse',
          permissionDecision: 'deny',
          permissionDecisionReason: `[${p.id}] ${p.reason}`
        }
      }));
    }
    console.log('{}');
  } catch (e) {
    log({ level: 'ERROR', error: e.message });
    console.log('{}');
  }
}

if (require.main === module) {
  main();
} else {
  module.exports = { PATTERNS, LEVELS, SAFETY_LEVEL, checkCommand, disabledRules, rmTargetsAllSafe, effectiveCwd };
}
