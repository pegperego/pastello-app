# 0001. Record architecture decisions

- **Status:** accepted
- **Date:** 2026-10-24

## Context

The project is open source and is meant to be maintained by a community.
Future contributors need to understand why the code is shaped the way it is,
not only how.

## Decision

We record every significant architecture decision as a short Markdown file in
`docs/adr/`, numbered sequentially and based on
[`0000-template.md`](0000-template.md). Decisions are first explored in the
Italian analysis notes (`analisi/`) and then summarized here in English once
accepted.

## Consequences

- The history of decisions is versioned together with the code.
- A decision is never deleted: when it changes, a new ADR supersedes it.
