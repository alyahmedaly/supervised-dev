---
name: supervised-dev
description: 'Use to run a ticket end-to-end through the supervised delivery pipeline: tester writes failing tests, implementer fixes production code, reviewer inspects the diff, simplifier finds over-built surface, supervisor gives a single combined verdict. Invoked by the supervisor when the user provides a ticket.'
---

# Supervised Delivery

Run one ticket through the full pipeline. Serial execution, one worktree. No parallel writers.

## When this pipeline is the wrong tool

Four subagents cost four system prompts, four tool schemas, four handoffs, and four reviews before any code changes. That fixed prefix only repays itself on work with real correctness risk and enough substance to amortise it.

Downshift to the first row that covers the work:

| Work                                                | Run it as                                    |
| --------------------------------------------------- | -------------------------------------------- |
| One-line fix, typo, mechanical rename, comment      | Yourself, plus the one relevant check        |
| Bounded change, one or two files, obvious oracle    | Yourself, plus one reviewer pass on the diff |
| Real feature or refactor, non-obvious failure modes | Full pipeline below                          |
| Repo-wide sweep of N near-identical units           | Full pipeline, batched — see Phase 3         |

The rows have moved down over time. Current models finish multi-file features end to end without leaving
stubs when handed the complete specification up front, so work that once needed the pipeline to avoid
half-done output now sits a row lower — the pipeline buys independent judgement on a diff, not completion.
Escalating past the row the work sits in is a cost with no buyer. Name the row you picked, and why, in your first message so the user can push back before the delegation is paid for.

## Entry requirements

Before starting, confirm you have:

- Ticket: what to build or fix, scope, out-of-scope list
- Acceptance criteria: concrete pass/fail conditions

If either is missing, ask the user before proceeding. Anything answerable from the repo — base SHA, test commands, conventions — you find yourself.

## Roles and tools

| Role        | Tool                                           | Authority                                 | Model   | Effort |
| ----------- | ---------------------------------------------- | ----------------------------------------- | ------- | ------ |
| Supervisor  | — (you)                                        | Plan, delegate, gate, verdict             | inherit | high   |
| Tester      | `Agent(subagent_type: "subagent-tester")`      | Tests only; `acceptEdits`                 | sonnet  | medium |
| Implementer | `Agent(subagent_type: "subagent-implementer")` | Production changes; `acceptEdits`         | sonnet  | high   |
| Reviewer    | `Agent(subagent_type: "subagent-reviewer")`    | Read-only diff review; `dontAsk`          | sonnet  | medium |
| Simplifier  | `Agent(subagent_type: "subagent-simplifier")`  | Read-only simplification audit; `dontAsk` | sonnet  | medium |

Effort applies where the runtime exposes it (Codex `model_reasoning_effort`); on Claude Code the Model
column is the lever.

Agent definitions live in `~/.claude/agents/subagent-*.md`; if the session's agent list does not show them, stop and tell the user before Phase 2.

You coordinate. You do not edit files yourself unless the user explicitly asks.

### Runtime adapter

Abstract needs, per host. Delegate a role means "hand the role's `roles/<role>.md` body plus the ticket
brief to a fresh agent." Sources are cited per cell; a cell with no confirmed source says so.

