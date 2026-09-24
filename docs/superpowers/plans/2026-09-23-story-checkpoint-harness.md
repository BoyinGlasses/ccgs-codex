# Story Checkpoint Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make each game story a copilot loop with approval before implementation and human acceptance after evidence review.

**Architecture:** Keep the existing story skills and one primary agent. Add a small handoff classification to the story, make story approval the authority for routine implementation edits, and make final acceptance the only path to `Status: Complete`. Use existing session state and behavioral skill specs; add no runtime or automation mode.

**Tech Stack:** Markdown skills and contracts, YAML project configuration, Python port smoke test.

**Spec:** `docs/superpowers/specs/2026-09-23-story-checkpoint-harness-design.md`

## Global Constraints

- Two human checkpoints per story: approve the story before implementation, accept the result after evidence review.
- Player-facing and mixed stories require the game maker to play before acceptance; technical stories can be accepted from build or test evidence.
- Scope, acceptance criteria, consequential gameplay or architecture choices, and engine changes require a new decision before related work continues.
- `modes.automation` remains the existing configuration; story checkpoints apply in every mode. Other workflows keep their current mode behavior.
- A missing run is reported `NOT VERIFIED` with a reason. Do not claim automated tests prove player experience.
- Edit the plugin skill under `skills/ccgs-*/` and copy it to the same path under `assets/template/.agents/skills/`; `tests/smoke_port.py` requires byte equality.
- Use `rtk` for shell commands. On Windows, use `rtk proxy powershell -NoProfile -Command "..."` for native file operations.

## Review Focus

These are the five likely failures to probe in the task that owns them:

1. A `Logic` story that changes visible combat still needs a playtest; `Type:` alone must not classify it as technical (Task 1).
2. An older story without handoff fields must reach the first checkpoint with a proposed classification, not silently default to technical (Task 2).
3. A resumed `In Progress` story with recorded approval must not ask for the same approval again; one without a record must not silently assume approval (Task 2).
4. A discovered out-of-scope edit must pause before that edit and preserve the pending decision in session state (Task 2).
5. A player-facing story with a screenshot but no game-maker play confirmation, or any story with `NOT VERIFIED` evidence, must not be reported as fully verified (Task 3).

## File map

- `skills/ccgs-create-stories/{SKILL,CONTRACT}.md`: seed the handoff class and concrete verification method in new story files.
- `skills/ccgs-story-readiness/{SKILL,CONTRACT}.md`: assess those fields without breaking older stories.
- `skills/ccgs-dev-story/{SKILL,CONTRACT}.md`: first checkpoint, resumption, primary-agent ownership, and scope-change pause.
- `skills/ccgs-code-review/SKILL.md`: return review findings to the primary agent without an extra routine user checkpoint.
- `skills/ccgs-story-done/{SKILL,CONTRACT}.md`: evidence report, conditional playtest, and final acceptance.
- `assets/template/.agents/skills/ccgs-*/`: byte-identical mirrors of each changed plugin skill and contract.
- `assets/template/.claude/docs/{automation-modes,coordination-rules}.md`: narrowly scoped policy reconciliation.
- `assets/template/CCGS Skill Testing Framework/skills/{pipeline,readiness}/*.md`: update the existing behavioral cases for changed skills. Do not add another test harness.

### Task 1: Story handoff contract

**Files:** `skills/ccgs-create-stories/SKILL.md`, `skills/ccgs-create-stories/CONTRACT.md`, `skills/ccgs-story-readiness/SKILL.md`, `skills/ccgs-story-readiness/CONTRACT.md`, their template mirrors, and the corresponding `create-stories.md` and `story-readiness.md` behavioral specs under `assets/template/CCGS Skill Testing Framework/skills/`.

**Interfaces:** A story keeps its existing `Type:` and `## Test Evidence`; it adds `**Handoff Class**: Player-facing | Technical | Mixed` and `**Verification Method**: ...`. `Handoff Class` describes the acceptance path, while `Type:` continues to select code and QA rules.

