#!/usr/bin/env bash
# artifact-check.sh — evaluate every workflow-catalog step's artifact spec
# against what is actually on disk.
#
# Replaces the "Use Glob and Read to verify files exist and have meaningful
# content" loop in /gate-check (and the equivalent hand-scans in /help and
# /project-stage-detect). workflow-catalog.yaml already encodes `glob`,
# `pattern`, `min_count` and `any_of` per step; nothing consumed it
# deterministically, so the model re-derived the same answers by opening files.
#
# EMITS OBSERVATIONS, NOT A VERDICT (per .claude/docs/context-management.md
# rule 2). It reports what is on disk; the CALLER applies the workflow tier,
# the required/optional distinction, and any per-system override. In
# particular this script never says PASS or FAIL, and never decides that an
# ABSENT artifact is a blocker — at `minimal` most of them are not.
#
# Usage: bash .claude/scripts/artifact-check.sh [--phase <id>] [project-root]
#   --phase <id>  restrict output to one phase (concept, systems-design, ...)
#   project-root  defaults to the repo root; an explicit path is taken as-is
#                 (used by the test suite against fixtures).
#
# Output:
#   CATALOG: <path>            the catalog actually read
#   ROOT: <path>               the tree evaluated against
#   PHASES: <n> / STEPS: <n>   denominators — see below
#   PHASE: <id>
#     STEP: <id> required=<bool> repeatable=<bool> check=<kind> status=<status> ...
#
# status values (observations):
#   PRESENT       glob matched, count >= min_count, pattern found if specified
#   ABSENT        no file matched the glob
#   SHORT         files matched but fewer than min_count
#   PATTERN_MISS  files matched but none contained the required pattern
#   NO_CHECK      the step declares no artifact — completion is not detectable
#                 from disk. NOT the same as ABSENT. A `note=` field carries the
#                 catalog's human-readable fallback where one exists.
#
# DENOMINATOR DISCIPLINE (mirrors create-control-manifest / adr-dep-graph.sh):
# STEPS is printed before any per-step line so a caller can tell "0 steps
# reported because the catalog failed to parse" from "0 steps are incomplete".
# A NO_CHECK count is printed too — a phase that is all NO_CHECK has been
# *scanned*, not *satisfied*, and reporting it as clean would be a false pass.
#
# Patterns are POSIX ERE and are matched with `grep -E`, never Python `re`
# (the catalog uses classes like [[:space:]]) and never `grep -P` (unavailable
# on Windows Git Bash — see .claude/docs/coding-standards notes).

set -u

PHASE_FILTER=""
ROOT_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --phase) PHASE_FILTER="${2:-}"; shift 2 ;;
    --phase=*) PHASE_FILTER="${1#--phase=}"; shift ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) ROOT_ARG="$1"; shift ;;
  esac
done

if [ -n "$ROOT_ARG" ]; then
  ROOT="$ROOT_ARG"
else
  cd "$(dirname "$0")/../.." || { echo "artifact-check: cannot reach repo root" >&2; exit 1; }
  ROOT="$(pwd)"
fi

CATALOG="$ROOT/.claude/docs/workflow-catalog.yaml"
if [ ! -f "$CATALOG" ]; then
  echo "artifact-check: catalog not found at $CATALOG" >&2
  exit 1
fi

# Python fallback chain: python -> python3 -> py (matches yaml-helper.sh:65).
PYBIN=""
for candidate in python python3 py; do
  if command -v "$candidate" >/dev/null 2>&1; then
    if "$candidate" -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
      PYBIN="$candidate"; break
    fi
  fi
done
if [ -z "$PYBIN" ]; then
  echo "artifact-check: no python 3 interpreter found (tried python, python3, py)" >&2
  exit 1
fi

"$PYBIN" - "$CATALOG" "$ROOT" "$PHASE_FILTER" <<'PYEOF'
import glob as globmod
import os
import subprocess
import sys

catalog_path, root, phase_filter = sys.argv[1], sys.argv[2], sys.argv[3]

# A gate's own output path is part of the gate: the catalog's `note:` fields
# contain em-dashes, and on a cp1252 console an unreconfigured stdout raises
# UnicodeEncodeError mid-report — dying after some rows have printed, which
# reads as a short but successful run. Force UTF-8 and never crash on a glyph.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, ValueError):
    pass


def indent_of(line):
    return len(line) - len(line.lstrip(" "))


