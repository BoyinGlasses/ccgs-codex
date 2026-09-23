#!/bin/bash

# --- work from the project root ----------------------------------------------
# Every path below is repo-relative, so a hook invoked with a working directory
# that is not the repo root would silently read and write the WRONG TREE --
# returning a near-empty result instead of the session-recovery block, and
# creating stray trees such as docs/production/session-logs/ on write.
#
# PRECEDENCE IS LOAD-BEARING. A cwd that IS a project root carries real
# information and must win: a caller sitting inside another project means that
# project, not this one. Resolving to the script's own location first would
# override them. So, in order:
#   1. cwd holds project.yaml   -> cwd   (a project root)
#   2. cwd holds .claude/       -> cwd   (a project root not yet configured)
#   3. CLAUDE_PROJECT_DIR       -> that  (populated in the hook environment)
#   4. this script's location   -> <root>/.claude/hooks/../.. by construction
# Rule 4 always works and needs no environment at all; rules 1-2 stop it from
# overriding a caller that legitimately means somewhere else.
#
# NOT an upward search: that resolves a nested project to its parent's config.
if [ -f "project.yaml" ] || [ -d ".claude" ]; then
  CCGS_ROOT="$PWD"
elif [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR}" ]; then
  CCGS_ROOT="$CLAUDE_PROJECT_DIR"
else
  CCGS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
fi
[ -n "$CCGS_ROOT" ] && cd "$CCGS_ROOT" 2>/dev/null || true

# Claude Code PreToolUse hook: Validates git commit commands
# Receives JSON on stdin with tool_input.command
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)
#
# Input schema (PreToolUse for Bash):
# { "tool_name": "Bash", "tool_input": { "command": "git commit -m ..." } }

INPUT=$(cat)