| Need                                 | Claude Code                                                    | Codex CLI                                                                                                                                                                                                                                                                                                                                           |
| ------------------------------------ | -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Skill install path                   | `~/.claude/skills/supervised-dev`                              | `~/.agents/skills/supervised-dev` (user-level; repo-level is `<repo>/.agents/skills`) — symlink one dir to serve both: `ln -s ~/.claude/skills/supervised-dev ~/.agents/skills/supervised-dev`. Source: `developers.openai.com/codex/skills` (redirects to `learn.chatgpt.com/docs/build-skills`).                                                  |
| Delegate a role                      | `Agent(subagent_type: "subagent-<role>")`                      | No native subagent/spawn command found (R3; see `codex --help` command list, local codex-cli 0.153.2). Supervisor shells out per delegation: `codex exec -s <sandbox> --approve-for-me -m <model> -c model_reasoning_effort=<effort> "$(cat roles/<role>.md)"$'\n\n'"<ticket brief>"`. Source: local `codex exec --help`.                           |
| Write-capable role permissions       | `permissionMode: acceptEdits`                                  | `-s workspace-write --approve-for-me` (sandbox permits workspace writes; approvals routed through automatic review instead of prompting). Source: local `codex exec --help`.                                                                                                                                                                        |
| Read-only role permissions           | `tools:` list omits Edit/Write, plus `permissionMode: dontAsk` | `-s read-only` (sandbox blocks writes outright). Source: local `codex exec --help`.                                                                                                                                                                                                                                                                 |
| Model per role                       | `sonnet` (all four roles)                                      | unconfirmed — verify. No per-role Codex model recommendation found in R2/R4; only generic example ids (`gpt-5.6-terra` in docs, `gpt-5.3-codex-spark` in the local `codex-cli-runtime` skill for an unrelated "spark" mapping). Do not guess a model id.                                                                                            |
| Reasoning effort                     | No knob; the Model column is the lever                         | `-c model_reasoning_effort=<value>`, values `minimal, low, medium, high, xhigh`. Value vocabulary confirmed via local skill `.../codex/skills/codex-cli-runtime/SKILL.md` (`--effort` wrapper flag). Exact TOML key spelling `model_reasoning_effort` is unconfirmed — verify: `developers.openai.com/codex/config` returned HTTP 404 when fetched. |
| Ledger path                          | Session scratchpad (see Durable state)                         | `${TMPDIR:-/tmp}/supervised-dev/<branch>/`                                                                                                                                                                                                                                                                                                          |
| Continue a role agent across batches | `SendMessage` to the same agent                                | No native resume-a-role feature (R3). Use `codex exec resume --last` (or by session id) on that role's own subprocess session, sending only the delta instruction. Source: local `codex exec --help` ("resume Resume a previous session by id or pick the most recent with --last").                                                                |

Details, unconfirmed items, and a Codex smoke test: `references/codex-host.md`.

### Model, and the four-role cap

Model choice is the primary cost lever, not just a style knob. Pick a cheaper model for read-only roles;
step a role up only when the work demands it.

- Reviewer and simplifier run on `sonnet`. Review precision does not need the strongest model, so one
  cheap pass per SHA beats one expensive pass. Escalate a single re-review to the strongest available
  model only for a diff touching auth, credentials, or destructive operations.
- Step the implementer up to the strongest available model for demanding work: concurrency, teardown,
  wire formats, or a tracer unit that must establish the pattern for N siblings.
- **Never run a searching role on the cheapest model.** A cheaper model calls search and retrieval tools
  less and answers from memory instead. A simplifier that does this will assert "no consumer" without
  running the call-site grep that is the only thing making that finding admissible.
- Keep thinking enabled. Disabling it is the wrong cost lever — pick a cheaper model instead. With
  thinking off, an agent occasionally writes a tool call into its prose instead of calling the tool, and
  can leak internal XML tags into the return. A return that narrates a command it never ran is unexecuted
  work: re-delegate it, never read it as a result.
