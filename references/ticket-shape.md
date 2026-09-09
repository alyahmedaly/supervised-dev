# Ticket shape

A ticket is the contract for one unit of work, written before any delegation. It becomes the decision
record when the work closes.

## Location

`docs/<program>/tickets/NNN-<slug>.md` — zero-padded three-digit id, kebab-case slug. Follow the repo's
own ticket directory convention if it already has one. The ticket and feature handoff are tracked and
land in the PR. Only optional scratch logs stay outside the repo.

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
source: # repo-relative evidence index; read shared context first, then role-relevant sources
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
- `## Notes` — sequencing, boundaries with neighbours; current status and handoff link if the ticket
  has no existing `## Current status`. Preserve an existing status section rather than adding a duplicate.
- `## Updates` — optional until the first substantive update; dated feedback, discoveries, context,
  and decisions, like issue comments. Append new entries; keep current state in status/handoff.
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
- Code blocks in scope/acceptance sections are contract targets, labelled as such — never implementation
  hints. Evidence snippets in Updates are labelled as observations with their source and measured SHA.
- Supersession check: search existing tickets and plans for the same scope before writing a new one.
  Extend or set `supersedes:`; never duplicate.
- Tense: sections above Outcome may speak future; Outcome speaks present.

## Updates — issue-style discussion

The supervisor appends meaningful user feedback, agent findings, new context, and decisions under
`## Updates`. Keep entries chronological, oldest first, using this lightweight shape:

```markdown
### YYYY-MM-DD HH:mm UTC — <author or role> — <short subject>

<Feedback, discovery, or decision; one short paragraph.>

Evidence: <path:symbol, command/result with measured SHA, or link; when applicable>
Follow-up: <action/owner, unresolved question, or superseded entry; when applicable>
```

Attribute user feedback accurately; preserve the user's words for decisions and overrides. When the
supervisor records an agent's finding, name that role rather than implying the user said it. Agents
return updates to the supervisor; they do not gain permission to edit ticket or handoff documents.

Append corrections with a reference to the earlier entry instead of rewriting history. An update is
discussion, not an automatic scope change: confirmed decisions also update Recorded intent and affected
contract sections through the existing intent/scope rules. Promote settled facts into the handoff and
current status at the next safe checkpoint. Keep unresolved questions visible there until resolved.
Do not copy raw logs or routine phase narration into Updates.

Existing tickets remain valid without this section; add it on the first meaningful contribution.
Outcome remains the closing decision record. In new tickets, Updates sits after Notes and before
Outcome; preserve an existing discussion section/location instead of creating a second thread.

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