# Parse command -- use jq if available, fall back to grep
if command -v jq >/dev/null 2>&1; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
    COMMAND=$(echo "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# Only process git commit commands
if ! echo "$COMMAND" | grep -qE '^git[[:space:]]+commit'; then
    exit 0
fi

# Resolve a Python interpreter ONCE for every batched check below. Both the
# blocking JSON scan and the advisory design scan must not spawn one process per
# item; they spawn one each, and share this lookup.
_VC_PY=""
for _c in python python3 py; do
    if command -v "$_c" >/dev/null 2>&1; then _VC_PY="$_c"; break; fi
done

# Get staged files
STAGED=$(git diff --cached --name-only 2>/dev/null)
if [ -z "$STAGED" ]; then
    exit 0
fi

WARNINGS=""

# Section findings are collected through a file, not a variable: the loops below
# run inside pipelines, and a subshell cannot assign to WARNINGS in the parent.
# The scratch file must actually be WRITABLE, and that has to be tested rather
# than assumed. `mktemp` and the `${TMPDIR:-/tmp}` fallback beside it both aim
# at /tmp, which does not exist or is not writable in several environments this
# hook runs in -- notably sandboxed Windows shells. When the redirect failed,
# `[ -s "$TMP_DESIGN" ]` was false, the design-section scan emitted nothing, and
# the hook exited 0: a check that could not run, reporting clean.
#
# So: try mktemp, then TMPDIR, then the repo own .git directory (writable by
# definition -- `git diff --cached` has already succeeded against it), and PROVE
# each candidate by writing to it. If none works, TMP_DESIGN stays empty and the
# scan announces that it did not run instead of skipping in silence.
TMP_DESIGN=""
for _cand in "$(mktemp 2>/dev/null)" "${TMPDIR:+$TMPDIR/ccgs-commit-$$}" \
             "$(git rev-parse --git-dir 2>/dev/null)/ccgs-commit-$$"; do
    [ -z "$_cand" ] && continue
    if : > "$_cand" 2>/dev/null; then TMP_DESIGN="$_cand"; break; fi
done
trap '[ -n "$TMP_DESIGN" ] && rm -f "$TMP_DESIGN"' EXIT

# ---------------------------------------------------------------------------
# BLOCKING CHECK FIRST. Everything below this block is advisory:
# it appends to $WARNINGS and the hook still exits 0. This block is the only one
# that can exit 2, and exit 2 is the entire reason the hook is registered.
#
# Running it THIRD, after the design-section scan, and validating one file
# per `python -m json.tool` invocation -- one interpreter spawn each, ~110ms on
# Windows -- gets the hook killed by its 15s timeout on a large commit before
# it reaches the corrupt file, so whether a bad file is caught depends on where
# its NAME SORTED. Measured with 201 staged files and one corrupt:
#
#   corrupt sorts FIRST -> 730ms,   rc=2,   BLOCKED emitted
#   corrupt sorts LAST  -> 15217ms, rc=124, nothing emitted, commit not blocked
#
# Two independent fixes, because either alone is a mitigation rather than a
# guarantee:
#   (a) ORDER. The blocking check runs before any advisory work, so a starved
#       hook has already done the part that matters.
#   (b) COST. One interpreter validates every staged JSON file, so the check is
#       constant in file count instead of linear. The one-subprocess-per-item
#       shape has caused this same starvation more than once; batching is the
#       only fix that holds.
#
# Making it merely faster is not enough -- the cost stays linear and the hook
# starves again at a larger file count. Batch it, or it returns.
# ---------------------------------------------------------------------------
DATA_FILES=$(echo "$STAGED" | grep -E '^assets/data/.*\.json$')
if [ -n "$DATA_FILES" ]; then
    PYTHON_CMD="$_VC_PY"
    if [ -n "$PYTHON_CMD" ]; then
        # One spawn, all files. The file list arrives on stdin so an unbounded
        # number of paths cannot overflow the argument limit.
        BAD_JSON=$(printf '%s\n' "$DATA_FILES" | "$PYTHON_CMD" -c '
import json, sys, os
bad = []
for line in sys.stdin.read().splitlines():
    path = line.strip()
    if not path or not os.path.isfile(path):
        continue
    try:
        with open(path, "r", encoding="utf-8-sig") as fh:
            json.load(fh)
    except Exception:
        bad.append(path)
# Bytes, not text. Python text-mode stdout on Windows rewrites \n as \r\n,
# putting a CR inside every path but the last. Invisible in a terminal and in
# a line-by-line diff -- only a byte comparison against the pre-batch
# implementation surfaced it. get_yaml_key writes bytes for the same reason.
sys.stdout.buffer.write("\n".join(bad).encode("utf-8"))
' 2>/dev/null)
        if [ -n "$BAD_JSON" ]; then
            # Every offender at once. The per-file loop reported only the first
            # and exited, so a commit with several bad files took several
            # round-trips to clean up.
            echo "$BAD_JSON" | while IFS= read -r bad; do
                [ -n "$bad" ] && echo "BLOCKED: $bad is not valid JSON" >&2
            done
            exit 2
        fi
    else
        echo "WARNING: Cannot validate JSON (python not found)" >&2
    fi
fi

# Check design documents for the sections REQUIRED AT THIS PROJECT'S TIER.
#
# Demanding all 8 sections unconditionally would contradict
# .claude/docs/coding-standards.md and workflow-modes.md: the required count is
# a function of `modes.workflow` -- 8 at `full`, 5 (+ conditional Formulas) at
# `standard`, and no GDD requirement at all at `minimal`. A jam project on the
# recommended `minimal` tier was being warned about six sections its own
# configuration says it does not need, which trains the user to ignore the hook.
# Source the config helper ONCE, ahead of every consumer below. It was
# previously sourced inside the design-doc branch, so the code scans further
# down -- which now need resolve_code_root -- could not reach it on a commit
# that staged no GDD.
# Detect success by asking whether the function EXISTS, not by the source's exit
# status. A sourced file returns the status of its last statement, which here is
# incidental -- gating on it left _VC_HELPER at 0 on a perfectly good source, the
# workflow tier silently stayed at its "standard" fallback, and the GDD section
# check stopped scaling with the tier (caught by test LL.9).
_VC_HELPER=0
if [ -f .claude/hooks/yaml-helper.sh ]; then
    . .claude/hooks/yaml-helper.sh 2>/dev/null || true
    command -v resolve_setting >/dev/null 2>&1 && _VC_HELPER=1
fi

DESIGN_FILES=$(echo "$STAGED" | grep -E '^design/gdd/')
if [ -n "$DESIGN_FILES" ]; then
    WORKFLOW="standard"
    if [ "$_VC_HELPER" = 1 ]; then
        W=$(resolve_setting modes.workflow 2>/dev/null | cut -f1)
        [ -n "$W" ] && WORKFLOW="$W"
    fi

    # "Detailed" (not "Detailed Rules") because the canonical heading has a
    # documented alias, "Detailed Design" -- workflow-modes.md says not to treat
    # one as missing when the other is present.
    case "$WORKFLOW" in
        minimal) REQUIRED="" ;;
        full)    REQUIRED="Overview|Player Fantasy|Detailed|Formulas|Edge Cases|Dependencies|Tuning Knobs|Acceptance Criteria" ;;
        *)       REQUIRED="Overview|Detailed|Edge Cases|Dependencies|Acceptance Criteria" ;;
    esac

    if [ -n "$REQUIRED" ]; then
        # One pass for every file x section pair.
        #
        # A nested shell loop -- for each staged design doc, `echo |
        # tr | while read` then one `grep -qi` per required section -- does not
        # scale. At
        # workflow=full that is 8 greps per file, and each is a process. 50
        # design docs measured 14644ms -- 97% of this hook's 15s budget, from
        # the ADVISORY half alone. 50 GDDs is an ordinary project, not a
        # stress case.
        #
        # Matching is unchanged on purpose: case-insensitive SUBSTRING anywhere
        # in the file, exactly what `grep -qi "$section"` did. It is looser than
        # a heading check, and tightening it here would silently change which
        # documents warn -- a behaviour change smuggled inside a performance
        # fix. If that wants tightening it should be its own change with its
        # own test.
        printf '%s\n' "$DESIGN_FILES" | "${_VC_PY:-python}" -c '
