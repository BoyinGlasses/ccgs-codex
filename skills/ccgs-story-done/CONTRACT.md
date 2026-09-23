# $ccgs-story-done — Final Handoff Contract

## Role

Verify an approved In Progress story, present evidence once, and wait for
the game maker's acceptance. Only this skill writes `Status: Complete`.
It remains the final step of the primary agent's story task.

## Inputs

- Story file with `Status: In Progress`, `Story Approval`, `Handoff Class`,
  `Verification Method`, `Type`, acceptance criteria, scope, governing
  requirements, and `## Test Evidence`.
- `production/session-state/active.md` with story path, changed files,
  verification result, run result, review verdict, and pending decisions.
- Source/test/evidence artifacts produced by dev-story, plus relevant GDD,
  ADR, TR registry, and control manifest sections.
- Game-maker play confirmation for Player-facing or Mixed stories.

## Evidence and verdict

- Present changed files and result, every acceptance criterion mapped to
  an executed command/output or observation/evidence path, review result,
  limitations, play steps when applicable, and a decision request.
- Technical handoffs can use inspectable build/test evidence with
  `Play steps: N/A`. Player-facing handoffs require game-maker play.
  Mixed handoffs require play plus evidence for separate technical criteria.
- A screenshot can prove appearance but not that the game maker played.
  `qa.level: minimal` and advisory visual strictness do not waive play.
- A missing or failed execution is `NOT VERIFIED — <reason>` or FAIL,
  never PASS. It can be explicitly accepted as a named gap, not silently
  converted to a passing test.
- Preserve the existing verdict order: BLOCKED, NOT ASSESSED,
  COMPLETE WITH NOTES, COMPLETE. Pending play prevents either COMPLETE
  verdict until the game maker confirms playing.

## Human checkpoint

In every automation mode, wait for the game maker to accept the evidence
report. Routine manual-criterion and lean-review confirmations are batched
into this checkpoint. No separate per-file status-write prompt follows it.

- Accept with required play confirmed: update story, sprint, and session
  state once.
- Request fixes or wait: leave In Progress and record the specific pending
  item in session state; preserve current implementation.
- Accept a BLOCKED or NOT ASSESSED gap: require an explicit named-gap
  decision, record the original failure or NOT VERIFIED result and risk in
  Completion Notes, and never call that evidence PASS.

## Outputs

| File | Change after acceptance |
| --- | --- |
| Story file | `Status: Complete`, Last Updated, and Completion Notes with date, criteria/evidence, review, game-maker acceptance, play confirmation or Technical N/A, and any accepted gaps. |
| `production/sprint-status.yaml` | Matching story becomes done with completion date, if file exists. |
| `production/session-state/active.md` | Record final verdict, acceptance, play status, accepted gaps, and next action. A pending decision is recorded even without acceptance. |
| `docs/tech-debt-register.md` | Append advisory deviations only when the game maker explicitly asks. |

This skill reads but does not edit implementation or test files. The next
ready story may be surfaced only after the current story is accepted.
