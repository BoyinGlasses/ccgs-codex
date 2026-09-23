# /create-stories — Handoff Contract

## Role in Pipeline
Decomposes a single epic into implementable story files by tracing GDD acceptance
criteria through ADR decisions and manifest rules — sits between `/create-epics`
and `/story-readiness` + `/dev-story`.

## Inputs Required

### Files That Must Exist
| File | Required Fields / Sections | Read-Only? |
|------|---------------------------|-----------|
| `production/epics/[epic-slug]/EPIC.md` | `Layer:`, `GDD:` path, `Architecture Module:`, `## Governing ADRs` table, `## GDD Requirements` table with TR-IDs | Yes |
| `design/gdd/[filename].md` | All 8 required sections, especially `## Acceptance Criteria`, `## Formulas`, `## Edge Cases` | Yes |
| `docs/architecture/adr-NNNN-[slug].md` (all governing ADRs) | `Status:`, `Decision`, `Implementation Guidelines`, `Engine Compatibility`, `Engine Notes` | Yes |
| `docs/architecture/control-manifest.md` | Layer rules (required patterns, forbidden patterns, guardrails), `Manifest Version:` date in header | Yes |
| `docs/architecture/tr-registry.yaml` | All TR-IDs for the epic's system, with stable `id` values | Yes |

### Preconditions
- `/create-epics` has been run and the target `EPIC.md` has `Status: Ready`
- The EPIC.md contains a populated `## GDD Requirements` table (not empty)
- All governing ADRs listed in the EPIC.md exist as files
- Foundation epics have stories created before Core epics are started; Core before Feature; Feature before Presentation

## Outputs Produced

### Files Written
| File | Guaranteed Fields / Sections | Notes |
|------|------------------------------|-------|
| `production/epics/[epic-slug]/story-NNN-[slug].md` | `Epic:`, `Status:`, `Layer:`, `Type:`, `Manifest Version:`, `## Context` (GDD path + `TR-[system]-NNN` + ADR reference + ADR Decision Summary + Engine/Risk + Engine Notes + Control Manifest Rules), `## Acceptance Criteria`, `## Implementation Notes`, `## Out of Scope`, `## Test Evidence`, `## Dependencies` | Created per story |
| `production/epics/[epic-slug]/EPIC.md` | `## Stories` table replacing the "Not yet created" placeholder | Updated in-place |

### Output Guarantees
- Every story file contains a `TR-[system]-NNN` reference in its `## Context` section (or `TR-[system]-???` with a warning if the registry has no match)
- Every story file contains an `ADR Governing Implementation:` line referencing at least one ADR, or an explicit `No ADR applies` note
- Every story file has a `Status:` field — either `Ready` or `Blocked` (if the governing ADR is `Proposed`)
- Every story file has a `Type:` field — one of: Logic, Integration, Visual/Feel, UI, Config/Data
- Every story file has a `Manifest Version:` field matching the date from `docs/architecture/control-manifest.md`'s header at time of writing
- Every story file has a `## Test Evidence` section stating the expected evidence location for its type
- Every story file has a `## Acceptance Criteria` section with at least one checkbox item copied from the GDD
- Every story file has a `## Dependencies` section (may say "None" but is never omitted)
- The EPIC.md `## Stories` table is updated with a row per story including `#`, `Story` title, `Type`, `Status`, and `ADR`
- Stories with a `Proposed` ADR have `Status: Blocked` and a note: `BLOCKED: ADR-NNNN is Proposed — run /architecture-decision to advance it`
- Every story file has an `Engine` and a `Risk` field. `Risk` is taken from `docs/engine-reference/<engine>/VERSION.md`; when that file is missing or assigns no level, `Risk` is **`NOT ASSESSED (no VERSION.md risk rating)`** — never a guessed level
- **`NOT ASSESSED` is an emittable value of the `Risk` field**, and downstream readers must handle it. `/dev-story` treats it as HIGH when deciding whether to spawn the engine specialist: an unknown risk is not a low one

## Immutability Rules
- READS but does NOT modify: the epic's GDD, all ADR files, `docs/architecture/tr-registry.yaml`, `docs/architecture/control-manifest.md`
- MODIFIES: `production/epics/[epic-slug]/story-NNN-[slug].md` (creates), `production/epics/[epic-slug]/EPIC.md` (updates Stories section only)

## Hard Constraints (Never Violate)
- Never start implementation — this skill stops at the story file level
- Never invent acceptance criteria — all criteria must come from the GDD
- Never invent implementation notes — all guidance must come from the referenced ADR
- Never write story files without presenting the full story list for approval first
- Never mark a story `Status: Ready` if its governing ADR has `Status: Proposed`
- Never omit the `Manifest Version:` field — downstream readiness checks depend on it
- Never reuse a story number (NNN) that already exists in the epic directory

## Downstream Skill Expects
**Next skill:** /story-readiness (then /dev-story)

It will read:
- Each `story-NNN-[slug].md` file — specifically: `Status:`, `Type:`, `Manifest Version:` (header), `TR-[system]-NNN` (in `## Context`), `ADR Governing Implementation:` line, `## Acceptance Criteria` section, `## Test Evidence` section, `## Dependencies` section
- `docs/architecture/control-manifest.md` — to compare its `Manifest Version:` against the story's embedded version
- The referenced ADR file — to verify its `Status:` field is still `Accepted`

It assumes:
- `Manifest Version:` in the story header is a date string that can be compared against the manifest's current `Manifest Version:` date
- `TR-[system]-NNN` IDs are resolvable in `docs/architecture/tr-registry.yaml`
- The ADR referenced by name in `ADR Governing Implementation:` exists as a file in `docs/architecture/` (pattern: `adr-NNNN-[slug].md`)
- `Status: Ready` means the story is a candidate for assignment (not Draft, not in progress)
- `## Acceptance Criteria` contains checkbox items that are directly testable
- `## Test Evidence` specifies an exact file path or evidence doc path where proof will be stored

## Known Fragile Points
- If the story file format (header field names, section names, checkbox syntax) changes, `/story-readiness` will silently skip checks for fields it cannot parse — stories may pass readiness that should fail
- If `control-manifest.md` is regenerated with a new `Manifest Version:` date after stories are written, all existing stories will show a stale manifest version and fail the readiness manifest check — every story in the epic will need its `Manifest Version:` updated
- If a governing ADR is renumbered or its file is renamed after stories are written, the `ADR Governing Implementation:` reference in story files will point to a missing file and `/story-readiness` will BLOCK those stories
- If `tr-registry.yaml` deprecates or supersedes a TR-ID that is already embedded in story files, `/story-readiness` will flag those stories as NEEDS WORK
- The EPIC.md Stories table update is append-style — if `/create-stories` is run twice for the same epic, duplicate rows will appear in the table