import sys, os
argv = sys.argv
required = [x for x in argv[1].split("|") if x]
workflow = argv[2]
out = []
for line in sys.stdin.read().splitlines():
    path = line.strip()
    if not path or not path.endswith(".md") or not os.path.isfile(path):
        continue
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            body = fh.read().lower()
    except OSError:
        continue
    for section in required:
        if section.lower() not in body:
            out.append("DESIGN: %s missing section required at workflow=%s: %s"
                       % (path, workflow, section))
if out:
    # Bytes, not text -- see the CRLF note in the JSON scan above.
    sys.stdout.buffer.write(("\n".join(out) + "\n").encode("utf-8"))
' "$REQUIRED" "$WORKFLOW" > "$TMP_DESIGN" 2>/dev/null
        if [ -z "$TMP_DESIGN" ]; then
            # Obligation 3 of .claude/rules/skill-authoring.md: a skipped step
            # announces itself. Silence here is indistinguishable from a GDD
            # that already has every section its tier requires.
            WARNINGS="$WARNINGS\nSKIPPED: no writable scratch location, so the GDD section check did NOT run on the staged design doc(s)."
        elif [ -s "$TMP_DESIGN" ]; then
            WARNINGS="$WARNINGS\n$(cat "$TMP_DESIGN")"
        fi
    fi
fi

# Check for hardcoded gameplay values in gameplay code
# Uses grep -E (POSIX extended) instead of grep -P (Perl) for cross-platform compatibility
#
# Batched through xargs. Run one `grep` per staged file -- a process each,
# ~60ms on Windows -- and 400 staged gameplay files blow a 15s budget on their
# own. `xargs` packs as many
# paths into each grep as ARG_MAX allows, so the spawn count is bounded by total
# path length rather than by file count.
#
# `-l` not `-q`: with many files per invocation the exit status can no longer
# say WHICH matched, and the warning names the file. It stays a test, not a
# report -- `-l` prints only names, never matched lines, which is what the -q
# comment here was guarding against.
#
# NUL-delimited, NOT `-d '\n'`: both `-d` and `-r` are GNU-only extensions.
# BSD xargs (macOS) rejects `-d`, and because this pipeline ends in
# `2>/dev/null || true` the rejection is SILENT -- the check returns empty and
# reports nothing found, which is indistinguishable from a clean scan. README
# claims these hooks run on macOS, so a silent no-op there is a false pass.
# `-0` exists in both GNU and BSD xargs. `-r` is dropped, not replaced: both
# callers below reach xargs only inside `if [ -n ... ]`, so the empty-input case
# it guarded cannot occur. `|| true` stays -- grep exits 1 on no match, which is
# the normal case and not an error.
# --- resolve the code root before either scan below ------------------------
#
# Both scans used to be hardcoded to `^src/gameplay/` and `^src/`. Per
# .claude/docs/directory-structure.md, `src/` is the GODOT row of the code-root
# table -- Unity compiles only `Assets/`, Unreal builds only from `Source/`. So
# on two of the three supported engines both greps matched nothing on every
# commit, both checks silently did not run, and the hook exited 0. A scan that
# cannot run and a scan that found nothing produced the identical artifact.
#
# The `/gameplay/` narrowing is dropped rather than translated: it describes a
# Godot source layout and has no Unity or Unreal equivalent, so keeping it would
# leave the check Godot-only by a second route. The hardcoded-value scan instead
# widens to the whole code root and is bounded by source-code EXTENSION, which
# is what actually keeps it precise -- without it, a Unity commit would drag
# `.meta`, `.asset` and `.prefab` YAML (all full of `speed: 5`) into a scan
# meant for code, and a hook that cries wolf gets muted rather than fixed.
CODE_ROOT=""; CODE_ROOT_SRC="unset"
if [ "$_VC_HELPER" = 1 ]; then
    _CR=$(resolve_code_root 2>/dev/null)
    CODE_ROOT=$(printf '%s' "$_CR" | cut -f1)
    CODE_ROOT_SRC=$(printf '%s' "$_CR" | cut -f2)
