# Supervised-dev incidents

Numbered war stories moved out of `SKILL.md` to keep the rules terse. Each entry
carries the rule it motivates and the story itself. SKILL.md points here as
`(incidents.md #N)`; nothing here changes the rule, which still lives in SKILL.md.

## 1. Omitted lint gate reached git push

**Rule:** Read the gate set off the repo's own verify scripts; never hand-write it or inherit one from a prior handoff.

**Story:** A ticket's owed-verification list omitted lint. The omission traced back to that same ticket's prerequisites commit. The gap survived all the way to `git push`, where the pre-push hook caught the real lint error nothing upstream had run.

## 2. The end-state test that stayed red on purpose

**Rule:** Expected-red gates are excluded from the per-batch loop and never handed to an implementer to fix into green.

**Story:** An architecture-rules suite asserted the ticket's END state — a test hardcoded the final allowlist — so it stayed red for the entire sweep. Re-running it per batch just read a counter (13 failures → 12 → 11 as units landed), not a gate.

## 3. Content hashes hid a real parity match

**Rule:** An oracle over nondeterministic artifact names must normalize before comparing.

**Story:** Bundler chunk filenames tracked module identity but carried content hashes, so raw file counts matched between builds while the names differed for legitimate reasons. Parity only became meaningful after stripping the hash suffixes and diffing story-ID sets instead of counts.

## 4. A push that fired no CI

**Rule:** Read the CI trigger map's branch filters in Phase 1, not just the event names.

**Story:** One repo's test workflow accepted `push` only for the default branch and a bot-prefixed branch. Pushing a feature branch produced no CI run at all, and the "CI green" criterion stayed unreachable until a PR existed. The workflow had been misread as having no `push` trigger, when the trigger existed but was filtered.

## 5. A brief that was sent but never picked up

**Rule:** After delegating, confirm the agent actually started — new commits or an agent-list check — rather than trusting that a delivered message means work in progress.

**Story:** One batch brief was queued but never consumed: the agent had already ended its turn, so nothing ran and no files appeared until the brief was re-sent.

## 6. A rebase that moved the base out from under the pipeline

**Rule:** Implementers never rebase, merge, pull, fetch, or reset; if history must move, they stop and report.

**Story:** One implementer rebased its branch onto `origin/master` unasked. That rewrote the frozen tester commit, moved the base SHA, and silently invalidated the parity baseline every later comparison depended on.

## 7. "Pushed" meant "committed"

**Rule:** Verify a push with `git rev-parse <remote-ref>`; never take an agent's word that it pushed.

**Story:** One implementer reported "all pushed to this branch" while the remote ref was still an unknown revision — nothing had actually reached the remote.

## 8. Two hours of archaeology for one file

**Rule:** Batch repeatable units at 2-3 per run instead of handing one agent the whole N-unit ticket.

**Story:** A 14-unit brief spent roughly two hours on dependency archaeology and produced one file. The same agent, re-briefed at 2-3 units with the pattern already extracted from the finished ones, did three units in about the same span.

## 9. Re-scanning 13,211 files to catch one defect

**Rule:** Tier gates by the smallest scope that can change their result; only the tracer unit gets every gate.

**Story:** A 13-unit sweep re-ran `format:check` over 13,211 files and a boundaries scan over 17,281 files / 141 packages after every batch, to validate roughly 16 new files per unit. Across the six units after the tracer, those per-unit-scale gates caught exactly one real defect.

## 10. An implementer stuck in its own retry loop

**Rule:** The supervisor owns the per-batch and end-tier gates; the implementer runs only the per-unit tier.

**Story:** An implementer handed a long browser-test gate hit the stall watchdog three times, every time inside the same retry loop, burning the run without producing work.

## 11. 854/854 that was actually 852/854

**Rule:** Re-run the numeric gates yourself and compare counts; a subagent's summary is a claim, not evidence.

**Story:** In one ticket the agent reported a suite at 854/854 when the run had actually been 852/854. The two failures were real, just flaky, and the report rounded them away.

## 12. The exit code that belonged to `tail`

