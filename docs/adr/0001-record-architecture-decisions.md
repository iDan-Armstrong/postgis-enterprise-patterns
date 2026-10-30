# ADR-0001: Record architecture decisions

**Status:** accepted

## Context

Database architecture outlives the people who chose it. Six months in, "why is
everything 4326?" gets asked in every project, and the answer lives in someone's
memory or nowhere.

## Decision

Keep Architecture Decision Records in `docs/adr/`, one file per decision, in the
format context → decision → consequences. A decision isn't made until it's written
down; superseding a decision means a new ADR that links the old one, never editing
history.

## Consequences

Reviewers see the *why* alongside the *what* in the same PR. New team members read
four short files instead of reverse-engineering intent from DDL. The discipline
costs ~20 minutes per decision.
