# $ccgs-dev-story — Handoff Contract

## Role in Pipeline

One primary Codex agent validates and obtains approval for a story, implements
it within the approved scope, verifies it, and continues to
`$ccgs-code-review` and `$ccgs-story-done` in the same task. The game maker
owns the story decision. Specialists answer bounded questions when useful.

## Inputs

- A story at `production/epics/**/*.md` with `Status: Ready`, or an
  `In Progress` story with a recorded `**Story Approval**: YYYY-MM-DD`.
- The existing `Type:`, acceptance criteria, dependencies, Out of Scope,
  governing GDD/ADR/manifest context, and `## Test Evidence` section.
- `Handoff Class:` and `Verification Method:` when present. For a legacy
  story, propose both in the approval card and persist them on approval.
- Engine configuration and commands from `project.yaml`, with the documented
  legacy fallbacks. `production/session-state/active.md` identifies a resumed
  story and any pending scope decision.

## Preconditions

- Run `$ccgs-story-readiness [story-path]` for a new Ready story. Only READY
  proceeds to story approval. Do not rerun readiness merely because an
  approved In Progress story resumes.
- Load the story, applicable registry/ADR/manifest rules, engine preferences,
  and dependency status before approval or implementation. A Proposed ADR or
  missing required input blocks as specified by workflow tier. Read each
  referenced ADR's Status at every tier; a freshness stamp is not a status
  check.
- Show one approval card with goal, in/out-of-scope boundary, every
  acceptance criterion, Handoff Class, and Verification Method. Wait for the
  game maker's explicit approval in every automation mode.

## Writes and Outputs

| Artifact | Contract |
| --- | --- |
| Story file | After approval, persist Handoff Class and Verification Method if missing, `**Story Approval**: YYYY-MM-DD`, then `Status: In Progress` and Last Updated. Never write Complete. |
| `production/session-state/active.md` | Record story path, approval, handoff, changed files, verification result, next step, and any pending decision. Create if absent. |
| Source and test files | The primary agent implements within approved scope at the resolved code root. Logic/Integration tests follow `## Test Evidence` unless waived at `qa.level: minimal`. No per-file write prompt is needed. |
| Evidence | Report executed build/test commands and results. For anything player-observable, run and retain visual evidence when possible; otherwise state `NOT VERIFIED — <reason>`. |
| Specialist consultation | Use a bounded question for a named risk; report the result, skip, or `NOT ASSESSED — specialist unavailable`. Missing consultation never counts as engine verification. |

## Decision Boundaries

- Stop before an out-of-scope file edit, acceptance-criteria change,
  consequential gameplay or architecture choice, or engine change. Append
  the pending decision to session state and preserve in-scope work. Resume
  only after the game maker approves the revised story and the pending
  decision is cleared.
- An approved In Progress story with no pending decision resumes without
  repeating approval. In Progress without an approval record needs the card
  before further implementation edits.
- Run relevant parse/build/test and run-observe checks. A partial specialist
  or implementation result is INCOMPLETE, not a successful handoff.
- Continue through `$ccgs-code-review` and `$ccgs-story-done` without
  asking the user to invoke either. Resolve in-scope review fixes and
  recheck them before the final acceptance checkpoint.

## Downstream

`$ccgs-story-done` reads the approved story, session state, source/test
evidence, review outcome, and run result. It alone can mark
`Status: Complete` after game-maker acceptance.
