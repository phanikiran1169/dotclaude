# dotclaude

Personal Claude Code configuration with multi-provider support, safety hooks, and custom commands.

## Quick Start


### Install CLI if not present
```bash
if ! command -v claude &> /dev/null; then
    curl -fsSL https://claude.ai/install.sh | bash
fi
```

### Install [ccusage](https://ccusage.com/guide/getting-started) (if required)

### Setup claude custom configuration
```bash
git clone https://github.com/phanikiran1169/dotclaude.git /tmp/dotclaude
cd /tmp/dotclaude && chmod +x install.sh
./install.sh
source ~/.zshrc # or source ~/.bashrc
```

First install creates fresh configuration. Later runs keep a timestamped copy of anything they
replace in `~/.claude/backups/`, alongside the single `.backup` slot. The `.backup` slot holds only
the most recent version, so `backups/` is the reliable recovery path.

`jq` is required. Without it the installer leaves an existing `settings.json` untouched rather than
overwriting it, because a plain copy would drop your permission allowlist, model and plugin
settings.

## Structure

```
dotclaude/
├── CLAUDE.md              # Development guidelines and behavior rules
├── settings.json          # Base configuration (permissions, hooks, statusline)
├── install.sh             # Deployment script to ~/.claude (backs up existing files)
├── statusline-script.sh   # Status bar showing project, branch, model, time, user
├── hooks/pre_tool_use/    # Blocks destructive commands and credential leaks
├── hooks/post_tool_use/   # Reminds you to state a run's setup before quoting its numbers
├── skills/                # Situational guidance, loaded when the description matches
├── commands/              # Slash commands (/scan, /prime, /create-spec)
├── profiles/              # Multi-provider configurations (claude, openrouter, glm)
│   ├── claude.json        # Anthropic Claude (default)
│   ├── *.template         # Templates for providers requiring API keys
└── scripts/               # Profile switcher shell functions
```

## Usage

### Switch Providers
```bash
use-claude       # Anthropic Claude (default)
use-openrouter   # OpenRouter (400+ models)
use-glm          # GLM (Zhipu AI)
claude-profile   # Show current provider
```

### Slash Commands
```bash
/scan        # Generate project CLAUDE.md documentation
/prime       # Load project context for session
/create-spec # Discuss requirements, then write a technical specification
```

### Plugins

The installer automatically installs these recommended plugins:
```bash
context7            # Enhanced codebase context and understanding
code-simplifier     # Identify and simplify complex code
superpowers         # Extended capabilities and workflows
claude-md-management # CLAUDE.md tooling
skill-creator       # Scaffolding for new skills
codex               # Codex CLI integration (from the openai-codex marketplace)
```

These are installed unconditionally and need network access. Offline they fail without stopping the
install.

To modify the plugin list, edit the `PLUGINS` array in `install.sh`.

### Academic writing setup (opt-in)

Skipped by default — review requirements first, then enable explicitly:

```bash
./install.sh --academic
# or
INSTALL_ACADEMIC=1 ./install.sh
```

Two marketplace plugins for thesis/paper authoring are installed when enabled
(see `ACADEMIC_MARKETPLACES` in `install.sh`):

```
claude-scholar              # Citation/LaTeX/arXiv tooling (check-refs, verify-math, arxiv-prep, ...)
academic-research-skills    # ARS: research → write → review pipeline (12-agent paper, deep-research, ...)
```

System dependencies installed by the installer (cross-platform: macOS via brew,
Ubuntu via apt):

- `pandoc`  — used by ARS format conversion (DOCX/Markdown)
- `pipx`    — isolated Python CLI installer
- `arxiv-latex-cleaner` (via pipx) — used by `claude-scholar:arxiv-prep`

LaTeX stack (`lualatex`, `pdflatex`, `bibtex`, `biber`, `latexmk`) is verified
but **not** auto-installed (large download, often already present). The
installer prints the platform-specific install command if any tool is missing.

Project-level Python deps (e.g. `sympy` for `claude-scholar:verify-math`) belong
in the project's own conda env / `environment.yml`, not in dotclaude.

Optional env var for ARS cross-model verification:
```bash
export ARS_CROSS_MODEL=1
```

## Customization

### Change Model Mappings
Edit `profiles/*.json.template`:
```json
"ANTHROPIC_DEFAULT_HAIKU_MODEL": "your-fast-model",
"ANTHROPIC_DEFAULT_SONNET_MODEL": "your-balanced-model",
"ANTHROPIC_DEFAULT_OPUS_MODEL": "your-powerful-model"
```

### Modify Behavior Rules
Edit `CLAUDE.md` - controls how Claude behaves (code style, search tools, workflow)

### Adjust Safety Hooks
Edit `hooks/pre_tool_use/block-dangerous-commands.js` to add or remove patterns. Add the command to
`hooks/pre_tool_use/cases.js` first, then run the checks:

```bash
node hooks/pre_tool_use/test-patterns.js      # every case must block or pass as listed
node hooks/pre_tool_use/test-coverage.js      # reports rules no case reaches
node hooks/post_tool_use/test-eval-provenance.js
```

A pattern that blocks ordinary work is worse than no pattern, because the hook ends up switched
off. `cases.js` holds both lists for that reason.

### Add More Profiles
1. Copy existing template: `cp profiles/openrouter.json.template profiles/newprovider.json.template`
2. Update API endpoint and models
3. Add switch function to `scripts/profile-switcher.sh`

## API Key Setup

Provider profiles need API keys configured before use.

### OpenRouter
```bash
use-openrouter  # First run: auto-copies template, prompts for API key
vim ~/.claude/profiles/openrouter.json  # Replace YOUR_API_KEY_HERE with actual key
use-openrouter  # Second run: activates profile with your key
```

### GLM
```bash
use-glm  # First run: auto-copies template, prompts for API key
vim ~/.claude/profiles/glm.json  # Replace YOUR_API_KEY_HERE with actual key
use-glm  # Second run: activates profile with your key
```

**Why twice?** First run creates the config file from template. Second run (after adding your key) copies your configured profile to active settings.

## Notes

- **Permissions:** All profiles use `"defaultMode": "acceptEdits"`, which auto-accepts file edits.
  Destructive shell commands are refused by the hooks rather than by the permission prompt.
- **Safety hooks:** Active on all providers - blocks dangerous operations automatically
- **Templates vs Active:** `.template` files are blueprints, `.json` files (without .template) are active configs
- **Profile switching:** Copies the selected profile to `~/.claude/settings.json`, then restart Claude Code