- [ ] **Step 1: Add behavioral cases first.** In the two existing skill test specs, add a fixture where `Type: Logic` implements visible combat and must receive `Handoff Class: Player-facing`, plus a legacy fixture without either new field that readiness reports as an advisory gap. State that missing fields alone do not change a legacy READY verdict to BLOCKED.
- [ ] **Step 2: Check the current behavior.** In a disposable game project copied from `assets/template/`, invoke `$ccgs-skill-test spec create-stories` and `$ccgs-skill-test spec story-readiness`. Record the expected FAIL or PARTIAL on the new assertions; these are model-evaluated specs, not Python tests.
- [ ] **Step 3: Update the story template and contract.** In `ccgs-create-stories`, add the exact story fields below near `Type:` and `## Test Evidence` and instruct the author to derive them from the actual acceptance criteria and QA steps, then show them in the story draft before the user approves creation:

  ```markdown
  **Handoff Class**: [Player-facing | Technical | Mixed]
  **Verification Method**: [exact build/test command or manual play steps; name the evidence path]
  ```

  A story with any player-observable behavior is Player-facing unless it also has independent technical acceptance criteria, in which case it is Mixed. Do not derive the class solely from `Type:`.
- [ ] **Step 4: Update readiness.** Validate that the class is one of the three values and the method names a concrete action and expected evidence. For older stories missing fields, report `ADVISORY: classify at the dev-story approval checkpoint`; preserve existing readiness rules and verdict precedence. Update both contracts to name the new fields and compatibility behavior.
- [ ] **Step 5: Mirror and verify.** Copy the four changed files to their matching template skill directories. Run `rtk python tests/smoke_port.py`, re-run the two behavioral specs, and check `rtk git diff --check`. Expected: smoke passes, new cases PASS, no whitespace errors.
- [ ] **Step 6: Commit.** Stage only Task 1 files and commit `feat(harness): classify story handoffs`.

### Task 2: Approval before implementation

**Files:** `skills/ccgs-dev-story/{SKILL,CONTRACT}.md`, template mirrors, `assets/template/.claude/docs/automation-modes.md`, `assets/template/.claude/docs/coordination-rules.md`, and the existing `skills/pipeline/dev-story.md` behavioral spec in the template testing framework.

**Interfaces:** `dev-story` consumes a READY story and writes an approved handoff class, verification method, `**Story Approval**: YYYY-MM-DD`, `Status: In Progress`, and a session extract. `story-done` later reads these fields. The primary Codex agent owns implementation; specialist agents receive only bounded assignments when engine risk or expertise warrants them.

- [ ] **Step 1: Add behavioral cases first.** Cover an unapproved Ready story, a legacy story missing handoff fields, a resumed In Progress story with and without `Story Approval`, an approved new-file write, and an out-of-scope edit discovered mid-story. The expected preapproval prompt must present goal, scope, all acceptance criteria, handoff class, and verification method in one reviewable card.
- [ ] **Step 2: Confirm the old behavior fails the new cases.** In the disposable game project, invoke `$ccgs-skill-test spec dev-story`; record the new assertions that are FAIL or PARTIAL.
- [ ] **Step 3: Add the first checkpoint after Phase 2 context and dependency validation, before `Mark Story In Progress` or any programmer work.** Present one card:

  ```markdown
  Story: [path and goal]
  Scope: [files or boundaries, including Out of Scope]
  Acceptance criteria: [all criteria]
  Handoff Class: [Player-facing | Technical | Mixed]
  Verification Method: [build/test command, evidence path, and play steps if required]
  Decision: [Approve this story | Revise the story]
  ```

  On approval, persist the three fields named in Interfaces, update sprint status, then proceed. No reply or a revision request stops implementation. A resume with `Status: In Progress` and recorded approval continues without asking again. For an older In Progress story with no approval record, show the missing record and ask before further edits.
- [ ] **Step 4: Make ownership shallow and continue the whole story.** Run `$ccgs-story-readiness [story-path]` for every new Ready story before approval; skip this rerun only for an approved In Progress resume. Replace the mandatory programmer spawn in Phases 3–4 with primary-agent implementation by default. Consult one or more specialists only for a concrete engine risk or bounded expertise question, and report which ran or was skipped. Keep all current ADR, code-root, test, parse, and run-verification gates. After implementation, continue to `$ccgs-code-review` and `$ccgs-story-done` in the same task; resolve in-scope review fixes and recheck them before the final checkpoint. When an out-of-scope file or consequential decision is needed, stop before that work, append the pending decision to `production/session-state/active.md`, and ask for a revised story approval; resume only after the story and approval record reflect the decision.
- [ ] **Step 5: Reconcile shared rules narrowly.** Add a `Story execution` paragraph to `automation-modes.md`: both story checkpoints require a human response in every mode, while file edits within approved scope need no separate write permission. Keep non-story behavior unchanged. In `coordination-rules.md`, exempt ordinary story implementation from mandatory leadership tiers while preserving escalation for genuine cross-domain conflict. Update the `dev-story` contract accordingly.
- [ ] **Step 6: Mirror and verify.** Copy the dev-story skill and contract to the template; run `rtk python tests/smoke_port.py`, re-run `$ccgs-skill-test spec dev-story` in the disposable project, and run `rtk git diff --check`. Expected: approved story proceeds with one pre-checkpoint; unapproved, legacy, and scope-change cases pause correctly.
- [ ] **Step 7: Commit.** Stage only Task 2 files and commit `feat(harness): gate story implementation`.

