# Skill Test Spec: /code-review

## Skill Summary

`$ccgs-code-review` reviews source files against the project's coding
standards, governing ADRs, architecture, testability, and game concerns.
It writes no files. The primary agent owns the verdict and may consult a
specialist for a bounded finding. An approved review returns to the
story loop without a routine game-maker prompt.

---

## Static Assertions (Structural)

Verified automatically by `/skill-test static` — no fixture needed.

- [ ] Has Codex skill frontmatter fields: `name`, `description`
- [ ] Has ≥2 phase headings
- [ ] Contains verdict keywords: APPROVED, APPROVED WITH SUGGESTIONS,
      CHANGES REQUIRED, NOT ASSESSED
- [ ] Does NOT require "May I write" language (read-only; findings are advisory output)
- [ ] Has a next-step handoff (what to do with findings)

---

## Director Gate Checks

The skill itself has no mandatory director gate. Bounded specialist review
may run for an applicable engine or QA concern; an unresolved architecture
decision pauses for the game maker.

---

## Test Cases

### Case 1: Happy Path — Source file follows all coding standards

**Fixture:**
- `src/gameplay/health_component.gd` exists with:
  - All public methods have doc comments (`##` notation)
  - No singletons used; dependencies injected via constructor
  - No hardcoded values; all constants reference `assets/data/`
  - ADR reference in file header: `# ADR: docs/architecture/adr-004-health.md`
  - Referenced ADR has `Status: Accepted`

**Input:** `/code-review src/gameplay/health_component.gd`

**Expected behavior:**
1. Skill reads the source file
2. Skill checks all coding standards: doc comments, DI, data-driven, ADR status
3. All checks pass
4. Skill outputs the overall standards score and an APPROVED verdict
5. Verdict is APPROVED

**Assertions:**
- [ ] The standards score reflects the clean fixture
- [ ] Skill reads referenced ADR to confirm its status
- [ ] Verdict is APPROVED
- [ ] No edits are made to any file

---

### Case 2: Needs Changes — Missing doc comment and singleton usage

**Fixture:**
- `src/ui/inventory_ui.gd` has:
  - 2 public methods without doc comments
  - Uses `GameManager.instance` (singleton pattern)
  - All other standards met

**Input:** `/code-review src/ui/inventory_ui.gd`

**Expected behavior:**
1. Skill reads the source file
2. Skill detects: 2 missing doc comments on public methods
3. Skill detects: singleton usage at specific lines (e.g., line 42, line 87)
4. Findings identify the issue types with supporting locations
5. Verdict is CHANGES REQUIRED

**Assertions:**
- [ ] Missing doc comments are identified
- [ ] Singleton usage is flagged with file and line number
- [ ] Verdict is CHANGES REQUIRED when blocking standard violations exist
- [ ] Skill does not edit the file — findings are for the developer to act on

---

### Case 3: Architecture Risk — ADR reference is Proposed, not Accepted

**Fixture:**
- `src/core/save_system.gd` has a header comment: `# ADR: docs/architecture/adr-010-save.md`
- `adr-010-save.md` exists but has `Status: Proposed`
- Code itself follows all other coding standards

**Input:** `/code-review src/core/save_system.gd`

**Expected behavior:**
1. Skill reads the source file
2. Skill reads referenced ADR — finds `Status: Proposed`
3. Skill flags this as ARCHITECTURE RISK (code is implementing an unaccepted ADR)
4. Other coding standard checks pass
5. Verdict is CHANGES REQUIRED because the architecture decision is
   unresolved; the primary agent pauses for the game maker.

**Assertions:**
- [ ] Skill reads referenced ADR file to check its status
- [ ] ARCHITECTURE RISK is flagged when ADR status is Proposed
- [ ] Verdict is CHANGES REQUIRED for an unresolved Proposed ADR
- [ ] The active story pauses for the game maker's architecture decision
- [ ] Output recommends resolving the ADR before the code goes to production

---

### Case 4: Edge Case — No source files found at specified path

**Fixture:**
- User calls `/code-review src/networking/`
- `src/networking/` directory does not exist

**Input:** `/code-review src/networking/`

**Expected behavior:**
1. Skill attempts to read files in `src/networking/`
2. Directory or files not found
3. Skill outputs an error: "No source files found at `src/networking/`"
4. Verdict is `NOT ASSESSED — NO DATA` (nothing was reviewed)

**Assertions:**
- [ ] Skill does not crash when path does not exist
- [ ] Output names the attempted path in the error message
- [ ] No APPROVED or clean verdict is emitted when there is nothing to review
- [ ] The output reports NOT ASSESSED and names the missing path

---

### Case 5: Gate Compliance — No gate; LP may be consulted separately

**Fixture:**
- Source file follows most standards but has 1 CONCERNS-level finding (a magic number)
- `review-mode.txt` contains `full`

**Input:** `/code-review src/gameplay/loot_system.gd`

**Expected behavior:**
1. Skill reads and reviews the source file
2. No director gate is invoked (code review findings are advisory)
3. Skill presents findings with APPROVED WITH SUGGESTIONS.
4. If architecture expertise is needed, it may consult a specialist on a
   named bounded question and verifies the finding before reporting it.
5. No routine game-maker menu is opened for the advisory finding.

**Assertions:**
- [ ] No mandatory director gate is invoked by this skill
- [ ] A specialist, if used, gets a bounded question
- [ ] No code edits are made
- [ ] Verdict is APPROVED WITH SUGGESTIONS for advisory-level findings

---

### Case 6: Approved review returns to the primary agent

**Fixture:** A code story has a passing review with no unresolved architecture
decision. The primary agent is carrying an approved story through to the
final acceptance checkpoint.

**Input:** `$ccgs-code-review src/gameplay/hit_reaction.gd`

**Expected behavior:** The skill reports its findings and APPROVED verdict to
the primary agent. It does not ask the game maker how to proceed merely
because review completed. The primary agent continues to
`$ccgs-story-done [story-path]`.

**Assertions:**
- [ ] APPROVED review emits no routine user-choice menu.
- [ ] The review returns a clear verdict and findings to the primary agent.
- [ ] An unresolved architecture decision still pauses and seeks a decision.

---

## Protocol Compliance

- [ ] Reads source file(s) and coding standards before reviewing
- [ ] Provides evidence for any standards failures it reports
- [ ] Does not edit any source files (read-only skill)
- [ ] No mandatory director gate is invoked by this skill
- [ ] Verdict is one of: NOT ASSESSED, APPROVED,
      APPROVED WITH SUGGESTIONS, CHANGES REQUIRED

---

## Coverage Notes

- Batch review of all files in a directory is not explicitly tested; behavior
  is assumed to apply the same checks file by file and aggregate the verdict.
- Test coverage checks (verifying corresponding test files exist) are a stretch
  goal not tested here; that is primarily the domain of `/test-evidence-review`.
