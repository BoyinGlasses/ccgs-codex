# Game Studios for Codex (CCGS Codex)

Turn Codex into a coordinated game development studio. This Codex port packages
74 adapted workflow skills, 49 specialist agent roles, 13 project rules, and a
complete starter template for Godot, Unity, or Unreal Engine projects.

The project template and workflows are adapted from
[Donchitos/Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios).
Upstream project content is MIT licensed; see [LICENSE](LICENSE).
This is an unofficial community port and is not affiliated with or endorsed by
the upstream author.

## Install from GitHub

Requires Codex CLI and Git. Run:

```powershell
codex plugin marketplace add BoyinGlasses/ccgs-codex
codex plugin add ccgs-codex@ccgs-codex
```

Start a **new Codex task** after installation so Codex loads the plugin skills.

## Start a game project

In a Codex task, create a project from the included template:

```text
$ccgs-new-game Create a project at D:\Games\MyGame
```

Open the new folder as a Codex project, then run:

```text
$ccgs-start
```

For an existing game project, open its folder in Codex and run `$ccgs-start`.
Use `$ccgs-help` to find workflows. Workflow skills are named `$ccgs-*` to avoid
collisions with unrelated Codex skills.

## What's included

- `skills/` — adapted Codex workflows, including `$ccgs-start` and `$ccgs-help`.
- `assets/template/` — project structure, `AGENTS.md`, 49 native Codex agent
  definitions, 74 project skills, documentation, templates, and Codex hooks.
- `.agents/plugins/marketplace.json` — marketplace catalog for GitHub installs.

On first project open, Codex may ask you to review and trust the project's hooks
through `/hooks`. On Windows, Git Bash and Python 3 are needed by the original
shell validation scripts.

## Port notes

The upstream Claude `Notification` event and status line have no direct Codex
equivalent. Codex project hooks cover session startup, tool validation,
compaction, and subagent logging. See [assets/template/CODEX-PORT.md](assets/template/CODEX-PORT.md).

After changing skills, agents, or hooks, run `python tests/smoke_port.py` to
check the copied project and Codex hook bridge.

## Credits

Created as a Codex adaptation of Claude Code Game Studios by Donchitos. The
upstream is the source of the game studio workflows, templates, and rules; this
repository adapts them to Codex skills, agents, and hooks.
