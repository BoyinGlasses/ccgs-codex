"""Run with `python tests/smoke_port.py` after changing the Codex port."""

import json
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "assets" / "template"


def main() -> None:
    assert json.loads((ROOT / "plugin.json").read_text(encoding="utf-8"))["name"] == "ccgs-codex"
    plugin_skills = {p.name for p in (ROOT / "skills").iterdir() if p.is_dir()}
    project_skills = {p.name for p in (TEMPLATE / ".agents" / "skills").iterdir() if p.is_dir()}
    assert plugin_skills == project_skills | {"ccgs-new-game"}
    for name in project_skills:
        assert (ROOT / "skills" / name / "SKILL.md").read_bytes() == (
            TEMPLATE / ".agents" / "skills" / name / "SKILL.md"
        ).read_bytes(), name

    agents = [tomllib.loads(p.read_text(encoding="utf-8")) for p in (TEMPLATE / ".codex" / "agents").glob("*.toml")]
    assert len(agents) == len({agent["name"] for agent in agents}) == 49
    assert all("May I write" not in agent["developer_instructions"] for agent in agents)
    commands = [name.removeprefix("ccgs-") for name in plugin_skills]
    old_command = re.compile(r"(?<![\w./])/(?:" + "|".join(map(re.escape, sorted(commands, key=len, reverse=True))) + r")(?![\w-])")
    assert all(not old_command.search(agent["developer_instructions"]) for agent in agents)
    hooks = json.loads((TEMPLATE / ".codex" / "hooks.json").read_text(encoding="utf-8"))["hooks"]
    assert {"SessionStart", "PreToolUse", "PostToolUse", "PreCompact", "PostCompact"} <= hooks.keys()

    with tempfile.TemporaryDirectory(prefix="ccgs-port-") as directory:
        game = Path(directory) / "game"
        shutil.copytree(TEMPLATE, game)
        assert (game / ".agents" / "skills" / "ccgs-start" / "SKILL.md").is_file()
        assert (game / ".codex" / "agents" / "producer.toml").is_file()
        broken = game / "assets" / "data" / "broken.json"
        broken.parent.mkdir(parents=True, exist_ok=True)
        broken.write_text("{broken", encoding="utf-8")
        event = {
            "tool_name": "apply_patch",
            "tool_input": {"command": "*** Begin Patch\n*** Add File: assets/data/broken.json\n+{broken\n*** End Patch"},
        }
        result = subprocess.run(
            [sys.executable, str(game / ".codex" / "hooks" / "bridge.py"), "PostToolUse"],
            input=json.dumps(event), text=True, capture_output=True, cwd=game, timeout=30,
        )
        assert result.returncode == 0, result.stderr
        assert "not valid JSON" in json.loads(result.stdout)["hookSpecificOutput"]["additionalContext"]

    print("CCGS Codex port smoke test passed")


if __name__ == "__main__":
    main()
