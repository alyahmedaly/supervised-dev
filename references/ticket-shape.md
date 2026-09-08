# Ticket shape

A ticket is the contract for one unit of work, written before any delegation. It becomes the decision
record when the work closes.

## Location

`docs/<program>/tickets/NNN-<slug>.md` — zero-padded three-digit id, kebab-case slug. Follow the repo's
own ticket directory convention if it already has one. Tracked, and lands in the PR — unlike the ledger,
which never does.

## Frontmatter

Fenced YAML, exactly these keys:

```yaml
---
id: '001'
title: <imperative, one line>
type: task | research
labels: [<topic>, <topic>] # topic tags only; never tool- or workflow-prefixed labels
status: open | closed | rejected # must agree with the body: closed ⇔ "## Outcome" present
assignee: null
blocked_by: []
blocks: []
gate: null # optional: the named gate this ticket satisfies
supersedes: null # optional: path of the ticket or plan this replaces
source: # repo-relative paths the agent must read; point, do not paste
  - intent/<slug>.md # optional: the upstream intent this ticket serves
  - docs/<program>/plan.md
effort: S | M # L is not a ticket; split it through a plan first
mode: AFK | pair # only AFK enters the pipeline
loop: full | light # light = tester + implementer only, supervisor verifies; see SKILL.md "Light loop"
created: YYYY-MM-DD
intent_recorded: null # date the intent pass ran; AFK with null here is invalid
resolved: null # set at close
---
```

## Body, canonical section names, in this order

- `## Question` — one falsifiable question the ticket answers; stands without the solution.
- `## Recorded intent` — the choices the ticket rests on, from the intent pass (see SKILL.md "Intent
  pass"). One bold-led paragraph each, two kinds, tagged. A **decision** the user answered: what was
  chosen, and the reason. An **`Assumed.`** entry the drafter made without asking, because it lost the
  question budget — written down so the user can reverse it by reading. An answer that went against the
  recommendation is tagged `Override` and carries the user's own words verbatim, never paraphrased.
- `## Required changes` — scope as imperative bullets; future tense is fine here.
- `## Out of scope` — what neighbours own; name the ticket that owns each item.
- `## Pinned rules` — 3–6 invariants this change must not break, from the repo's agent instructions or
  the plan. Tester writes one pin test per rule; pins pass on base and after.
- `## Acceptance` — pass/fail bullets, each ending in an oracle tag such as `(oracle: tester)` or
  `(oracle: review)`. No oracle means it's a wish — give it one or move it to Out of scope.
- `## Verification` — the exact fenced commands; these ARE the named oracles, nothing else.
- `## Alternatives considered` — optional at open; only what was actually weighed, one bold-led
  paragraph each, with why it lost.
- `## Notes` — sequencing, boundaries with neighbours.
- `## Outcome` — added only at close, by the supervisor, same PR. Four H3s: `### Decision` (what
  shipped, present tense, plus any drift from `## Recorded intent`); `### Alternatives considered` (what
  it beat and why — recorded, never invented, say so if none were weighed); `### Consequences` (cost AND
  benefit); `### Verification` (pins now, as `passed/total` with the SHA measured at).

## Rules

- Status agrees with body: `open` has no Outcome; `closed` has Outcome and `resolved:`; `rejected`
  freezes the proposal and carries the one-line reason in `## Notes`.
- Every ticket carries `## Recorded intent` and a date in `intent_recorded:`. `mode: AFK` with
  `intent_recorded: null` is invalid — nobody is watching once Phase 2 starts, so an unanswered
  load-bearing choice cannot ride into the pipeline.
- Recorded intent is provenance, not weighing. `## Alternatives considered` is what the drafter weighed;
  `## Recorded intent` is what the user decided and what the drafter assumed unasked. A recorded decision
  that is testable also earns a `## Pinned rules` entry — intent keeps the why, the pin keeps the check.
- Code blocks in a ticket are contract targets, labelled as such — never implementation hints.
- Supersession check: search existing tickets and plans for the same scope before writing a new one.
  Extend or set `supersedes:`; never duplicate.
- Tense: sections above Outcome may speak future; Outcome speaks present.

## Worked example — open

````markdown
---
id: '041'
title: Add --format table|json flag to report
type: task
labels: [cli, output]
status: open
assignee: null
blocked_by: ['038']
blocks: ['042']
gate: null
supersedes: null
source:
  - docs/tooling-cli/plan.md
effort: S
mode: AFK
loop: full
created: 2026-01-14
intent_recorded: 2026-01-14
resolved: null
---

## Question

Can `tooling-cli report` emit machine-readable JSON instead of only the table it prints today?

## Recorded intent

**Output framing.** One JSON object per row, newline-delimited, not a single top-level array.
Recommended — the table already streams row by row, so NDJSON keeps `report` usable in a pipe and
needs no buffering.

**Flag surface.** `--format <table|json>` on the existing command. `Override` — recommendation was a
`--json` boolean. User: "we will want csv next quarter, don't paint us into a boolean".

**`Assumed.`** Unknown `--format` values exit 1 rather than falling back to `table`. Not asked; the
repo's other flags already reject unknown values this way.

## Required changes

- Add a `--format <table|json>` flag to `report`, default `table`.
- When `--format json`, print one JSON object per report row to stdout, newline-delimited.
- Reject an unknown `--format` value with a non-zero exit and a one-line stderr message.

## Out of scope

- Reworking the table layout itself — owned by ticket 038.
- A `--format csv` mode — anticipated in Recorded intent, but no ticket yet.
- Consuming the JSON in the CI summary — owned by ticket 042.

## Pinned rules

- `report` writes only the report body to stdout (see `cli/report.ts`).
- Exit code 0 only when every requested row printed.
- Flag parsing stays in `cli/args.ts`; commands never read `process.argv` directly.

## Acceptance

- `report --format json` on a 3-row fixture prints 3 valid JSON lines (oracle: tester)
- `report` with no flag prints the existing table, byte-for-byte (oracle: tester)
- `report --format xml` exits 1 naming the bad value on stderr (oracle: tester)
- lint and typecheck pass (oracle: `npm run verify`)

## Verification

```
npm run verify
```

## Alternatives considered

**Separate `report-json` command.** Rejected: doubles the surface for one output switch, and the two
commands would drift on filtering flags.

## Notes

Blocked on 038 (column rename), so JSON keys match the final column names. 042 consumes this output.
````

## Worked example — closed (excerpt)

```markdown
---
id: '041'
status: closed
resolved: '2026-01-16'
---

## Outcome

### Decision

Shipped `--format table|json` on `report`, newline-delimited, default unchanged. No drift from Recorded
intent.

### Alternatives considered

Separate `report-json` command; rejected for doubling the flag surface (see Alternatives considered
above).

### Consequences

Cost: one new flag branch in `cli/args.ts`, one new fixture file. Bought: scriptable report output
without parsing the table.

### Verification

Pins: 3/3 passed at `a1b2c3d`.
```

The Outcome section's shape follows [DeepSeek Harness Agent Notes](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/README.md) (MIT); the prose above is original.
