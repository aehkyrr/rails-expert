---
description: Configure Rails Expert plugin settings
argument-hint: [optional-flags]
allowed-tools: Read, Write, AskUserQuestion
---

# Rails Expert Plugin Configuration

This command helps you configure the Rails Expert plugin settings.

Check if `.claude/rails-expert.local.md` exists. If it does, read it to show current configuration.

$IF($ARGUMENTS,
Quick configuration mode with arguments: $ARGUMENTS

Parse arguments and update settings accordingly. Common arguments:
- `--enable [feature]` - Enable a feature (auto_trigger, debates, etc.)
- `--disable [feature]` - Disable a feature
- `--set-mode [full|tamed]` - Set DHH personality mode
- `--set-verbosity [full|summary|minimal]` - Set output detail level
,
Interactive configuration mode.

Use the AskUserQuestion tool to guide the user through configuration options:

1. **Enable/Disable Plugin**: Master on/off switch
2. **DHH Mode**: "The Full Experience" (opinionated) vs "Tamed Edition" (professional)
3. **Auto-Trigger**: Automatically engage when editing Rails code or running Rails commands
4. **Verbosity**: Full discussion, summary only, or minimal output
5. **Enabled Specialists**: All specialists or specific subset
6. **Advanced Settings**: Minimum change threshold, excluded paths, debate settings
)

Create or update `.claude/rails-expert.local.md` with the configuration:

```markdown
---
enabled: true                           # Master enable/disable
auto_trigger: true                      # Auto-trigger on edits/commands
verbosity: full                         # full | summary | minimal
enabled_specialists: ["all"]            # or specific list
minimum_change_lines: 5                 # Trigger threshold
excluded_paths: ["vendor/", "tmp/"]     # Skip these paths
excluded_files: []                      # Individual file exclusions
dhh_mode: "full"                        # "full" (opinionated) | "tamed" (professional)
specialist_personalities: true          # Enable distinct specialist tones
allow_unprompted_input: true            # Let specialists chime in unsolicited
enable_debates: true                    # Allow specialist disagreements
bash_enabled_specialists: ["all"]       # Which specialists can run commands
---

# Rails Expert Configuration

Configuration saved. Settings take effect after restarting Claude Code.
```

After creating/updating the file, inform the user:

1. Configuration saved successfully
2. Summary of current settings
3. Reminder that changes require restarting Claude Code
4. Suggestion to run `/rails-team` to test the configuration

Make configuration easy and clear!