**Rule:** Read pass/fail counts out of the log, or an explicit `EXIT=` line the script wrote — never the wrapper's exit status.

**Story:** `<suite> | tee log | tail` reports `tail` succeeding while the suite itself was `2 failed | 852 passed (854)`. A compound `cmd > log; echo EXIT=$?; tail log` hands the harness `tail`'s exit code, not `cmd`'s.

## 13. A lockfile diff that crossed a fork point

**Rule:** Before blaming an agent for a diff, confirm the SHA you're diffing from is still an ancestor (`git merge-base --is-ancestor`).

**Story:** A supervisor diffed a lockfile from a remembered SHA, saw alarming unrelated deletions, and concluded agent damage. A rebase had orphaned that SHA, so the diff crossed a fork point and swept in unrelated changes from the main branch. The agent's real delta was 34 added lines.

## 14. Three false findings from one borrowed convention

**Rule:** Verify every finding against the code before it enters the frozen list; delegated review buys candidates, not verdicts.

**Story:** Three of four findings in one ticket were false, and all three failed the same way: the reviewer read a convention out of the ticket's recipe and applied it as a rule. It called a declared dependency unused (a story file imports it), a package missing from the catalog (present under its real package name, not the app name), and two presets missing a Vite alias (they resolve by workspace symlink, exactly like the recipe's own reference example).

## 15. Four stale bullets that were actually seven

**Rule:** Scope a freeze finding by predicate, not by an enumerated count.

**Story:** A freeze entry reading "fix the four stale bullets in `README.md`" handed the implementer a count, and the count was wrong — the file held seven stale references. That one finding took three commits to close, two of them after the ticket was already believed done.

## 16. Met for X, unmet for ninety instances of Y

**Rule:** A half-met acceptance criterion is a scope decision for the user, not a backlog downgrade the supervisor makes alone.

**Story:** One criterion of the form "remove X and remaining Y" was met for X and unmet for roughly ninety instances of Y. Filing that as backlog would have made the verdict false; the user chose to ship the met half and follow up, a decision only they were entitled to make.

## 17. The fix that gated the wrong half

**Rule:** Before applying a finding's suggested diff, check that it actually closes the path it names.

**Story:** A security finding about credentials on untrusted input was correct. Its suggested diff gated the step that used the credential while leaving in place the grant that let the same code mint one directly.

## 18. A rate limit that looked like a finding

**Rule:** Two independent runs failing identically on the same non-code cause is what makes an infrastructure red nameable as an external blocker.

**Story:** A genai review job failed twice with `exceeded rate limit` against its model deployment. That is an external blocker to name, not a finding, and no change on the branch would have closed it.

## 19. A 10.7-second regression inside a 16-second noise floor

**Rule:** Establish a job's run-to-run spread before reporting a performance or caching claim from two CI runs.

**Story:** One before/after pair read as a 10.7s cache regression on a 31-suite browser job. A third run with no cache at all came in slower than both, putting the spread at ≥16s and the "regression" inside noise.

## 20. 1020ms against a 1000ms budget

**Rule:** Re-run a failing test in isolation before charging it to your diff; a timing budget is not a regression.

**Story:** One case timed out at ~1020ms against a 1000ms budget under full parallel load, and passed 7/7 when run in isolation.

## 21. Snapshots written by packages nobody touched

**Rule:** Run `git status` after any wide test run before interpreting a red result — a gate can write instead of fail.

**Story:** Test runners that create missing snapshot keys rather than erroring, under a saturated parallel run, left empty-render snapshots on disk in packages the branch never touched.

## 22. The checklist that was missing lint

**Rule:** Re-derive the gate list from the repo in Phase 1; never copy an inherited one.

**Story:** The one incomplete gate list in this pipeline's history came from exactly that — a checklist inherited verbatim from a previous session's handoff, missing lint.

## 23. A registry that 403s intermittently

**Rule:** Confirm the tools the plan leans on actually work here before planning around them — package registry reachability, auth for any host CLI, worktree cleanliness, write access.

**Story:** A private registry that 403s intermittently will strand an agent mid-ticket if the plan assumed a fresh install could proceed.