def strip_val(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        v = v[1:-1]
    return v


# --- parse ---------------------------------------------------------------
# Hand-rolled on purpose: PyYAML is not a guaranteed dependency (yaml-helper.sh
# promises "no external deps beyond a Python 3 interpreter"). The catalog's
# shape is fixed and regular, so an indentation walk is sufficient and cannot
# drag in an import that fails on a user's machine.
with open(catalog_path, encoding="utf-8", errors="replace") as fh:
    lines = [ln.rstrip("\n").rstrip("\r") for ln in fh]

phases = []            # [(phase_id, [step, ...])]
cur_phase = None
cur_step = None
ctx = None             # None | "artifact" | "any_of"
in_phases = False

for raw in lines:
    if not raw.strip() or raw.lstrip().startswith("#"):
        continue
    ind = indent_of(raw)
    s = raw.strip()

    if ind == 0:
        in_phases = (s == "phases:")
        continue
    if not in_phases:
        continue

    if ind == 2 and s.endswith(":"):
        cur_phase = (s[:-1].strip(), [])
        phases.append(cur_phase)
        cur_step = None
        ctx = None
        continue
    if cur_phase is None:
        continue

    if ind == 6 and s.startswith("- id:"):
        cur_step = {"id": strip_val(s[len("- id:"):]), "required": False,
                    "repeatable": False, "artifact": None, "note": None}
        cur_phase[1].append(cur_step)
        ctx = None
        continue
    if cur_step is None:
        continue

    if ind == 8:
        ctx = None
        if s == "artifact:":
            cur_step["artifact"] = {"glob": None, "pattern": None,
                                    "min_count": 1, "any_of": [], "note": None}
            ctx = "artifact"
        elif s.startswith("required:"):
            cur_step["required"] = strip_val(s[len("required:"):]).lower() == "true"
        elif s.startswith("repeatable:"):
            cur_step["repeatable"] = strip_val(s[len("repeatable:"):]).lower() == "true"
        continue

    art = cur_step["artifact"]
    if art is None:
        continue

    if ind == 10:
        if s == "any_of:":
            ctx = "any_of"
        elif s.startswith("glob:"):
            art["glob"] = strip_val(s[len("glob:"):]); ctx = "artifact"
        elif s.startswith("pattern:"):
            art["pattern"] = strip_val(s[len("pattern:"):]); ctx = "artifact"
        elif s.startswith("min_count:"):
            try:
                art["min_count"] = int(strip_val(s[len("min_count:"):]))
            except ValueError:
                pass
            ctx = "artifact"
        elif s.startswith("note:"):
            art["note"] = strip_val(s[len("note:"):]); ctx = "artifact"
        continue

    if ind >= 12 and ctx == "any_of":
        if s.startswith("- glob:"):
            art["any_of"].append({"glob": strip_val(s[len("- glob:"):]), "pattern": None})
        elif s.startswith("pattern:") and art["any_of"]:
            art["any_of"][-1]["pattern"] = strip_val(s[len("pattern:"):])

# --- evaluate ------------------------------------------------------------
def match_files(pat):
    if not pat:
        return []
    full = os.path.join(root, pat.replace("/", os.sep))
    return sorted(p for p in globmod.glob(full, recursive=True) if os.path.isfile(p))


def pattern_hits(files, pattern):
    """POSIX ERE via grep -E. Python's re cannot parse [[:space:]], and grep -P
    is unavailable on Windows Git Bash."""
    if not pattern:
        return files
    hits = []
    for f in files:
        try:
            rc = subprocess.call(["grep", "-qE", "--", pattern, f],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError:
            return None          # no grep — caller reports UNKNOWN rather than a false miss
        if rc == 0:
            hits.append(f)
    return hits


def evaluate(art):
    """-> (status, kind, detail dict). Observation only; no verdict."""
    if art is None:
        return "NO_CHECK", "none", {}

    if art["any_of"]:
        for i, alt in enumerate(art["any_of"]):
            files = match_files(alt["glob"])
            if not files:
                continue
            hits = pattern_hits(files, alt["pattern"])
            if hits is None:
                return "UNKNOWN", "any_of", {"why": "grep-unavailable"}
            if hits:
                return "PRESENT", "any_of", {"match": alt["glob"], "alt": str(i + 1)}
        return "ABSENT", "any_of", {"alts": str(len(art["any_of"]))}

    if not art["glob"]:
        return "NO_CHECK", "none", ({"note": art["note"]} if art["note"] else {})

    files = match_files(art["glob"])
    if not files:
        return "ABSENT", "glob", {"glob": art["glob"]}

    hits = pattern_hits(files, art["pattern"])
    if hits is None:
        return "UNKNOWN", "glob", {"why": "grep-unavailable"}
    if art["pattern"] and not hits:
        return "PATTERN_MISS", "glob", {"glob": art["glob"], "found": str(len(files))}

    counted = hits if art["pattern"] else files
    need = art["min_count"]
    if len(counted) < need:
        return "SHORT", "glob", {"glob": art["glob"], "count": str(len(counted)), "min": str(need)}
    d = {"count": str(len(counted))}
    if need > 1:
        d["min"] = str(need)
    return "PRESENT", "glob", d


sel = [(pid, steps) for pid, steps in phases if not phase_filter or pid == phase_filter]

if phase_filter and not sel:
    known = ", ".join(pid for pid, _ in phases) or "(none parsed)"
    sys.stderr.write("artifact-check: unknown phase '%s' (known: %s)\n" % (phase_filter, known))
    sys.exit(2)

total_steps = sum(len(s) for _, s in sel)
print("CATALOG: %s" % os.path.relpath(catalog_path, root).replace(os.sep, "/"))
print("ROOT: %s" % root.replace(os.sep, "/"))
print("PHASES: %d" % len(sel))
print("STEPS: %d" % total_steps)

no_check = 0
rows = []
for pid, steps in sel:
    rows.append("PHASE: %s" % pid)
    for st in steps:
        status, kind, det = evaluate(st["artifact"])
        if status == "NO_CHECK":
            no_check += 1
        extra = "".join(" %s=%s" % (k, v) for k, v in sorted(det.items()) if v is not None)
        rows.append("  STEP: %s required=%s repeatable=%s check=%s status=%s%s"
                    % (st["id"], str(st["required"]).lower(),
                       str(st["repeatable"]).lower(), kind, status, extra))

# Printed BEFORE the rows so a caller reading top-down knows how much of what
# follows is undetectable-from-disk before it reads any of it.
print("NO_CHECK: %d" % no_check)
for r in rows:
    print(r)
PYEOF
