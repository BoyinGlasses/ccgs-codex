# Story checkpoint harness

## Purpose

CCGS Codex acts as a copilot for a game maker. The game maker decides what to build and accepts the result. Codex carries out the approved story, gathers evidence, and returns to the game maker when a product decision changes.

## Decision

Use one primary agent to coordinate a story from readiness through implementation, review, and completion. Reuse the existing `ccgs-story-readiness`, `ccgs-dev-story`, `ccgs-code-review`, and `ccgs-story-done` skills. Invoke a specialist only for a bounded task that benefits from its expertise; the primary agent owns the handoff and final result.

There are two required human checkpoints:

1. **Before implementation:** present the story's goal, scope, acceptance criteria, and verification method. Implementation starts after the game maker approves that story.
2. **After implementation:** present the changes, verification evidence, remaining limitations, and a clear acceptance decision. The story becomes accepted only when the game maker accepts it. Requested fixes stay within the same story unless they change its approved scope.

The game maker is asked again during implementation only when Codex discovers a need to change approved scope or acceptance criteria, make a new consequential gameplay or architecture choice, or change the engine. Routine file edits, tests, and fixes within the approved story proceed without another checkpoint. This is the intended story-scoped behavior for `guided` automation; it requires reconciling the current rule that asks before every new file.

## Verification by story type

| Story type | Required handoff evidence |
| --- | --- |
| Player-facing gameplay, UI, audio, controls, or feel | A runnable build or scene, short play instructions, and test results. The game maker plays it before acceptance. |
| Technical infrastructure, tools, or internal data | Build or test results and an inspectable change summary. The game maker can accept from that evidence without a play session. |
| Mixed | Both sets of evidence and a play session before acceptance. |

If a required run or observation could not be performed, mark it **NOT VERIFIED**, state why, and leave acceptance to the game maker. A passing automated test is not evidence that player-facing feel is good.

## Handoff contract

Each story carries the approved goal, scope, acceptance criteria, story type, and verification method. The final handoff maps each criterion to evidence or an explicit gap. The primary agent records the current story and next action in the existing session state so a resumed task can continue without reconstructing decisions from chat.

## Boundaries

- Keep `project.yaml` and existing skills as the configuration and workflow entry points. Do not add an automation mode or a second orchestration runtime.
- Keep coordination shallow: primary agent plus optional bounded specialists. Do not require the leadership hierarchy for ordinary story work.
- Change only the rules and skills needed to make this story loop coherent. Preserve other workflows until a scenario shows they need adjustment.

## Validation

Validate one player-facing story and one technical story end to end, plus one story whose implementation discovers a scope change. Check that each required checkpoint occurs once, routine implementation does not trigger file-by-file approval, evidence matches the story type, and a blocked or unverified run is reported honestly. Retain the existing port smoke test for copied skills and hook compatibility.
