"""Translate Codex hook input to the original CCGS shell hook schema."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASH = shutil.which("bash")
if os.name == "nt":
    git = shutil.which("git")
    candidates = [Path(git).parent.parent / "bin" / "bash.exe"] if git else []
    candidates.append(Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "Git" / "bin" / "bash.exe")
    BASH = next((str(path) for path in candidates if path.is_file()), None)

EVENTS = {
    "SessionStart": ["session-start.sh", "detect-gaps.sh"],
    "PreToolUse": ["validate-commit.sh", "validate-push.sh"],
    "PostToolUse": ["validate-assets.sh", "validate-skill-change.sh"],
    "PreCompact": ["pre-compact.sh"],
    "PostCompact": ["post-compact.sh"],
    "Stop": ["session-stop.sh"],
    "SubagentStart": ["log-agent.sh"],
    "SubagentStop": ["log-agent-stop.sh"],
}


def inputs(event: str, data: dict) -> list[dict]:
    if event == "PreToolUse":
        tool = data.get("tool_input") or {}
        return [{**data, "tool_name": "Bash", "tool_input": {"command": tool.get("command") or tool.get("cmd") or ""}}]
    if event == "PostToolUse":
        tool = data.get("tool_input") or {}
        command = tool.get("command", "")
        paths = re.findall(r"^\*\*\* (?:Add|Update|Delete) File: (.+)$", command, re.M)
        if tool.get("file_path"):
            paths.append(tool["file_path"])
        return [{**data, "tool_name": "Write", "tool_input": {"file_path": p}} for p in dict.fromkeys(paths)]
    return [data]


def run(event: str, data: dict) -> tuple[bool, str]:
    if not BASH:
        raise FileNotFoundError("Git Bash is required for CCGS hooks")
    env = os.environ.copy()
    env["CLAUDE_PROJECT_DIR"] = str(ROOT)
    messages = []
    blocked = False
    for script in EVENTS[event]:
        for payload in inputs(event, data):
            path = ROOT / ".claude" / "hooks" / script
            result = subprocess.run(
                [BASH, str(path)], input=json.dumps(payload), text=True,
                encoding="utf-8", errors="replace", capture_output=True,
                cwd=ROOT, env=env, timeout=15,
            )
            output = "\n".join(x.strip() for x in (result.stdout, result.stderr) if x.strip())
            output = output.replace("Claude Code Game Studios", "Codex Game Studios")
            output = output.replace("/start", "$ccgs-start").replace("/skill-test", "$ccgs-skill-test")
            if output:
                messages.append(output)
            blocked |= result.returncode == 2 and event == "PreToolUse"
    return blocked, "\n".join(messages)


def main() -> None:
    event = sys.argv[1]
    data = json.load(sys.stdin)
    try:
        blocked, message = run(event, data)
    except (OSError, subprocess.TimeoutExpired) as exc:
        print(json.dumps({"systemMessage": f"CCGS hook {event} failed: {exc}"}))
        return
    if blocked:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse", "permissionDecision": "deny",
            "permissionDecisionReason": message or "CCGS validation blocked this command.",
        }}))
    elif message:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": event, "additionalContext": message,
        }}))


if __name__ == "__main__":
    main()
