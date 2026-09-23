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

# Claude Code PostToolUse hook: Validates asset files after Write/Edit
# Checks naming conventions for files in assets/ directory
#
# Exit behavior:
#   exit 0 = success or advisory warnings only
#   exit 2 = build-breaking issue (invalid JSON, missing required fields)
#
# A PostToolUse hook CANNOT block -- the write has already happened by the time
# this runs (see .claude/docs/hooks-reference/hook-input-schemas.md). The only
# question is who hears about it, and that is what the exit code selects:
#   exit 1 -> stderr goes to the USER only. Claude never sees it, so a JSON file
#             it just corrupted looks like it wrote cleanly and it moves on.
#   exit 2 -> stderr is fed back to CLAUDE as actionable feedback, so it can fix
#             the file it just wrote.
# Exiting 1 while printing "ERRORS (Blocking) ... fix before proceeding" would be
# a promise the hook cannot keep, delivered to the one party who cannot act on it.
#
# Input schema (PostToolUse for Write/Edit):
# { "tool_name": "Write", "tool_input": { "file_path": "assets/data/foo.json", "content": "..." } }

INPUT=$(cat)

# Parse file path -- use jq if available, fall back to grep
if command -v jq >/dev/null 2>&1; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
else
    FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# Normalize path separators (Windows backslash to forward slash).
# Two rules, order significant -- see the long note in validate-skill-change.sh.
# Short version: hook input is JSON, so a Windows path arrives as `\\`. Without
# jq the fallback cannot unescape it, and a single-rule sed turns each escaped
# pair into two slashes, so `assets/` never matches and this hook silently
# validates nothing on Windows.
FILE_PATH=$(printf '%s' "$FILE_PATH" | sed 's|\\\\|/|g; s|\\|/|g')

# Only check files in assets/
if ! echo "$FILE_PATH" | grep -qE '(^|/)assets/'; then
    exit 0
fi

FILENAME=$(basename "$FILE_PATH")
WARNINGS=""   # Style/convention issues -- exit 0 with advisory message
ERRORS=""     # Build-breaking issues -- exit 1 to block the operation

# ADVISORY: Check naming convention (lowercase with underscores only)
# Naming issues are style violations -- warn but do not block
# Uses grep -E (POSIX) not grep -P (Perl) for Windows Git Bash compatibility
if echo "$FILENAME" | grep -qE '[A-Z[:space:]-]'; then
    WARNINGS="$WARNINGS\n  NAMING: $FILE_PATH must be lowercase with underscores (got: $FILENAME)"
fi

# BLOCKING: Check JSON validity for data files
# Invalid JSON will break runtime loading -- this is a build-breaking error
if echo "$FILE_PATH" | grep -qE '(^|/)assets/data/.*\.json$'; then
    if [ -f "$FILE_PATH" ]; then
        # Find a working Python command
        PYTHON_CMD=""
        for cmd in python python3 py; do
            if command -v "$cmd" >/dev/null 2>&1; then
                PYTHON_CMD="$cmd"
                break
            fi
        done

        if [ -n "$PYTHON_CMD" ]; then
            if ! "$PYTHON_CMD" -m json.tool "$FILE_PATH" > /dev/null 2>&1; then
                ERRORS="$ERRORS\n  FORMAT: $FILE_PATH is not valid JSON — fix syntax errors before continuing"
            fi
        else
            # Say so rather than skipping in silence. This is the only BLOCKING
            # check in this hook, so without an interpreter the hook exits 0 on
            # a file it never opened -- indistinguishable from valid JSON. The
            # sibling validate-commit.sh already warns in exactly this case;
            # this half was the one that did not.
            echo "WARNING: Cannot validate JSON (python not found) — $FILE_PATH unchecked" >&2
        fi
    fi
fi

# Report warnings (advisory -- non-blocking)
if [ -n "$WARNINGS" ]; then
    echo -e "=== Asset Validation: Warnings ===$WARNINGS\n==================================\n(Warnings are advisory. Fix before final commit.)" >&2
fi

# Report build-breaking issues. exit 2 routes this to Claude, not just the user,
# so the file that was already written can actually be corrected.
if [ -n "$ERRORS" ]; then
    echo -e "=== Asset Validation: ERRORS ===$ERRORS\n================================\nThe file was written but is broken. Fix it now, before continuing." >&2
    exit 2
fi

exit 0
