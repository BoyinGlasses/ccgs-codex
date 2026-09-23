# Skill Test Spec: /dev-story

## Skill Summary

`$ccgs-dev-story` is the entry point for one story. It checks readiness, loads
the governing context, presents one approval card, implements within that
approved scope, verifies the result, and continues to `$ccgs-code-review`
and `$ccgs-story-done`. The primary Codex agent owns the work. A specialist
is consulted only for a bounded question that needs its expertise.
`$ccgs-story-done` owns the final acceptance and Complete status.

## Test Cases

### Case 1: Ready story needs approval before any implementation write

**Fixture:**
- A story has `Status: Ready`, valid context and dependencies, acceptance
  criteria, `Handoff Class: Technical`, and a concrete Verification Method.
- The readiness check returns READY.
- The governing ADR is Accepted.

**Input:** `$ccgs-dev-story production/epics/core/story-damage.md`

**Expected behavior:**
1. Read the story and required context; run story-readiness.
2. Show one card with story goal, in/out-of-scope files, every criterion, handoff
   class, and verification method.
3. Wait for `Approve this story` or `Revise the story`.
4. Only after approval, record `Story Approval`, mark In Progress, implement,
   run the prescribed checks, then continue to code-review and story-done.
5. Do not set Complete; story-done owns that status.

**Assertions:**
- [ ] No status, source, or test write precedes story approval.
- [ ] The approval card contains all five required parts.
- [ ] No reply or `Revise the story` stops implementation.
- [ ] Approval is recorded in the story and session state before implementation.
- [ ] The primary agent can implement directly; a programmer spawn is not mandatory.
- [ ] Routine code and test files within approved scope need no further write prompt.
- [ ] The same task continues through review and completion handoff.

---

### Case 2: Proposed ADR blocks before the approval card

**Fixture:** A Ready story references an ADR with `Status: Proposed`.

**Input:** `$ccgs-dev-story production/epics/core/story-damage.md`

**Expected behavior:** Report BLOCKED with the ADR path and recommend
`$ccgs-architecture-decision`. Do not ask the user to approve an unready story,
change status, or start implementation.

**Assertions:**
- [ ] The proposed ADR is named in the blocker.
- [ ] No approval card or implementation write occurs.

---

### Case 3: A legacy story gets a proposed handoff at approval

**Fixture:** A story passes its legacy readiness checks, but has no
`Handoff Class` or `Verification Method`. Its Logic acceptance criteria
describe an enemy hit reaction visible in play.

**Input:** `$ccgs-dev-story production/epics/core/story-hit-reaction.md`

**Expected behavior:** Propose Player-facing and concrete build/test and play
steps in the approval card. On approval, persist both fields and the approval
date before writing implementation files. Do not silently classify Logic as
Technical.

**Assertions:**
- [ ] The proposed class is Player-facing, not Technical.
- [ ] The proposed method includes a configured build/test command, play steps,
      and an evidence path.
- [ ] Both fields are recorded only after the game maker approves the story.

---

### Case 4: Resumption respects the approval record

**Fixture A:** `Status: In Progress` and `Story Approval` is recorded in the
story; session state names the same story and has no pending decision.

**Fixture B:** `Status: In Progress` but no approval is recorded.

**Input:** `$ccgs-dev-story`

**Expected behavior:** For A, resume from session state without repeating the
story approval checkpoint. For B, show the missing approval record and ask
before any further implementation edits.

**Assertions:**
- [ ] A does not ask for the same approval again.
- [ ] B does not infer approval from In Progress status.
- [ ] A pending decision in session state prevents automatic resumption.

---

### Case 5: Scope change pauses before the edit

**Fixture:** The approved story excludes `src/networking/`, but meeting a
criterion now requires changing `src/networking/replication.gd`.

**Input:** Continue `$ccgs-dev-story` for the approved story.

**Expected behavior:** Stop before changing that file, append the pending
decision and affected path to `production/session-state/active.md`, present
the revised scope, and wait. On approval, update the story and approval record
before resuming.

**Assertions:**
- [ ] The out-of-scope file is untouched before the new decision.
- [ ] The pending decision survives a resumed session.
- [ ] No in-scope implementation is discarded while waiting.

---

### Case 6: Bounded specialist consultation

**Fixture:** A Godot C# story has a specific post-cutoff engine API risk.

**Input:** `$ccgs-dev-story production/epics/core/story-save.md`

**Expected behavior:** The primary agent owns implementation and may consult
`godot-csharp-specialist` about the named API risk. It reports whether that
consultation ran or was skipped and retains the existing engine verification
checks.

**Assertions:**
- [ ] No mandatory leadership hierarchy is used for ordinary implementation.
- [ ] The specialist has a bounded question, not ownership of the whole story.
- [ ] A missing specialist does not silently remove the engine verification gate.

---

### Case 7: Approval snapshot detects same-day scope drift

**Fixture:** A story is In Progress with `Story Approval: 2026-09-23`.
The latest session-state approval extract excludes
`src/networking/replication.gd`. The story text now includes that file,
but the approval date is still 2026-09-23.

**Input:** Resume `$ccgs-dev-story` for that story.

**Expected behavior:** Compare current scope and acceptance criteria against
the latest approval extract. The matching date alone does not prove the
changed scope was approved. Pause before editing the newly included file and
show the revised approval card.

**Assertions:**
- [ ] Same-day story edits do not bypass the checkpoint.
- [ ] The latest approved scope and criteria are the comparison baseline.
- [ ] No out-of-scope edit occurs before revised approval.

---

## Protocol Compliance

- [ ] Every new Ready story runs readiness before approval.
- [ ] Both story checkpoints require the game maker in every automation mode.
- [ ] Approved routine file edits require no separate file permission.
- [ ] The story is never marked Complete by dev-story.
- [ ] Skipped specialists and verification steps are named in the output.
