`island setup claude` does all of this for you:

- adds a `PreToolUse` → `Bash` hook to `~/.claude/settings.json` (a backup is written next to it)
- appends a short rule block to `~/.claude/CLAUDE.md`
- copies `agents/progress-island.md` to `~/.claude/agents/` and the skill to `~/.claude/skills/`
