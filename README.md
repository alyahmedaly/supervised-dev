# supervised-dev

An agent skill that runs one ticket through a supervised pipeline. A supervisor plans and gates the
work; a tester writes failing acceptance tests first; an implementer makes them pass; a reviewer and a
simplifier audit the same SHA read-only; the supervisor freezes findings, allows at most two fix cycles,
and returns one verdict. Works under Claude Code and OpenAI Codex CLI.

## When not to use it

- One-line fix, typo, mechanical rename, or comment: do it yourself, plus the one relevant check.
- Bounded change touching one or two files with an obvious oracle: do it yourself, plus one reviewer
  pass on the diff.
- The full pipeline is for a real feature or refactor with non-obvious failure modes — four subagents
  cost four system prompts, four tool schemas, and four handoffs before any code changes, so only spend
  that on work substantial enough to repay it.

## Install — Claude Code

```sh
git clone https://github.com/alyahmedaly/supervised-dev ~/.claude/skills/supervised-dev
sh ~/.claude/skills/supervised-dev/scripts/sync-claude-agents.sh
```

The sync script generates the four role agents (`subagent-tester`, `subagent-implementer`,
`subagent-reviewer`, `subagent-simplifier`) as `~/.claude/agents/subagent-*.md`, one per `roles/*.md` role
body plus a Claude Code frontmatter block. It writes under `$CLAUDE_AGENTS_DIR` instead of
`~/.claude/agents` if that variable is set. Start a new session afterward so the agents are picked up.

## Install — Codex CLI

```sh
git clone https://github.com/alyahmedaly/supervised-dev ~/.agents/skills/supervised-dev
```

Or symlink from the Claude Code checkout so one clone serves both hosts:

```sh
ln -s ~/.claude/skills/supervised-dev ~/.agents/skills/supervised-dev
```

Codex has no native subagent/spawn command, so the supervisor shells out per role via
`codex exec`. See `references/codex-host.md` for the exact exec command, sandbox and approval flags per
role, the smoke test for running one role by hand, and the items still unconfirmed (model id per role,
the `model_reasoning_effort` key spelling).

## Usage

Invoke `/supervised-dev` with a ticket description and concrete acceptance criteria. The skill asks for
whichever of the two is missing before it starts; everything else (base SHA, verification commands,
repo conventions) it reads from the repository itself. Hand it a ticket in the shape of
`references/ticket-shape.md`, or hand it prose and it drafts the ticket in that shape and waits for your
approval before Phase 1.

Phase 1 collects shared source context before delegation. The supervisor keeps a tracked
`docs/<feature>/handoff.md` current at phase boundaries, batch completions, and blocked exits.
Detailed assignments can use temporary role/batch briefs containing source-derived values, patterns,
commands, an exact starting SHA, and ticket/handoff links. Agents read that brief first, then durable
context before scoped source inspection. Tickets own intent and decisions; handoffs own current state
and resume information. Briefs remain reconstructible, with lasting discoveries promoted into durable
documents. Broad sweeps may use one optional read-only investigator; ordinary tickets reuse the
supervisor's recon. Both full and light loops follow these checkpoint rules.

Markdown tickets support issue-style discussion through dated `## Updates` entries for feedback,
discoveries, and decisions. The supervisor records contributions and folds settled knowledge into
current status and the handoff, so later agents can resume without replaying the whole discussion.

## Layout

| Path                            | Contents                                                                 |
| ------------------------------- | ------------------------------------------------------------------------ |
| `SKILL.md`                      | The pipeline itself: phases, roles, gating, verdict format               |
| `roles/*.md`                    | Runtime-neutral role prompts, single source for both hosts               |
| `scripts/sync-claude-agents.sh` | Generates the Claude Code `subagent-*.md` agents from `roles/*.md`       |
| `references/incidents.md`       | The incidents behind the pipeline's rules                                |
| `references/codex-host.md`      | Codex CLI adapter detail: exec command, sandbox flags, unconfirmed items |
| `references/ticket-shape.md`    | The ticket contract: frontmatter, body sections, worked example          |
| `references/plan-shape.md`      | The plan contract for tickets made of N repeatable units                 |

## License

MIT — see `LICENSE`.
