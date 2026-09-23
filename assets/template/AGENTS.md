# Codex Game Studios

This is the Codex port of Claude Code Game Studios. Start with `$ccgs-start` or `$ccgs-help`.
The studio's original `CLAUDE.md` is retained as a legacy mirror and source
reference; this file governs Codex.

Read `project.yaml` for engine, stage, rigor, automation and team settings. Read
`.claude/docs/coordination-rules.md` and `.claude/docs/coding-standards.md` when relevant.
Use `production/session-state/active.md` as the checkpoint after compaction or a resumed session.

Workflow skills live in `.agents/skills/ccgs-*/SKILL.md`. References to old `/name`
commands mean the corresponding `$ccgs-name` skill. Role definitions are native
Codex agents in `.codex/agents/`; use them only when delegation is available and
the task warrants it. Do not imply a role ran when it did not.

Ask for missing product decisions and wait for the answer. User instructions and
the active permission policy take precedence over old Claude approval language.
Use Codex's available tools in place of Claude's named tools.

## Path rules

Before editing a matching path, read its rule:

- `.claude/rules/agent-memory.md` when editing: .claude/agent-memory/**
- `.claude/rules/ai-code.md` when editing: src/ai/**
- `.claude/rules/data-files.md` when editing: assets/data/**
- `.claude/rules/design-docs.md` when editing: design/gdd/**
- `.claude/rules/engine-code.md` when editing: src/core/**
- `.claude/rules/gameplay-code.md` when editing: src/gameplay/**
- `.claude/rules/narrative.md` when editing: design/narrative/**
- `.claude/rules/network-code.md` when editing: src/networking/**
- `.claude/rules/prototype-code.md` when editing: prototypes/**
- `.claude/rules/shader-code.md` when editing: assets/shaders/**
- `.claude/rules/skill-authoring.md` when editing: .agents/skills/**, .claude/agents/**
- `.claude/rules/test-standards.md` when editing: tests/**
- `.claude/rules/ui-code.md` when editing: src/ui/**
