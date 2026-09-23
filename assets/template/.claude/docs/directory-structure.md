# Directory Structure

```text
/
├── CLAUDE.md                    # Master configuration
├── project.yaml                 # Machine-readable project config — engine, modes, stage (source of truth)
├── .claude/                     # Agent definitions, skills, hooks, rules, docs
├── <code root>/                 # Game source code — THE PATH IS ENGINE-SPECIFIC, see below
├── assets/                      # Game assets (art, audio, vfx, shaders, data)
├── design/                      # Game design documents (gdd, narrative, levels, balance)
├── docs/                        # Technical documentation (architecture, api, postmortems)
│   └── engine-reference/        # Curated engine API snapshots (version-pinned)
├── tests/                       # Game test suites (unit, integration, performance, playtest)
├── tools/                       # Build and pipeline tools (ci, build, asset-pipeline)
├── prototypes/                  # Throwaway prototypes (isolated from src/)
├── production/                  # Production management (sprints, milestones, releases)
│   ├── session-state/           # Ephemeral session state (active.md — gitignored)
│   └── session-logs/            # Session audit trail (gitignored)
└── CCGS Skill Testing Framework/ # QA for the skills/agents themselves — /skill-test, /skill-improve
```

## The code root is engine-specific

**Two of the three supported engines will not build a project whose code sits in
`src/`.** This is not a style preference — it is a hard constraint of the engine's
own toolchain:

| `engine.name` | Code root | Why it cannot be `src/` |
|---|---|---|
| **Godot** | `src/` | No constraint — Godot loads from `res://` anywhere under the project root. |
| **Unity** | `Assets/` | Unity compiles **only** `Assets/` and `Packages/`. Code outside them is invisible to the compiler. |
| **Unreal** | `Source/<Module>/` | UnrealBuildTool discovers modules under `Source/`; content lives in `Content/`. A module elsewhere is not built. |

**Resolve the code root from `engine.name` before writing any source file.** Where
a skill, rule or template says `src/`, read it as *"the code root"* and substitute
the row above. `src/` is the table's Godot row, not a universal path.

> **Known residual — do not read `src/` as settled.** Roughly 30 files under
> `.claude/` still name `src/` literally, because they were written when Godot was
> the only engine walked end to end. They are correct for Godot and wrong for the
> other two. This section is the authority; those files are the default. The
> breakage is real, not theoretical — a Unity tree laid out this way does not
> compile, and an Unreal one produces a module no `.uproject` can consume.