fi

# Obligation 3 of .claude/rules/skill-authoring.md -- a skipped step announces
# itself. Only fires when source code is actually being committed, so a
# docs-only or config-only commit stays quiet and the notice keeps its meaning.
if [ -z "$CODE_ROOT" ]; then
    if echo "$STAGED" | grep -qiE '\.(gd|cs|cpp|cc|hpp|h|c|py|js|ts|rs|java|kt|lua|gdshader|shader|hlsl)$'; then
        WARNINGS="$WARNINGS\nSKIPPED: source files are staged but no code root could be resolved (engine.name unset, and the tree does not name one unambiguously). The hardcoded-value and TODO-owner scans did NOT run. Run /setup-engine, or set engine.name in project.yaml."
    fi
fi

CODE_FILES=""
[ -n "$CODE_ROOT" ] && CODE_FILES=$(echo "$STAGED" \
    | grep -E "^${CODE_ROOT}/" \
    | grep -iE '\.(gd|cs|cpp|cc|hpp|h|c|py|js|ts|rs|java|kt|lua)$')
if [ -n "$CODE_FILES" ]; then
    HARDCODED=$(printf '%s\n' "$CODE_FILES" | tr '\n' '\0' \
        | xargs -0 grep -lE '(damage|health|speed|rate|chance|cost|duration)[[:space:]]*[:=][[:space:]]*[0-9]+' 2>/dev/null || true)
    if [ -n "$HARDCODED" ]; then
        while IFS= read -r file; do
            [ -n "$file" ] && WARNINGS="$WARNINGS\nCODE: $file may contain hardcoded gameplay values. Use data files."
        done <<< "$HARDCODED"
    fi
fi

# Check for TODO/FIXME without assignee -- uses grep -E instead of grep -P
# Same code root as the scan above. Not extension-bounded: an unowned TODO is
# worth flagging in a shader or a build script too, and this scan greps for a
# literal marker rather than a numeric pattern, so it does not misfire on
# serialized asset YAML the way the hardcoded-value scan would.
SRC_FILES=""
[ -n "$CODE_ROOT" ] && SRC_FILES=$(echo "$STAGED" | grep -E "^${CODE_ROOT}/")
if [ -n "$SRC_FILES" ]; then
    UNOWNED=$(printf '%s\n' "$SRC_FILES" | tr '\n' '\0' \
        | xargs -0 grep -lE '(TODO|FIXME|HACK)[^(]' 2>/dev/null || true)
    if [ -n "$UNOWNED" ]; then
        while IFS= read -r file; do
            [ -n "$file" ] && WARNINGS="$WARNINGS\nSTYLE: $file has TODO/FIXME without owner tag. Use TODO(name) format."
        done <<< "$UNOWNED"
    fi
fi

# Print warnings (non-blocking) and allow commit
if [ -n "$WARNINGS" ]; then
    echo -e "=== Commit Validation Warnings ===$WARNINGS\n================================" >&2
fi

exit 0
