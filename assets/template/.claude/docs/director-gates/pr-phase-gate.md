> Gate definition. The spawning skill passes this file's path to the director agent; the AGENT reads it — the parent session should not.

# PR-PHASE-GATE — Production Readiness at Phase Transition

Agent: `producer` | Model tier: Opus | Domain: Scope, timeline, dependencies, production risk

**Trigger**: Always at `/gate-check` — spawn in parallel with CD-PHASE-GATE and TD-PHASE-GATE

**Context to pass**:
- Target phase name
- Sprint and milestone artifacts present
- Team size and capacity
- Current blocked story count

**Prompt**:
> "Review the current project state for [target phase] gate readiness from a
> production perspective. Is the scope realistic for the stated timeline and team
> size? Are dependencies properly ordered so the team can actually execute in
> sequence? Are there milestone or sprint risks that could derail the phase within
> the first two sprints? Return READY, CONCERNS [list], or NOT READY [blockers]."

**Verdicts**: READY / CONCERNS / NOT READY
