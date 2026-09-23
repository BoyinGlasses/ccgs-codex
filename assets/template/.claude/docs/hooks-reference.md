# Active Hooks

Hooks are configured in `.claude/settings.json` and fire automatically:

| Hook | Event | Trigger | Action |
| ---- | ----- | ------- | ------ |
| `validate-commit.sh` | PreToolUse (Bash) | `git commit` commands | Validates design doc sections, JSON data files, hardcoded values, TODO format |
| `validate-push.sh` | PreToolUse (Bash) | `git push` commands | Warns on pushes to protected branches (develop/main) |
| `validate-assets.sh` | PostToolUse (Write/Edit) | Asset file changes | Checks naming conventions and JSON validity for files in `assets/` |
| `session-start.sh` | SessionStart | Session begins | Loads sprint context, milestone, git activity; detects and previews active session state file for recovery |
| `detect-gaps.sh` | SessionStart | Session begins | Detects fresh projects (suggests /start) and missing documentation when code/prototypes exist, suggests /reverse-document or /project-stage-detect |
| `pre-compact.sh` | PreCompact | Context compression | Dumps session state (active.md, modified files, WIP design docs) into conversation before compaction so it survives summarization |
| `post-compact.sh` | PostCompact | After compaction | Reminds Claude to restore session state from `active.md` checkpoint |
| `notify.sh` | Notification | Notification event | Shows Windows toast notification via PowerShell |
| `session-stop.sh` | Stop | **Every response ends** — not once per session | Summarizes accomplishments, updates session log, and writes the subagent spawn tally to `production/session-logs/session-cost.md`. Archives `active.md` only when its content hash changed; without that guard a long session appended the whole file on every turn. |
| `log-agent.sh` | SubagentStart | Agent spawned | Audit trail start — logs subagent invocation with timestamp and session id |
| `log-agent-stop.sh` | SubagentStop | Agent stops | Audit trail stop — completes subagent record |
| `validate-skill-change.sh` | PostToolUse (Write/Edit) | Skill file changes | Advises running `/skill-test` after any `.agents/skills/` file is written or edited |

### Subagent cost visibility

The three hooks above form one chain. `log-agent.sh` writes a record per spawn
to `production/session-logs/agent-audit.log` in a fixed three-field shape:

```
YYYYMMDD_HHMMSS | <session_id> | Agent invoked: <agent_type>
```

`session-stop.sh` greps the literal string `" | $SESSION_ID | Agent invoked: "`
to tally the current session, then writes a count plus a per-agent breakdown to
`production/session-logs/session-cost.md` and echoes a one-line total.

Three constraints that must not be "tidied" later:

- **The field order is load-bearing.** Nothing else parses this log, so a
  reformat looks free — but it silently zeroes the spawn count rather than
  erroring.
- **`session-stop.sh` reads stdin last, on purpose.** Everything above the
  tally block (notably archiving `active.md`) runs first, so a stdin read that
  ever blocked would cost only the count, not the state archive.
- **No session id means no number.** The hook prints nothing rather than a
  total spanning every session in the log. Silence here is correct; a
  plausible-but-wrong cost figure is worse than none.

`agent_type` — not `agent_name` — is the field carrying the agent name. See
`hooks-reference/hook-input-schemas.md`.

## Events considered and deliberately not added

Claude Code offers many more hook events than the eleven above. These were
evaluated and rejected. Recorded so a future review does not re-propose them
from the event list alone.

| Event | Why not |
| ---- | ---- |
| `UserPromptSubmit` | Would re-inject session state on **every prompt**. `.claude/docs/config-resolution.md` already rejects the weaker version of this — injecting config at session start — because it "would cost tokens on every session whether or not any skill needs config, and it would go stale mid-session as `/settings` writes land". Firing per prompt is the same argument, multiplied. |
| `ConfigChange` | Fires only for Claude Code's own settings files — user, project, local, policy and skills. It does **not** fire for `project.yaml`, so a hook watching CCGS config here would never run. `FileChanged` is the event that watches arbitrary files. |
| `FileChanged` on `project.yaml` | Config is resolved per skill invocation, in the skill body, precisely so each run reads fresh values. The only staleness left is text already injected into an earlier invocation, which is the accepted trade in `config-resolution.md`. A warning hook would second-guess a settled decision. |
| `PreToolUse` `updatedInput` | Could rewrite a non-conventional commit message instead of blocking it. Silently editing the user's input contradicts the collaboration protocol: this project blocks and explains rather than acting unasked. |
| `PostToolUseFailure` | Would add another log with no reader. This repo has already been bitten by that — `log-agent.sh` wrote per-spawn records nothing consumed until `session-stop.sh` was given the job. |
| `SessionEnd` | `session-stop.sh` stays on `Stop`. `SessionEnd` fires on termination, which a crash may never reach, and the content-hash guard already makes the per-response firing cheap. |
| `InstructionsLoaded` | Useful for debugging which CLAUDE.md and rules files actually loaded, but it is a diagnostic, not a project requirement. Wire it in your own `.claude/settings.local.json` when you need it rather than paying for it on every load. |

Hook reference documentation: `.claude/docs/hooks-reference/`
Hook input schema documentation: `.claude/docs/hooks-reference/hook-input-schemas.md`
