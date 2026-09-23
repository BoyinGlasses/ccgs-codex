# /create-epics — Handoff Contract

## Role in Pipeline
Translates approved GDDs and architecture documents into one EPIC.md file per
architectural module, defining scope, ADR governance, engine risk, and requirement
traceability — sits between architecture review and story decomposition.

## Inputs Required

### Files That Must Exist
| File | Required Fields / Sections | Read-Only? |
|------|---------------------------|-----------|
| `design/gdd/systems-index.md` | System list, layer assignments, priority order | Yes |
| `design/gdd/[system].md` | `## Summary`, `## Acceptance Criteria`, `## Overview` (all 8 required sections) | Yes |
| `docs/architecture/architecture.md` | Module ownership, API boundaries | Yes |
| `docs/architecture/adr-NNNN-[slug].md` (all governing ADRs) | `Status:`, `GDD Requirements Addressed`, `Decision`, `Engine Compatibility` | Yes |
| `docs/architecture/control-manifest.md` | `Manifest Version:` date in header | Yes |
| `docs/architecture/tr-registry.yaml` | TR-IDs with `id`, `system`, requirement text | Yes |
| `docs/engine-reference/[engine]/VERSION.md` | Engine name, version, risk levels | Yes |

### Preconditions
- `/create-control-manifest` has been run and `docs/architecture/control-manifest.md` exists
- `/architecture-review` has passed (at minimum Foundation and Core ADRs are Accepted)
- All in-scope GDDs have status `Approved` or `Designed` in `systems-index.md`
- The target layer's GDDs are stable — do not run for Feature layer until Core is nearly complete

## Outputs Produced

### Files Written
| File | Guaranteed Fields / Sections | Notes |
|------|------------------------------|-------|
| `production/epics/[epic-slug]/EPIC.md` | `Layer`, `GDD` path, `Architecture Module`, `Status: Ready`, `## Governing ADRs` table, `## GDD Requirements` table with TR-IDs and ADR coverage, `## Definition of Done`, `## Overview` | Created per approved epic |
| `production/epics/index.md` | `Epic`, `Layer`, `System`, `GDD`, `Stories`, `Status` columns | Created or appended |

### Output Guarantees
- Every EPIC.md contains a `## Governing ADRs` table with at least one row (or a documented note if none apply)
- Every EPIC.md contains a `## GDD Requirements` table where each row has a `TR-ID` and an `ADR Coverage` cell (either `ADR-NNNN ✅` or `❌ No ADR`)
- The `GDD:` field in the EPIC.md header is a valid relative path to the source GDD
- The `Layer:` field is one of: Foundation, Core, Feature, Presentation
- The `Status:` field is set to `Ready`
- The `Stories:` field reads `Not yet created — run /create-stories [epic-slug]`
- Untraced requirements (TR-IDs with no ADR) are flagged in the GDD Requirements table with `❌ No ADR`
- `production/epics/index.md` has an entry for every epic written in this run

## Immutability Rules
- READS but does NOT modify: `design/gdd/systems-index.md`, all GDD files, `docs/architecture/architecture.md`, all ADR files in `docs/architecture/adr-NNNN-[slug].md` pattern, `docs/architecture/control-manifest.md`, `docs/architecture/tr-registry.yaml`, `docs/engine-reference/[engine]/VERSION.md`
- MODIFIES: `production/epics/[epic-slug]/EPIC.md` (creates), `production/epics/index.md` (creates or updates)

## Hard Constraints (Never Violate)
- Never create story files — this skill stops at the epic level
- Never invent content not sourced from GDDs, ADRs, or architecture docs
- Never skip the per-epic approval prompt before writing
- Never write an EPIC.md without first presenting the epic definition to the user
- Never mark a TR-ID as covered by an ADR unless that ADR's `Status:` is `Accepted`
- Never create epics for a layer whose dependency layer is not yet substantially complete

## Downstream Skill Expects
**Next skill:** /create-stories

It will read:
- `production/epics/[epic-slug]/EPIC.md` — specifically: `Layer:`, `GDD:` path, `Architecture Module:`, the full `## Governing ADRs` table (ADR IDs and summaries), and the full `## GDD Requirements` table (TR-IDs and ADR coverage status)
- `production/epics/index.md` — to enumerate available epics when no argument is given

It assumes:
- The `GDD:` path in EPIC.md resolves to a readable file
- Every ADR listed in `## Governing ADRs` exists as a file and has an `Accepted` status
- TR-IDs in `## GDD Requirements` match entries in `docs/architecture/tr-registry.yaml`
- The epic slug used in the directory name matches the slug referenced in `index.md`
- `Status: Ready` means stories have NOT yet been created (it will replace this line)

## Known Fragile Points
- If the EPIC.md template structure changes (section names, header field names, table column order), `/create-stories` will silently fail to parse governance data and may produce incomplete or incorrect stories
- If `tr-registry.yaml` is regenerated with renumbered IDs after EPIC.md files are written, the TR-IDs in existing EPIC.md files become stale and mislead `/create-stories`
- If an ADR is retroactively changed from `Accepted` to `Proposed` after the epic is written, the EPIC.md will still show it as governing — `/create-stories` will embed it without a BLOCKED flag
- If `systems-index.md` layer assignments change after epics are created, the `Layer:` field in existing EPIC.md files will be incorrect and `/create-stories` will use the wrong layer context
- `production/epics/index.md` is append-updated — if an epic is regenerated, a duplicate row may appear
