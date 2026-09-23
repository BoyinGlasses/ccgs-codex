# Skill Test Spec: /story-done

## Skill Summary

`$ccgs-story-done` checks each acceptance criterion, GDD/ADR deviations,
test/build evidence, review outcome, and required game-maker play. It shows
one final evidence report. Only explicit game-maker acceptance can change
the story to `Status: Complete`; requests for fixes or missing play leave
it In Progress. Verdicts include COMPLETE, COMPLETE WITH NOTES,
NOT ASSESSED, and BLOCKED.

---

## Static Assertions (Structural)

Verified automatically by `/skill-test static` — no fixture needed.

- [ ] Has Codex skill frontmatter fields: `name`, `description`
- [ ] Has ≥5 phase headings (complex skill warranting `context: fork` if applicable)
- [ ] Contains verdict keywords: COMPLETE, BLOCKED
- [ ] Requires explicit game-maker acceptance in every automation mode
- [ ] Has a next-step handoff (surfaces next story from sprint)

---

## Test Cases

### Case 1: Happy Path — All acceptance criteria met, no deviations

**Fixture:**
- Story file at `production/epics/core/story-light-pickup.md` with:
  - 3 acceptance criteria, all implemented as described
  - `Handoff Class: Player-facing` and a recorded Story Approval
  - game-maker play confirmation and executed build/test evidence
  - `TR-ID: TR-light-001` referencing a GDD requirement
  - `ADR: docs/architecture/adr-003-inventory.md` (Accepted)
  - `Status: In Progress`
- Implementation files listed in story exist in `src/`
- GDD requirement text at TR-light-001 matches how the feature was implemented
- ADR guidance was followed (no deviations)

**Input:** `/story-done production/epics/core/story-light-pickup.md`

