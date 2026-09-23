# Codex Game Studios port

Source: https://github.com/Donchitos/Claude-Code-Game-Studios at commit
`d05699707fae39a9b3c78f4b5f69eb77819094f1` (MIT).

Open this directory as a Codex project and invoke `$ccgs-start`. The 74 source
workflows are available as `$ccgs-*` skills. The 49 studio roles are native
project scoped Codex agent TOMLs in `.codex/agents/`. Game design templates,
scripts, source examples and `project.yaml` remain in their original locations.
Use `$ccgs-help` to find a workflow.

Codex reads `AGENTS.md`; `CLAUDE.md` remains as source reference because some
upstream workflows update it. `project.yaml` remains the active project config.
The 13 path rules are routed by `AGENTS.md`.

The Codex hooks adapter is in `.codex/hooks/bridge.py`. Codex requires hook
review and trust before project hooks run; inspect them with `/hooks` on first
open. Git Bash and Python 3 are required on Windows for the original shell
checks. Claude's `Notification` event has no equivalent Codex event and is not
automatically ported. The old Claude status line is not installed in Codex.