- A benign brief can come back as a **safeguard refusal**. Compile-check phrasing ("does this compile
  without errors?") and base64 blobs in tool output are the known triggers: ask "are there bugs in this",
  and never paste base64 into a brief. A refusal is a phrasing defect in your brief, not a finding, and
  not evidence about the code.
- **Four roles is the cap.** No fifth agent, and no subagent spawning its own. Current models delegate
  readily; a phase that feels like it needs another delegate has an underspecified brief, so fix the
  brief.

Effort-specific guidance below applies where the runtime exposes an effort knob (Codex); on Claude Code
pick the model tier instead.

- **Effort labels are not portable.** The same word buys different amounts of thinking on different
  models, so a level that worked for a role last quarter is a starting point, not a setting. Confirm
  against the model actually behind each role. (Codex; on Claude Code pick the model tier instead.)
- Step the implementer to `xhigh` only for demanding work: concurrency, teardown, wire formats, or a
  tracer unit that must establish the pattern for N siblings. (Codex; on Claude Code pick the model tier
  instead.)
- **Never run a searching role at `low`.** At low effort models call search and retrieval tools less and
  answer from memory instead. A simplifier at `low` will assert "no consumer" without running the
  call-site grep that is the only thing making that finding admissible. (Codex; on Claude Code pick the
  model tier instead.)
- At `xhigh` or `max`, leave `max_tokens` headroom for the thinking _and_ the output. A long deliverable
  can get drafted inside the thinking and written again as the reply, which doubles the turn and can
  truncate it. Long prose deliverables run at `high`. (Codex; on Claude Code pick the model tier instead.)

## Sequence

### Phase 1 — Scope

Inspect the repository to understand current state. Clarify only decisions with real consequences. Record:

- Exact file scope
- Acceptance criteria (pass/fail, not vague goals)
- Out-of-scope list
- Known decisions
- Architecture rules to pin: conventions this change must not break, read from the repo's `AGENTS.md`/`CLAUDE.md` and neighbouring code
- Verification command: the cheapest relevant check for the affected workspace, read from the repo's own docs — never guessed
- Full gate set: read it off what the repo's own `verify:local` / `verify:push` / CI phase scripts actually compose. Do not hand-write the list, and do not inherit one from a previous session's handoff. A gate you never listed is a gate nobody runs (incidents.md #1).
- Expected-red inventory: list the gates that are red by construction for the whole ticket, and record why — an end-state test can stay red for an entire sweep by design (incidents.md #2). Exclude these from the per-batch loop, never hand one to an implementer to "fix" into green, and route its teardown to a tester pass.
- Oracle per criterion: the exact command or state check that decides it. A criterion with no oracle is a wish — give it one or move it out of scope. You stop when the oracles pass, not when the work looks finished. When the build emits nondeterministic artifact names, the oracle must normalize before comparing (incidents.md #3).
- CI trigger map: read the repo's own workflow files and record what actually fires the gates Phase 8 depends on — including the branch filters, not just the event names. A push can fire no CI at all if the filters exclude it (incidents.md #4); read the filters in Phase 1, do not infer them from the event list.
- Capability preflight: confirm the tools the plan leans on actually work here, before planning around them — package registry reachability, auth for any host CLI, worktree cleanliness, write access (incidents.md #23). Never route around a failure by hand-editing a lockfile.
- Working branch or worktree: create it before recording base SHA, named per repo convention, and record the branch name in the ledger. A fresh worktree has no `node_modules`, so a bare `npx <tool>` inside it can resolve a different tool version than the main checkout — run formatters and linters from an installed tree, or install first.

Run: `git rev-parse HEAD` to record base SHA.

#### Brief hygiene

Every template below is a contract, not prose. Applies to all four roles:

- **Point, do not paste.** Give `path:symbol` and let the agent read it. Pasted file bodies go stale between phases and cost the same tokens twice.
- **State only the delta on re-delegation.** An agent you already briefed still holds the recipe; re-sending the whole ticket invites it to redo settled work.
- **Demand exact returns, and name the fields.** SHAs, counts as `passed/total`, verbatim failure text, and the commands actually run. Ban summary adjectives: "suite is green" is not a result; `854/854` is. Ask for the fields and the table explicitly — current models reach for structure less on their own, so an unspecified return format comes back as prose you have to parse.
  Ban _adjectives_, not status lines. Do not write "hold all findings for the final response" or otherwise suppress narration: models already go quiet through long tool chains, and a silent agent is indistinguishable from a stalled one. Ask for a line when it starts, a line when it changes direction, and the exact fields at the end.
- **A sent brief is not a started task.** After delegating, confirm the agent actually picked the work up — new commits, or an agent-list check — instead of assuming a delivered message equals work in progress (incidents.md #5).
- **Say the user is not watching.** Every brief opens with it: the agent is operating autonomously, nobody can answer mid-task, so "shall I apply this?" blocks the work. Reversible steps that follow from the brief proceed without asking; only destructive actions and genuine scope changes stop. Without this, an agent describes its next step and ends the turn, and the step stays undone until you reply.
- **Carry the scope clause.** Deliver what the brief asks at the scope asked; make routine judgment calls yourself; if the ticket looks mistaken, say so in one sentence and continue as asked rather than narrowing, widening, or transforming it. A pre-existing bug, a nearby performance smell, or undocumented behaviour found while working is a follow-up line in the return, not a change in this diff. Current models expand scope on their own judgment far more readily than they omit work, and an unasked-for improvement lands in the same diff the reviewer must clear.
- **Ask for surgical edits.** Say that edit tokens are to be minimized and a file should be patched, not rewritten, where that does not change the result. Left alone, models rewrite whole files for small changes — same content, but a diff the reviewer cannot read and a base SHA comparison full of noise.
- **Do not ask an agent to double-check itself.** Agents already verify their own work; "re-verify before reporting" or "add a final verification step" compounds with that and buys tokens, not quality. Brief the oracle instead — the exact command whose output decides the criterion. Supervisor verification is a different role reading a different signal, not the same agent looking twice.
- **Never brief a read-only role to be conservative.** "Only report high-severity issues" or "be conservative" is followed literally and suppresses real findings. Ask for everything at every severity; Phase 5 is the filter, and disproving a finding is cheaper than missing one.
- **Ban correction narration and mannered prose.** Returns state the final measured state, in direct language. An agent recounting what it first got wrong then fixed costs a re-read and buries the number you asked for, and metaphor in a return ("the dial worth turning") drags in connotations that make a fact ambiguous.

### Phase 2 — Tester first

Call `subagent-tester` with this template:

```
Ticket: <description>
Base SHA: <sha>
Acceptance criteria: <list>
Out of scope: <list>
Architecture rules to pin: <list from Phase 1>

Write two test classes:
1. Acceptance tests, one roughly per stated behavior. These must FAIL against
   the current production code — they assert what the ticket has not built yet.
2. Architecture-pin tests, one per architecture rule listed above. These assert
   a rule the change must not break, so they must PASS against the current
   production code. Their job is to catch the implementer breaking the rule
   later, not to fail now.
Do NOT fix production code.
Do NOT soften assertions.

Size the suite to the ticket, in the style and file layout of the neighbouring
tests. Scratch scripts and throwaway checks are yours to use and are NOT
committed as permanent test files.

Commit your test changes.
Return: test commit SHA, list of test files changed, which acceptance tests fail
and exact failure message, which architecture-pin tests pass and their names.
```

Wait for result. Confirm acceptance tests fail on base SHA and architecture-pin tests pass on base SHA. If tester edits production code, reject and re-delegate.

Count the committed test files against the criteria before accepting. Models over-commit tests on
open-ended briefs — scratch checks get promoted into permanent files, and every extra file is surface the
implementer must keep green and the reviewer must read. An unasked-for test file is an `in-diff` S1 for
the simplifier, and it is cheaper to reject it here.

### Phase 3 — Implement

Call `subagent-implementer` with this template:

```
Ticket: <description>
Base SHA: <sha>
Test commit SHA (do not modify these tests): <tester sha>
Acceptance criteria: <list>
Out of scope: <list>

You are operating autonomously; nobody can answer questions mid-task. Reversible
steps that follow from this brief proceed without asking. Stop only for a
destructive action or a real scope change.

Fix production code so the tester's tests pass.
Do NOT change test files or soften assertions.
Do NOT expand into other tickets. A pre-existing bug or nearby smell you find is a
follow-up line in your return, not an edit in this diff.
Do NOT rebase, merge, pull, fetch, or reset. If you think history must move, stop and report.
Patch files surgically; do not rewrite a whole file for a small change.
Oracle: <verification command from Phase 1>. Green on this command is the done condition.
Commit when done. Do NOT push.
Return: head SHA, changed files, verification commands run (fresh vs cached), deviations from ticket,
follow-ups you deliberately did not fix.
```

Wait for result. Confirm tester's tests pass at returned SHA without modification.

The rebase prohibition is not paranoia: an unasked rebase can move the base SHA and invalidate every later
comparison (incidents.md #6). Every "record the measured fact with its SHA" rule below collapses the
moment an agent can move the base underneath you.

Pushing is the supervisor's job, not the implementer's — see Phase 5. Then verify your own push actually
happened: "pushed" means "committed" until `git rev-parse <remote-ref>` says otherwise (incidents.md #7).
Run that command yourself after every push; do not trust the push command's own exit status as the signal.

#### Tickets made of repeatable units

When the ticket is N similar units (N services, N packages, N call sites), do not hand one agent all
N — a single oversized batch burns hours on archaeology for one file where a re-briefed batch does three
in the same span (incidents.md #8).

Batch for commit granularity and supervision, not for context — the model holds the whole ticket fine,
and it works best given the complete specification for its batch and then left alone. So each batch brief
carries the full spec for its units and nothing withheld. A batch briefed in fragments is a batch that
stalls on questions the ticket already answered.

- **Unit 1 is a tracer bullet.** Take one unit through every gate, including the aggregate-only ones —
  composed build, parity, boundaries. A pattern that passes unit-local tests and breaks the composed
  build is cheaper to find once than N times. That verified unit is then the canonical reference; name
  it in every later brief, or reviewers infer the pattern from whichever sibling they read first.
- Delegate **2–3 units per run**, and require a **commit per unit** before the next unit starts.
  Otherwise an agent finishes several units, holds them all uncommitted, and one interrupt loses the lot.
- Do the units that force a shared-config decision **last**, once the mechanical pattern is proven on
  the easy ones.
- Reuse the same agent across batches so it keeps the recipe, and state only the delta in each new brief.

#### Tier the gates

Knowing the full gate set does not mean running it per unit. Classify every gate by the smallest scope that
can change its result, and run it only at that tier — re-scanning the whole repo per batch to validate a
few new files catches almost nothing for the cost (incidents.md #9).

| Tier            | What belongs there                                                                                          |
| --------------- | ----------------------------------------------------------------------------------------------------------- |
| Per unit        | that workspace's own type-check, lint, unit tests — the mechanical-error class, in seconds                  |
| Per batch       | the aggregate-only gates whose failures interact: composed build, parity                                    |
| Once at the end | repo-wide scans no single unit can regress: boundaries, formatting, full browser suite, expected-red suites |

The tracer unit is the exception and still gets every gate — that is what makes it a tracer. Batches 2..N do not.

Split gate _ownership_ along the same line: the implementer runs the per-unit tier only, the supervisor owns
the per-batch and end tiers — a long gate handed to an implementer can burn the run in a stall-watchdog
retry loop instead of producing work (incidents.md #10).

#### Verify the report, do not transcribe it

An implementer's summary is a claim, not evidence. Re-run the numeric gates yourself and compare
counts — a report can round away real, flaky failures (incidents.md #11).

Your own commands lie the same way, through the shell rather than through prose. An exit code read
through a pipe is the **last stage's** status, not the command's (incidents.md #12). Read the pass/fail
counts out of the log, or the `EXIT=` line the script itself wrote — never the status the wrapper reports.

Establish your task runner's abort semantics in Phase 1, from its own docs. A runner that stops at the
first failing task reports a total that is a truncation, not a census, so the "N total" in a wide run is
not the size of the gate until you pass whatever flag makes it keep going.

Issue independent gates in one response. Type-check, lint, and unit tests for a batch do not depend on
each other's results, and in coding loops the default drift is one tool call per turn — each extra turn
costs a round trip and a full context read for nothing. Decide what you need next, then request all of it
that has no ordering dependency at once.

Also check the brief was actually obeyed: diff the units it claims to have done against the units you
asked for. An agent told to do one batch may quietly continue through the rest of the ticket. That is
not automatically wrong, but it means nobody supervised the later units, so they need the same
verification the first batch got, not less.

Cut the other way too, before blaming an agent for a diff it could not plausibly have produced: confirm the
SHA you are diffing _from_ is still an ancestor (`git merge-base --is-ancestor`) — a diff crossing an
orphaned fork point can look like agent damage that was never there (incidents.md #13).

### Phase 4 — Review and simplify (parallel, same SHA)

Call `subagent-reviewer` with this template:

```
Review the diff from base SHA <base sha> to head SHA <implementer sha>.

Ticket: <description>
Acceptance criteria: <list>

Run: git diff <base sha> <implementer sha>
Read the full diff and surrounding call paths.
Review production code and tests together.
Check error paths, edge cases, and false-green test risk.
Report every issue you find, at every severity. Do NOT pre-filter, and do NOT
withhold a finding for being uncertain — mark it uncertain and report it.
Do NOT edit files.
Do NOT post GitHub comments or touch any PR.
Return findings ranked by severity:
  P0: security, data loss, destructive behavior
  P1: correctness defect or explicit acceptance violation
  P2: valuable improvement, non-blocking
  P3: style or preference
For each finding: file, line, severity, problem, high-level fix.
```

Call `subagent-simplifier` with this template:

```
Audit the diff from base SHA <base sha> to head SHA <implementer sha> for simplifications.

Ticket: <description>
Acceptance criteria: <list>

Run: git diff <base sha> <implementer sha>
Read the changed files in full plus their call sites. Follow the code; do not guess.

Find surface this diff ADDED that costs more than it buys:
- New public method, export, config knob, event, helper, or type with no consumer outside tests
- Two representations of the same fact introduced by this diff
- Defensive copies, validators, or guards on values a typed same-process caller already guarantees
- Speculative generality: options, hooks, or extension points with no current caller
- Hand-rolled code where a maintained dependency or a runtime builtin already does the job, and the swap deletes the implementation plus its dedicated tests
- Added-then-unused test scaffolding, fixtures, or snapshot entries
- Comments that restate the code, or docs that duplicate a fact owned elsewhere

For each finding classify SCOPE, then SEVERITY.

SCOPE:
  in-diff:      the added surface is inside this diff
  pre-existing: the smell predates base SHA

SEVERITY:
  S1: removes real risk or real maintenance cost; net deletion is clear
  S2: worthwhile but optional
  S3: taste, speculative, or a wrapper that relocates complexity rather than deleting it

Prove each finding with a call-site search, not an impression. State the exact
symbol you searched and what you found. If a production consumer exists, say so
and drop the finding.

Do NOT edit files.
Do NOT post GitHub comments or touch any PR.
Do NOT propose feature changes or redesigns of code outside the diff.
Return: file, line, scope, severity, what to delete or fold, net lines removed, evidence.
```

The constraint is the SHA, not the ordering: both read-only roles must judge the same head, so no writer
may run and no phase may advance the head until both have returned. Nothing stops them reading it at the
same time. Dispatch the reviewer and the simplifier together, and spend the wait on your own per-batch and
end-tier gates at that same SHA — idling until each read-only agent returns costs wall-clock and buys
nothing. Never dispatch either alongside an implementer.

Wait for both results before freezing.

Blocking scope for these findings is defined in the Severity reference below.

A simplifier finding that is really a correctness defect is a **P1**, not an S-finding. Reclassify it and treat it as a review finding.

Reject any finding without a named symbol and a call-site search result. "This looks complex" is not a finding.

### Phase 5 — Freeze

Verify every finding against the code before it enters the list. Delegated review buys candidates, not
verdicts — a reviewer that reads a convention out of the ticket's recipe and applies it as a rule can turn
most of a finding list false (incidents.md #14).

Cheapest disproof first: open the file, run the grep, read the resolution. A finding that survives
enters the list with its evidence attached. A finding that dies is dropped silently — do not keep it as
a "possible", and do not hand it to the implementer to investigate.

Scope every surviving finding by **predicate, not enumeration**. A freeze entry that hands the implementer
a count instead of a check can simply have the wrong count (incidents.md #15). Write it as "every path in
`README.md` that no longer resolves", and hand over the check that decides it. This applies to the whole
class: renames, moved exports, deleted modules, dropped config keys. The finding is the property; the list
you wrote from one read is a guess.

A ticket acceptance criterion that turns out **half-met** is not a backlog item, and downgrading it is
not the supervisor's call. It is a scope decision: name the clause that is unmet, say what closing it
costs, and ask — filing a half-met criterion as backlog on your own can make the verdict false
(incidents.md #16).

Then combine reviewer findings, blocking simplifier findings, and your own five-axis check:

1. Ticket/spec fidelity
2. Runtime correctness
3. Architecture fit — the Phase 1 architecture rules, package boundaries, test conventions
4. Test integrity — can tests produce false green?
5. Delivery state — worktree clean, pushed, CI

Freeze the list; blocking scope is the same Severity reference.

Push the branch yourself now — the implementer only commits. Then verify the push actually happened with
`git rev-parse <remote-ref>`; do not read a push command's exit status as the signal.

Once the blocking set is frozen and pushed: if the Phase 1 CI trigger map says a PR is required to fire the gates
Phase 8 depends on, open the PR now, per repo convention, with the ticket and acceptance criteria in the
body. The PR is opened once; later fix cycles push to the same branch, not a new PR.

### Phase 6 — Fix frozen findings

If the blocking set is non-empty, call `subagent-implementer` again:

```
Fix only these frozen findings: <F1, F2, ...>
Current head SHA: <sha>

Simplification findings in this list are deletions, not redesigns. Remove the
named surface and its dedicated tests. Do NOT restructure adjacent code to
accommodate the deletion beyond what the deletion requires.

Do NOT redesign adjacent code.
Do NOT change tester tests.
Run targeted verification.
Commit when done. Do NOT push.
Return: new head SHA and targeted verification output.
```

No new scope after freeze. Push the new head yourself and re-verify with `git rev-parse <remote-ref>`,
same as Phase 5.

**Maximum two fix/retest cycles.** A third cycle requires a new P0/P1 introduced by the fix. A simplifier finding never justifies a third cycle.

Count the cycles explicitly and state the number in the verdict. When cycle 2 ends with any blocking finding still open, stop delegating: go to Phase 8, return verdict `blocked`, and name each unresolved finding with what it would take to close it. Do not open cycle 3 to keep trying.

A finding can be right about the risk and wrong about the remedy, and an automated reviewer's suggested
diff is the common case. Before applying one, check that it closes the path it names — otherwise the diff
looks fixed, the finding gets marked resolved, and the hole stays open with a comment claiming otherwise
(incidents.md #17). Apply it if it buys something real, but say in the code and the verdict which part of
the risk it does and does not remove.

### Phase 7 — Final retest

Call `subagent-tester` again:

```
Retest at SHA: <new head>
Base SHA: <base sha>
Run: <failing tests from blocking findings> plus affected regression tests.
No new scope. No new assertions.
Return: deliverable or remaining blocker with exact test names and failure output.
```

After the tester retest, dispatch the reviewer and the simplifier together on the new head SHA. Scope the
reviewer to `git diff <previous head sha> <new head sha>` plus the frozen-finding list: it judges whether
the fix closed each frozen finding, and whether the fix itself introduced a new P0/P1. If this was cycle 1
and a cycle 2 follows, re-run Phase 4 on the new head SHA. The simplifier sees each round, including the
deletions it asked for.

### Phase 8 — Verdict

Deliverable requires all of:

- All ticket acceptance criteria satisfied
- No unresolved P0/P1 findings
- No unresolved `in-diff` S1 findings
- Tester's original tests pass at exact head SHA without modification
- Worktree clean, commits pushed
- PR open (if CI needs one)
- CI green or external blocker explicitly named

Distinguish an infrastructure red from a code red before it reaches the verdict (incidents.md #18). Two
independent runs failing identically on the same non-code cause is the evidence that makes it nameable as
an external blocker, not a finding.

Do not report a performance or caching claim from two CI runs. Establish the job's run-to-run spread
first, and quote the number — a two-run "regression" can sit entirely inside natural spread
(incidents.md #19). If the mechanism alone settles it — a cache that recorded zero hits on the tasks that
matter saved nothing, whatever the clock says — claim the mechanism and leave timing out.

Delivery that rewrites already-published history is a **separate authorization from the work itself**.
"Rebase the branch onto master" authorizes the rebase; it does not authorize overwriting the head of an
open PR and superseding its CI. Ask for that explicitly. Then make it recoverable: park a local safety
ref at the old tip first, and pin `--force-with-lease=<branch>:<exact expected remote sha>` rather than
a bare `--force`, so a concurrent push by anyone else aborts yours instead of erasing it.

Lead with the verdict in the first sentence, then the section below. No preamble, and no walk through the
phases — the user does not need the pipeline narrated back. Keep each line to its fact.

Give the user a **For you** section:

- Decisions needed (if any)
- Risks to accept (if any)
- Merge recommendation: merge / hold / blocked + one-line reason
- Fix cycles used (0, 1, or 2)
- Blockers outside agent authority (if any)
- Backlog: deferred P2 and S2 findings plus pre-existing simplifications, one line each. P3 and S3 are dropped, not listed.

## Reading a red gate

A red gate is not automatically a regression, and not automatically a flake. Decide with evidence, in
this order, before spending a fix cycle:

1. **Re-run the failing test in isolation.** Green isolated but red under full parallel load points at a
   timing budget, not your diff. Record the numbers (incidents.md #20).
2. **Re-run the full gate once.** The same failure twice is a signal. A different failure, or green, is load.
3. **Ask whether the branch touches the file.** `git diff --stat <base> HEAD -- <path>` on the failing
   file and its imports.

Step 3 alone is not enough, and the reason matters: under a type-aware linter the failing file need not
be in your diff at all, because resolved types from a bumped dependency reach files you never edited. So
"not in my diff" can clear a flaky test, but never clears a lint or type error.

One failure mode is none of the three, because the gate **wrote** instead of failing — a saturated
parallel run can leave new snapshot files in packages the branch never touched (incidents.md #21). Run
`git status` after any wide test run, before you interpret the red — otherwise you diagnose the failure
and ship the artifact alongside the fix.

The verdict must name which of the three it is — regression (fix it), pre-existing (backlog, and confirm
it also fails at base SHA), or flake (state the isolation evidence). Never "probably flaky".

## Durable state

Long tickets outlive one context. Keep one compact ledger, at the ledger path from the adapter, and
update it at every phase boundary. A ledger written at the end is a report, and reports do not survive
interrupts.

```
Objective:
Base SHA:
Branch:
Current phase:
Decisions: (user's words + reason)
Units done: (unit → commit SHA)
Gates: (gate → result count → SHA measured at)
Expected-red:
Failed approaches:
Open findings:
Next action:
```

Keep it calibrated. Models pad written artifacts by default, and a ledger that grows summary sections is a
report again: facts, numbers, SHAs, one line each, no recap of what the phases were.

The ledger is what survives compaction, so it must carry what a summary drops. When context is compacted —
by you or by the harness — the entries that get lost first are exactly the ones you cannot re-derive:
constraints and decisions in the user's own words, approaches already tried and abandoned with the reason,
where things stand right now, what is still open, and exact details like SHAs, counts, and error text.
Write those verbatim in the ledger rather than trusting a summary to preserve them. Your own reasoning
compresses freely; what the user asked for and what a gate measured do not.

Two rules make a ledger safe to inherit:

- **Record measured facts with their SHA.** A gate result with no SHA cannot be reused and cannot be trusted.
- **Re-derive, never copy, anything the repo owns.** Gate lists, lint warning caps, test commands, and
  allowlists all drift. An inherited gate list is a hint about what mattered last time, not the gate set —
  recompute it in Phase 1 (incidents.md #22).

Keep the ledger at the ledger path from the adapter, never in the repo — not even untracked at the
worktree root. Never a tracked doc reviewers must read past. Durable conclusions belong in the ticket or
its follow-up; delete the ledger when the PR merges. Repo-wide formatters and linters typically scan the
**working tree**, not the index — every file on disk, tracked or not — so a ledger left in the repo can
fail the pre-commit or pre-push hook on its own formatting; a ledger path outside the repo avoids the
whole class.

## Stopping rules

- "Implementer done" ≠ deliverable. Tester, reviewer, and simplifier must evaluate the same SHA.
- Reuse fresh evidence. A gate that passed at this exact SHA with unchanged scope does not get re-run for
  reassurance. Re-run only when the SHA moved, scope changed, or the result was red.
- A gate result you did not see is not a result. Numbers from a subagent's summary get re-run before they
  reach the verdict.
- Verification is bounded by the oracles. Re-running a numeric gate you did not witness is evidence
  discipline; re-reading code that already cleared review, or adding a pass no criterion asked for, is
  over-verification — current models already self-check, so an extra pass compounds cost without changing
  the verdict. Named in Phase 1 or not run.
- Once acceptance passes on exact SHA and the blocking set is empty, stop. Do not look for optional improvements.
- P2 and S2 after freeze go to a follow-up ticket. P3 and S3 are dropped without a ticket.
- Do not ask the user technical questions answerable from the repo.
- The simplifier audits what this diff added. It does not open a repository-wide cleanup.

## Severity reference

| Level             | Meaning                                                 | Blocks?      |
| ----------------- | ------------------------------------------------------- | ------------ |
| P0                | Security, data loss, destructive behavior               | Always       |
| P1                | Correctness defect or explicit acceptance violation     | Always       |
| P2                | Valuable improvement, not required                      | No — backlog |
| P3                | Style, preference, speculative                          | No — dropped |
| S1 `in-diff`      | Diff added surface with no consumer; clear net deletion | Always       |
| S1 `pre-existing` | Real simplification, but predates this ticket           | No — backlog |
| S2                | Worthwhile simplification, optional                     | No — backlog |
| S3                | Taste, or relocates complexity without deleting it      | No — dropped |

Backlog means one line in the verdict and a follow-up ticket. Dropped means gone — do not list it, do not file it.