**Expected behavior:**
1. Skill reads the story file and extracts all key fields
2. Skill reads the GDD requirement fresh from `tr-registry.yaml` (not from story's quoted text)
3. Skill reads the referenced ADR to understand implementation constraints
4. Skill evaluates each acceptance criterion against executed evidence and confirmed play
5. Skill checks for GDD requirement deviations
6. Skill checks for ADR guideline deviations
7. Skill reads the available code-review outcome and includes it in the report
8. Skill presents COMPLETE verdict and the final evidence report
9. Skill asks the game maker to accept the report
10. Only after acceptance: skill updates the story file
11. Skill surfaces the next `Ready for Dev` story from the sprint

**Assertions:**
- [ ] Skill reads `docs/architecture/tr-registry.yaml` for TR-ID requirement text (not just story)
- [ ] Skill reads the referenced ADR file (not just the story reference)
- [ ] Each acceptance criterion is listed with PASS / DEFERRED / FAIL status
- [ ] Skill includes the code-review outcome in the final evidence report
- [ ] Verdict is COMPLETE when all criteria are verified and no deviations exist
- [ ] Skill waits for explicit game-maker acceptance in every automation mode
- [ ] Skill does NOT auto-update story status without user confirmation
- [ ] After completion, skill surfaces a Ready or Not Started story from
      `production/sprints/` and routes it through story-readiness before work

---

### Case 2: Deferred player-facing criterion needs play

**Fixture:**
- Story has `Handoff Class: Player-facing` and an acceptance criterion:
  "Player sees correct animation on pickup"
- No automated test for this criterion exists
- Manual verification has not been performed
- All other criteria are met

**Input:** `/story-done production/epics/core/story-light-pickup.md`

**Expected behavior:**
1. Skill processes all acceptance criteria
2. Reaches the animation criterion — cannot auto-verify
3. Skill presents play steps in the final evidence report and asks for one
   game-maker decision.
4. Until the game maker plays, criterion remains DEFERRED and story stays
   In Progress, regardless of minimal QA or advisory visual strictness.
5. Session state records pending play; no Completion Notes are written yet.

**Assertions:**
- [ ] Skill includes the deferred criterion and play steps in the final report
- [ ] Deferred play cannot produce a COMPLETE verdict
- [ ] Status remains In Progress and session state names pending play
- [ ] No separate per-criterion or status-write prompt appears

---

### Case 3: Blocked Path — GDD deviation detected

**Fixture:**
- `project.yaml` sets `modes.workflow: full`, so the GDD rules check runs.
- Story TR-ID points to requirement: "Player can carry max 3 light sources"
- Implementation in `src/` uses a variable `MAX_CARRIED_LIGHTS = 5`
- This is a deliberate deviation from the GDD

**Input:** `/story-done production/epics/core/story-light-pickup.md`

**Expected behavior:**
1. Skill reads the GDD requirement text (max 3)
2. Skill detects discrepancy between requirement and implementation value (5)
3. Skill flags the changed gameplay cap as a BLOCKING GDD deviation in the
   final report; it cannot be treated as an ordinary advisory note.
4. The game maker may request an in-scope correction, revise the governing
   design/story before continuing, or explicitly accept the named risk.
5. Until that decision and any required correction, the story stays
   In Progress.

**Assertions:**
- [ ] Skill detects the mismatch between GDD requirement and implementation value
- [ ] Skill presents the gameplay change as BLOCKING with the current GDD value
- [ ] A correction request keeps the story In Progress
- [ ] An explicit override records the original deviation and risk in Completion Notes
- [ ] No post hoc "intentional" label silently converts the deviation to PASS

---

### Case 4: Edge Case — No argument, auto-detect current story

**Fixture:**
- `production/session-state/active.md` contains a reference to
  `production/epics/core/story-oxygen-drain.md` as the active story
- That story file exists with `Status: In Progress`

**Input:** `/story-done` (no argument)

**Expected behavior:**
1. Skill reads `production/session-state/active.md`
2. Skill finds the active story reference
3. Skill reads that story file and proceeds normally
4. Output names the auto-detected story as it proceeds; this is not another
   approval checkpoint

**Assertions:**
- [ ] Skill reads `production/session-state/active.md` when no argument is given
- [ ] Skill names the auto-detected story without asking for a redundant
      confirmation when the approval record and session state agree
- [ ] If no story is found in session state, skill checks the current sprint;
      if neither source identifies one, it asks for a path

---

---

### Case 5: Director Gate — LP-CODE-REVIEW behavior across review modes

**Fixture:**
- Story file at `production/epics/core/story-light-pickup.md`
- All acceptance criteria verified, no GDD deviations
- `production/review-mode.txt` exists

**Case 5a — full mode:**
- `review-mode.txt` contains `full`

**Input:** `/story-done production/epics/core/story-light-pickup.md` (full mode)

**Expected behavior:**
1. Skill reads review mode — determines `full`
2. After implementation verification, skill invokes LP-CODE-REVIEW gate
3. Lead programmer reviews the implementation
4. If LP verdict is REJECT → verdict is BLOCKED; the story cannot be
   marked Complete by default. A separate, explicit game-maker override
   must name and record the rejected finding and risk.
5. If LP verdict is APPROVED → skill proceeds to the game-maker acceptance checkpoint

**Assertions (5a):**
- [ ] Skill reads review mode before deciding whether to invoke LP-CODE-REVIEW
- [ ] LP-CODE-REVIEW gate is invoked in full mode after implementation check
- [ ] An LP REJECT verdict prevents ordinary completion; only an explicit
      named-risk override can close despite REJECT
- [ ] Gate result is noted in output: "Gate: LP-CODE-REVIEW — [result]"
- [ ] Skill still waits for game-maker acceptance before updating story status

**Case 5b — lean or solo mode:**
- `review-mode.txt` contains `lean` or `solo`

**Expected behavior:**
1. Skill reads review mode — determines `lean` or `solo`
2. LP-CODE-REVIEW gate is SKIPPED
3. Output notes the skip: "[LP-CODE-REVIEW] skipped — Lean/Solo mode"
4. Story completion still requires game-maker acceptance

**Assertions (5b):**
- [ ] LP-CODE-REVIEW gate does NOT spawn in lean or solo mode
- [ ] Skip is explicitly noted in output
- [ ] Skill still requires explicit game-maker acceptance before marking story Complete

---

### Case 6: Technical story closes from inspectable evidence

**Fixture:** An approved In Progress story has `Handoff Class: Technical`,
passing build/test output, a clean review, and no player-visible result.

**Input:** `$ccgs-story-done production/epics/core/story-internal-tool.md`

**Expected behavior:** Show the changes, each criterion with its command/result,
review verdict, limitations, and `Play steps: N/A`. Wait for the game maker
to accept. Only then write Complete and completion notes.

**Assertions:**
- [ ] A technical story does not require a play session.
- [ ] The evidence report appears before the acceptance prompt.
- [ ] No automation mode closes the story without explicit acceptance.

---

### Case 7: Player-facing story waits for play

**Fixture:** An approved Logic story has `Handoff Class: Player-facing`,
passing unit test and a retained screenshot of an enemy hit reaction. The game
maker has not played it. `qa.level: minimal` or
`testing.strict.visual: false` may be set.

**Input:** `$ccgs-story-done production/epics/core/story-hit-reaction.md`

**Expected behavior:** Present short playable setup/steps and the evidence.
Report play as pending. A screenshot and passing test do not count as game-maker
play. Leave In Progress until the game maker reports playing and accepts.

**Assertions:**
- [ ] The game maker must confirm play even at minimal QA or advisory visual strictness.
- [ ] Deferred play cannot yield a COMPLETE verdict.
- [ ] Status remains In Progress while play or acceptance is pending.

---

### Case 8: Mixed story requires both evidence sets

**Fixture:** An approved story has `Handoff Class: Mixed`, a visible UI
change, and a separate internal migration criterion. The UI screenshot and
play confirmation exist, but the migration test did not run.

**Input:** `$ccgs-story-done production/epics/core/story-shop-ui.md`

**Expected behavior:** Report the migration criterion as
`NOT VERIFIED — test runner unavailable`, keep the play confirmation and
visual evidence separate, and ask the game maker whether to wait or explicitly
accept the gap. Never label the migration test PASS.

**Assertions:**
- [ ] Mixed story needs both play confirmation and technical evidence.
- [ ] Unrun technical check is NOT VERIFIED, not PASS.
- [ ] An accepted gap is named in Completion Notes.

---

### Case 9: Failed or unverified run and request for fixes

**Fixture:** An approved Player-facing story has a failed run or
`Run result: NOT VERIFIED — engine unavailable`. The game maker requests a fix.

**Input:** `$ccgs-story-done production/epics/core/story-camera.md`

**Expected behavior:** Show the failure or missing execution with its reason,
offer a fix or wait path in the final checkpoint, keep Status In Progress,
and record the pending item in session state. The primary agent continues
in-scope fixes in the same story.

**Assertions:**
- [ ] Missing execution is never reported as PASS.
- [ ] A request for fixes does not close the story.
- [ ] The pending fix survives task resumption.
- [ ] No separate manual-criterion, lean-review, and close prompts precede the final checkpoint.

---

## Protocol Compliance

- [ ] Requires game-maker acceptance before status and completion-note writes
- [ ] Logs tech debt only when the game maker explicitly requests it
- [ ] Presents complete findings (criteria check, deviation check) before asking approval
- [ ] Ends by surfacing the next ready story from the sprint plan
- [ ] Does not mark a story Complete if any criteria are in ERROR state
- [ ] Includes the code-review result in the single final evidence report

---

## Coverage Notes

- The full 8-phase flow of the skill is exercised across Cases 1-3; not all
  edge cases within each phase are covered.
- Tech debt logging (deferred items written to `docs/tech-debt-register.md`)
  is mentioned in Case 2 but not the primary assertion focus; dedicated
  coverage deferred.
- The `sprint-status.yaml` update (Phase 7 in the skill) is implied by Case 1
  but not the primary assertion; the final story acceptance covers it.
- Stories with multiple TR-IDs or multiple ADRs are not explicitly tested.
