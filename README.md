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

First install creates fresh configuration. Subsequent runs backup your existing `settings.json` and `CLAUDE.md` to `.backup` files before updating.

## Structure

```
dotclaude/
├── CLAUDE.md              # Development guidelines and behavior rules
├── settings.json          # Base configuration (permissions: ask, hooks, statusline)
├── install.sh             # Deployment script to ~/.claude (backs up existing files)
├── statusline-script.sh   # Status bar showing project, branch, model, time, user
├── hooks/pre_tool_use/    # Safety guards (blocks rm -rf /, fork bombs, credential leaks)
├── commands/              # Slash commands (/scan, /plan, /prime)
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
/plan        # Create implementation plans
/prime       # Load project context for session
/create-spec # Throughly discuss to create technical specifications
```

### Plugins

The installer automatically installs these recommended plugins:
```bash
context7         # Enhanced codebase context and understanding
code-simplifier  # Identify and simplify complex code
superpowers      # Extended capabilities and workflows
```

To modify the plugin list, edit the `PLUGINS` array in `install.sh`.

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
Edit `hooks/pre_tool_use/*.py` - add/remove dangerous command patterns

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

## Updates

After modifying files in `~/Desktop/dotclaude`, re-run:
```bash
./install.sh  # Backs up settings.json and CLAUDE.md to .backup, then copies updated files
```

Your API keys in `~/.claude/profiles/*.json` are preserved (installer only copies `.template` files).

## Notes

- **Permissions:** All profiles use `"defaultMode": "acceptEdits"` - you approve every command
- **Safety hooks:** Active on all providers - blocks dangerous operations automatically
- **Templates vs Active:** `.template` files are blueprints, `.json` files (without .template) are active configs
- **Profile switching:** Copies the selected profile to `~/.claude/settings.json`, then restart Claude Code
