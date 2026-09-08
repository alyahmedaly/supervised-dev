# Plan shape

A plan groups N tickets that share a decision.

## Frontmatter

```yaml
---
title: <imperative, one line>
status: proposed | active | done
created: YYYY-MM-DD
owner: <name>
tickets_dir: docs/<program>/tickets
---
```

## Sections, canonical names, in this order

- `## Goal` — what the plan achieves, one paragraph.
- `## Decision` — the chosen approach, plus its alternatives, one bold-led paragraph each. A decision the
  user answered in the plan pass (see SKILL.md "Intent pass") is tagged `user-decided` and carries their
  own words; tickets reference it and never re-ask it.
- `## Invariants` — rules every ticket in the plan pins.
- `## Tickets` — table: id linked to file, one-line outcome, effort `S|M`.
- `## Dependency chain` — fenced text arrows.
- `## Non-goals` — what the plan deliberately does not do.
- `## Rollback` — one ticket = one PR; rollback is one ticket wide.

## Rules

- No ticket in the table carries effort `L` — split it into smaller tickets first.
- Ticket links are relative to the plan's own directory, not the repo root.
- Tickets that force a shared-config decision go last, once the mechanical pattern is proven on the
  easy ones.
- The dependency chain is serial wherever tickets touch the same files.

## Worked example

| id                                          | outcome                                   | effort |
| ------------------------------------------- | ----------------------------------------- | ------ |
| [038](tickets/038-rename-report-columns.md) | Rename report columns to snake_case       | S      |
| [041](tickets/041-format-json-flag.md)      | Add `--format table\|json` flag to report | S      |
| [042](tickets/042-json-in-ci-summary.md)    | Wire JSON output into the CI summary job  | M      |

```
038 --> 041 --> 042
```
