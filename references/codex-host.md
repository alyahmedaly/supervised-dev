# Codex host notes

Supporting detail for the Runtime adapter table in SKILL.md. Everything here is Codex-specific; the
phases themselves stay host-neutral.

## Install

Codex loads user-level skills from `~/.agents/skills` (source: `developers.openai.com/codex/skills`,
redirects to `learn.chatgpt.com/docs/build-skills`). Symlink this skill dir in rather than copying it, so
one directory serves both hosts:

    ln -s ~/.claude/skills/supervised-dev ~/.agents/skills/supervised-dev

## Smoke test: run one role by hand

Before trusting the pipeline under Codex, run one read-only role manually against a real diff:

    cd <repo>
    codex exec -s read-only --approve-for-me \
      "$(cat ~/.agents/skills/supervised-dev/roles/reviewer.md)

    Review the diff from base SHA <base sha> to head SHA <head sha>.
    Run: git diff <base sha> <head sha>"

Confirm: the process exits without prompting (read-only sandbox), and the findings follow the role's
required fields (file, line, severity, problem, fix). A prompt appearing anyway means the sandbox/approval
flags in the adapter table need re-checking against the installed `codex exec --help`.

## Unconfirmed — verify before relying on these

- **Model id per role.** No official per-role Codex model recommendation was found (research R2/R4). Do
  not guess a model id; check `codex --help` or `~/.codex/config.toml` on the machine that will run it.
- **`model_reasoning_effort` key spelling.** The value vocabulary (`minimal, low, medium, high, xhigh`) is
  confirmed via the local `codex-cli-runtime` skill's `--effort` flag; the exact TOML key name is
  corroborated only by third-party sources — `developers.openai.com/codex/config` returned HTTP 404 when
  fetched directly. Verify against `codex exec --help` or `codex doctor` before depending on it.
- **Running four concurrent role sessions** (one per role) rather than one interactive thread — not
  exercised here; `codex exec resume`'s session-selection semantics under that pattern are untested.
