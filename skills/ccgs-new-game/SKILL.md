---
name: ccgs-new-game
description: Create a new Codex Game Studios game project from the complete ported template when the user asks to start a CCGS project.
---

Resolve `../../assets/template` relative to this `SKILL.md`, then copy it with
Python's `shutil.copytree(source, destination)`. Require a destination that does
not exist; do not overwrite existing files. `copytree` preserves hidden
directories such as `.agents`, `.codex`, and `.claude` on Windows as well as
Unix. Verify the copy contains `AGENTS.md`, `project.yaml`,
`.agents/skills/ccgs-start/SKILL.md`, `.codex/agents/`, and `.codex/hooks.json`.

Open the new directory as a Codex project, then run `$ccgs-start`. On first
open, Codex may require review and trust of the project hooks through `/hooks`.
