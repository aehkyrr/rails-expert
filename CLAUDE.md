# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Claude Code plugin** called "Rails Expert" - an all-in-one Rails 8 expert development team with DHH as coordinator and 7 specialist personas covering routing, Active Record, Hotwire, Action Cable, testing, deployment, and performance.

## Plugin Architecture

```
rails-expert/
├── .claude-plugin/plugin.json    # Plugin manifest (name, version, description)
├── agents/                       # Subagent definitions (8 agents)
│   ├── dhh-coordinator.md        # Main coordinator - routes to specialists
│   ├── routing-controllers-specialist.md
│   ├── active-record-specialist.md
│   ├── hotwire-specialist.md
│   ├── action-cable-specialist.md
│   ├── testing-specialist.md
│   ├── deployment-specialist.md
│   └── performance-specialist.md
├── commands/                     # Slash commands (9 commands)
│   ├── rails-team.md            # /rails-team - Full team consultation
│   ├── rails-routing.md         # /rails-routing - Direct specialist access
│   ├── rails-db.md              # /rails-db
│   ├── rails-hotwire.md         # /rails-hotwire
│   ├── rails-realtime.md        # /rails-realtime
│   ├── rails-testing.md         # /rails-testing
│   ├── rails-deploy.md          # /rails-deploy
│   ├── rails-perf.md            # /rails-perf
│   └── rails-config.md          # /rails-config - Configure settings
├── skills/                       # Knowledge bases for each domain
│   ├── dhh-philosophy/          # Core Rails philosophy
│   ├── routing-controllers/     # RESTful design, routing patterns
│   ├── active-record-db/        # Models, migrations, queries
│   ├── hotwire-turbo-stimulus/  # Turbo, Stimulus patterns
│   ├── action-cable-realtime/   # WebSockets, channels
│   ├── testing-minitest/        # TDD, Minitest patterns
│   ├── deployment-kamal/        # Kamal 2, Docker deployment
│   └── performance-optimization/ # Caching, profiling
└── hooks/hooks.json             # PreToolUse hooks for auto-triggering
```

### Skill Structure

Each skill follows this pattern:
```
skills/<skill-name>/
├── SKILL.md           # ~2000 word overview with frontmatter
├── references/        # Detailed topical references
│   └── *.md
└── examples/          # Code snippets demonstrating patterns
    └── *.rb|*.js|*.yml
```

## Development & Testing

### Run Plugin Locally

```bash
claude --plugin-dir /path/to/rails-expert
```

### Test in a Rails Project

Copy to project:
```bash
cp -r rails-expert /path/to/your-rails-project/.claude-plugin/
```

### Key Files for Plugin Behavior

- **`plugin.json`**: Plugin metadata and registration
- **`hooks/hooks.json`**: Defines PreToolUse hooks that trigger on Write/Edit/Bash operations
- **`.claude-example-settings.md`**: Template for user settings (copied to `.claude/rails-expert.local.md`)

## Plugin Flow

1. **User triggers**: Via command (`/rails-team`) or auto-trigger (editing Rails files)
2. **DHH coordinator** analyzes request, determines relevant specialists
3. **Specialists** are called via Task tool, read from their skills
4. **Discussion/debate** facilitated by DHH when specialists disagree
5. **Consensus** synthesized and presented based on verbosity setting

## Configuration

Users configure via `.claude/rails-expert.local.md` in their project:

| Setting | Default | Description |
|---------|---------|-------------|
| `dhh_mode` | `"full"` | Personality: `"full"` (opinionated) or `"tamed"` (professional) |
| `verbosity` | `"full"` | Output: `"full"`, `"summary"`, or `"minimal"` |
| `auto_trigger` | `true` | Auto-engage on Rails file edits |
| `enable_debates` | `true` | Allow specialist disagreements |

## Agent YAML Frontmatter

Agents use this frontmatter structure:
```yaml
---
name: agent-name
description: When to trigger, with examples in <example> blocks
model: inherit       # or sonnet, opus, haiku
color: magenta       # Terminal color
tools: Read, Grep, Glob, Task  # Allowed tools
---
```

## Command YAML Frontmatter

Commands use this structure:
```yaml
---
description: Short description for help
argument-hint: [optional-arg]
allowed-tools: Task, Read
---
```

## Skill YAML Frontmatter

Skills use this structure:
```yaml
---
name: skill-name
description: Trigger phrases and when to use, with <example> blocks
---
```

## Hook Configuration

Hooks in `hooks.json` use prompt-based evaluation to determine when to engage:
- **Write/Edit matcher**: Checks if editing Rails files (`app/models/*.rb`, etc.)
- **Bash matcher**: Checks for Rails CLI commands (`rails generate`, `rails db:migrate`)
- Both respect user settings from `.claude/rails-expert.local.md`
