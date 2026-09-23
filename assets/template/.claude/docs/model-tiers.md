# Model Tier Assignment

> ### DECLARED, NOT CURRENTLY APPLIED — skills only
>
> **Claude Code reads `model:` from a skill's frontmatter and then serves the
> skill from the session's model anyway.** This has been measured directly
> against session transcripts on several Claude Code versions, and held every
> time. To re-test it on a newer version, run a skill that declares a tier
> different from the session model and check which model the transcript
> attributes the skill's turns to.
>
> So the skill tiers below are **intent, not behaviour**. Setting one changes
> nothing today. They are kept because they are correct descriptions of what each
> skill needs, and because they cost nothing to carry if Claude Code honours them
> later — but do not budget on them, and never tell a user a tier is saving them
> money.
>
> **This does NOT apply to agents.** `model:` in `.claude/agents/*.md` is a
> different mechanism, spawned as a separate session rather than executed inline.
> It has not been measured here, so treat the agent section below as unverified
> in either direction rather than assuming it behaves the same way.

Skills and agents are assigned tiers by task complexity:

| Tier | Model | When to use |
|------|-------|-------------|
| **Haiku** | `claude-haiku-4-5-20251001` | Read-only status checks, formatting, simple lookups — no creative judgment needed |
| **Sonnet** | `claude-sonnet-5` | Implementation, design authoring, analysis of individual systems — default for most work |
| **Opus** | `claude-opus-5` | Multi-document synthesis, high-stakes phase gate verdicts, cross-system holistic review |

Skills with `model: haiku` (5): `/help`, `/onboard`, `/project-stage-detect`,
`/scope-check`, `/sprint-status`

> `/patch-notes` and `/changelog` are `sonnet`, not `haiku`: both produce
> **player-facing** copy and need judgement the cheapest tier is defined as not
> doing. Full reasoning in each skill's own header.
>
> `/settings` was moved off `haiku` for the same reason. It does not only read
> and format — it resolves every leaf with provenance and then compares the
> configured rigor against the project's observable working practice. That is
> synthesis, which is what the Haiku row is defined as excluding.

Skills with `model: opus` (3): `/architecture-review`, `/gate-check`, `/review-all-gdds`

All other skills are Sonnet. When creating a new skill, assign Haiku if it only
reads and formats; assign Opus if it must synthesize 5+ documents with
high-stakes output; otherwise write `model: sonnet` explicitly. Every skill in
this repo declares a tier, and the lists above are kept in step with what the
`SKILL.md` files declare. That is a check on two descriptions agreeing; it
proves nothing about which model actually runs.

**Agent model tiers.** Orchestrator-spawned agents (`team-*`, `/review-all-gdds`)
use `model: inherit` so a fixed smaller model can't overflow when the parent runs
a large-context tier. Directors stay `opus`, `community-manager`/`devops-engineer`
stay `haiku`, and non-orchestrator agents stay pinned at `sonnet` as a floor.
