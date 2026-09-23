> Gate definition. The spawning skill passes this file's path to the director agent; the AGENT reads it — the parent session should not.

# CD-PHASE-GATE — Creative Readiness at Phase Transition

Agent: `creative-director` | Model tier: Opus | Domain: Vision, pillars, player experience

**Trigger**: Always at `/gate-check` — spawn in parallel with TD-PHASE-GATE and PR-PHASE-GATE

**Context to pass**:
- Target phase name
- List of all artifacts present (file paths)
- Game pillars and core fantasy

**Prompt**:
> "Review the current project state for [target phase] gate readiness from a
> creative direction perspective. Are the game pillars faithfully represented in
> all design artifacts? Does the current state preserve the core fantasy? Are there
> any design decisions across GDDs or architecture that compromise the intended
> player experience? Return READY, CONCERNS [list], or NOT READY [blockers]."

**Verdicts**: READY / CONCERNS / NOT READY