### Task 3: Evidence and final acceptance

**Files:** `skills/ccgs-code-review/SKILL.md`, `skills/ccgs-story-done/{SKILL,CONTRACT}.md`, template mirrors, and the existing `skills/readiness/story-done.md` and `skills/analysis/code-review.md` behavioral specs in the template testing framework.

**Interfaces:** `code-review` returns a verdict to the primary agent. `story-done` consumes the approved story, review result, test/build output, run result, and player confirmation where required; it writes `Status: Complete` only after explicit game-maker acceptance in every automation mode.

- [ ] **Step 1: Add behavioral cases first.** Cover a technical story with passing test/build evidence, a player-facing story awaiting play, a Mixed story requiring both evidence sets, a failed or `NOT VERIFIED` run, and a user request for fixes. Add a code-review case showing that APPROVED returns findings without a routine `How would you like to proceed?` prompt.
- [ ] **Step 2: Confirm the old behavior fails the new cases.** Invoke `$ccgs-skill-test spec story-done` and `$ccgs-skill-test spec code-review` in the disposable project; record new FAIL/PARTIAL assertions.
- [ ] **Step 3: Keep review inside the loop.** In `ccgs-code-review`, replace Phase 9's routine user menu with a handoff to the primary agent and `$ccgs-story-done`; unresolved architecture decisions still pause. Limit specialist review to applicable bounded findings and verify their claims before reporting.
- [ ] **Step 4: Make the completion report the final checkpoint.** In `ccgs-story-done`, present this report once after internal review and before any completion-status write:

  ```markdown
  Changes: [files and player-visible result]
  Handoff Class: [Player-facing | Technical | Mixed]
  | Acceptance criterion | Evidence path or command and result | Status |
  | --- | --- | --- |
  | [criterion] | [specific observation, test output, or NOT VERIFIED: reason] | [PASS | FAIL | DEFERRED] |
  Play steps: [steps for Player-facing/Mixed; N/A for Technical]
  Review: [verdict and unresolved issues]
  Limitations: [specific gaps or None]
  Decision: [accept | request fixes | wait for play/evidence]
  ```

  Combine the existing manual-criterion, lean code-review, and close-story prompts into this final checkpoint when they do not require a changed product decision. For Player-facing/Mixed, acceptance requires the game maker to confirm they played the build or scene, even when `qa.level: minimal` or `testing.strict.visual: false`. Deferred play alone cannot yield a COMPLETE verdict. For Technical, acceptance can rely on inspectable build/test evidence. A screenshot verifies appearance but does not replace a play confirmation. Missing execution stays `NOT VERIFIED`, with the reason and an explicit human decision; never call it a pass. Keep existing blocked-verdict override behavior explicit and documented.
- [ ] **Step 5: Close only on acceptance.** Remove the autonomous auto-close branch. If the user requests fixes or has not played a required story, leave `Status: In Progress` and write the pending item to session state. On acceptance, update story status, completion notes, sprint status, and session state once. Record what the user accepted and any explicitly accepted gaps in `## Completion Notes`. Update the story-done contract and behavioral specs.
- [ ] **Step 6: Mirror and verify.** Copy the changed skills and contract to the template. Run `rtk python tests/smoke_port.py`, both behavioral specs, and `rtk git diff --check`. Expected: no duplicate routine checkpoint from code-review and no story closes without final acceptance.
- [ ] **Step 7: Commit.** Stage only Task 3 files and commit `feat(harness): require story acceptance`.

## End-to-end validation

- [ ] In a disposable copy of `assets/template/`, exercise one Player-facing story from readiness through completion. Check that approval happens before the first implementation write, the handoff provides play steps and evidence, and the story remains In Progress until the game maker reports playing and accepts.
- [ ] Exercise one Technical story. Check that build/test evidence is shown, play is not requested, and acceptance is still explicit.
- [ ] Exercise one approved story that discovers a scope change. Check that work pauses before the out-of-scope edit, the pending decision survives resume, and a revised approval is required.
- [ ] Run `rtk python tests/smoke_port.py`, `rtk git diff --check`, and `rtk git status --short`. Record exact results; do not claim runtime behavior from the smoke test alone.
