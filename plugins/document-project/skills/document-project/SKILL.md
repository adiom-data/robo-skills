---
name: document-project
description: >-
  Create or update product and technical documentation for an existing GitHub
  project: AGENTS.md as the canonical agent guide and CLAUDE.md as a pointer to
  it (root), PRD.md as a versioned Product Definition Document (root), a
  human-readable README.md (root), and topic-per-file deep dives under docs/
  (architecture, data flows, workflows, data model, integrations, operations,
  testing, and invariants). Use when the user asks to document or refresh a
  project, write/update a PRD, create AGENTS.md/CLAUDE.md, define system
  invariants, or bring stale docs back in line with the code.
---

# Document a project

Produce documentation an agent can consume quickly and a maintainer can keep current. Output is
grounded in source (verified, not guessed) and organized so each topic lives in exactly one file.
This covers both the **technical** picture (how the system is built) and the **product** picture
(what it's for and what must hold), plus a bridge between them: the invariants.

This skill is a self-contained superset of plain codebase documentation — it adds a Product
Definition Document, an invariants doc, and explicit git-commit trust rules for existing docs.

## When to use

- The user asks to document a project, refresh stale docs, or onboard agents to a codebase.
- Create or update `AGENTS.md` / `CLAUDE.md` / `README.md`.
- Write or update a Product Definition Document (`PRD.md`).
- Define or revise the system invariants.
- Bring documentation back in line after architecture changes or new features.

## Output structure

```
AGENTS.md          # root — canonical agent entry point (technical hub)
PRD.md             # root — Product Definition Document (versioned)
CLAUDE.md          # root — thin pointer to AGENTS.md (preserve required header line if present)
README.md          # root — human-readable intro
docs/
  README.md        # index: one-line "read this when…" per doc + authoritative review marker
  architecture.md  # components, system topology, features, public APIs/proto services
  data-flows.md    # how data moves end-to-end: lifecycle of each key entity/request/event
  workflows.md     # core runtime flows, state machines
  data-model.md    # datastores, entities/tables, relationships, identity resolution
  integrations.md  # every third-party service + the single env-var reference
  operations.md    # runbook: build, local dev, migrations, images, publish, deploy
  testing.md       # how to run tests (incl. a single test) and where they live
  invariants.md    # human-readable statements that MUST hold (fusion of PRD + technical design)
  <domain>.md      # extra project/domain-specific docs as the project warrants
```

**Placement rule:** everything lives under `docs/` **except** `AGENTS.md`, `PRD.md`, `CLAUDE.md`,
and `README.md`, which stay in the repo root. Topic-per-file is the default so a change lands in one
place. Drop docs that don't apply; add domain-specific ones. Confirm scope/granularity with the user
only if genuinely ambiguous (e.g. a monorepo with many services) — otherwise use this layout.

## Trust existing docs only as far as their commit marker

Before reusing any existing doc, decide how much to trust it:

- **Has a commit marker** — a doc with `<!-- Last reviewed against commit <sha>. -->` (or a PRD
  changelog row naming a commit). Verify the sha is real and is in the history of the branch you are
  on, then trust the content up to that commit and only investigate changes since:
  ```sh
  git cat-file -e <sha>^{commit}                 # sha exists as a commit
  git merge-base --is-ancestor <sha> HEAD        # exit 0 ⇒ sha is in this branch's history
  git diff --stat <sha>..HEAD                     # what changed since the doc was reviewed
  ```
  If both checks pass, assume the doc is accurate as of `<sha>`; focus your work on the delta
  (`git diff <sha>..HEAD`) and update only what moved.
- **No marker, or the sha is unknown / not an ancestor of HEAD** — treat the doc as **potentially
  inaccurate and incomplete**. Re-derive its claims from source rather than trusting them.

## Procedure

### 1. Explore in parallel — gather grounded facts
Launch a few **Explore agents concurrently** (one message, multiple tool calls), each owning a
distinct slice so they don't overlap. Typical split:
- **Data model**: every schema/migration/model file → tables/entities, keys, relationships,
  identity resolution, historical/dropped pieces.
- **Core workflows / orchestration**: the main runtime path → entrypoints, state machines, queues,
  background jobs, invariants (idempotency, retries, dedup, leasing).
- **Integrations & subsystems**: each third-party service and cross-cutting subsystem → how it's
  wired (env vars, auth method, which component uses it), with file:line refs.
- **Data flows**: trace each major piece of data end-to-end — where it enters, every component and
  datastore it passes through, how it's transformed, where it's persisted/read, and where it exits.

Tell each agent to return **concrete function names, file paths, and line refs** — not prose. Read
the build system, existing README/docs, and any design notes yourself. Separately, gather **product
context** for the PRD: README, design notes, issue/PR discussions, marketing/landing copy, and any
existing PRD. Note explicitly what product information is *absent* — you'll mark those `<MISSING>`.

### 2. Decide structure and reconcile existing docs
- Apply the commit-marker rule above to every existing doc.
- Map the requested topics (codebase organization, code-org principles, runbook, testing,
  architecture, features, components, entities, workflows, invariants, integrations) onto the files
  above.
- Find stale/duplicate docs. Consolidate design notes + runbooks into the right topic file and
  delete the originals to prevent drift (confirm deletions if any are tracked and non-obvious).

### 3. Write the technical docs
- **AGENTS.md** is the stable hub. Include: a 2–3 sentence system summary + any naming/path gotcha;
  a repository-layout table; a build/test/run quick reference (link out, don't duplicate); a
  **"Code organization principles"** section capturing the *non-obvious* conventions (codegen,
  generated-vs-checked-in, build-graph/dep rules, multi-datastore footguns, graceful-degradation
  patterns, identity keys); a **documentation map** (links to PRD.md, docs/, invariants.md); and a
  **"Keeping docs current" table** mapping code areas → the doc to update. This table is the
  maintainability contract — make it specific.
- **CLAUDE.md** → short pointer to AGENTS.md; preserve its required Claude Code header line if one
  exists.
- **README.md** → human-facing: one paragraph on what it is, an ASCII flow diagram, a quick start,
  and links into AGENTS.md, PRD.md, and docs/. Drop stale framing.
- **docs/** topic files → use tables for component/env/entity references; centralize the env-var
  reference in integrations.md (other docs link to it) so a new var has one home.
- **data-flows.md** → document each major data path as its own subsection, ordered from entry to
  exit. For each flow: an ASCII diagram of the hops (`source → component → store → …`), a numbered
  step list naming the exact function/component at each hop, what data is read/written at each store,
  the transformations applied, and the identifier that threads the flow. Call out sync vs async
  boundaries (queue/event/RPC). Keep component *topology* in architecture.md and *control-flow /
  state-machine* logic in workflows.md; cross-link rather than repeat.
- Match the repo's existing terminology. State precisely *which component does what*.

### 4. Write the Product Definition Document (PRD.md)
Fill the PRD skeleton below with **grounded** information only. Rules:
- Never invent facts and never silently skip a section. If information isn't available, write
  `<MISSING>` (optionally with a short note on where it might come from).
- Keep it versioned: bump the `Version` header and add a changelog row whenever the PRD changes.
- Distinguish what the product *does today* from aspirations; label the latter clearly.

### 5. Write the invariants (docs/invariants.md)
An invariant is a human-readable statement that MUST hold for the system to operate correctly — a
fusion of product intent and technical design. Example: the PRD says users can sign in via Google or
Facebook ⇒ the invariant is "the same user sees the same data regardless of which provider they log
in with." For each invariant record: the MUST statement, its rationale, its source (which PRD
requirement and/or technical doc it derives from), and where it's enforced in code (or
`<UNENFORCED>` if nothing guarantees it — that's a finding worth surfacing).

### 6. Verify against source — don't trust agent summaries blindly
Explorer summaries can be wrong; spot-check load-bearing claims by reading the cited code. Then run
mechanical checks:
- **Links resolve** — every relative markdown link target exists (snippet below).
- **Commands exist** — each documented build/test/run command is a real target/script.
- **Env vars & entities exist** — grep each documented env var and table/entity name in source.
- **Invariants are real** — for each invariant, confirm the enforcement you cited actually exists, or
  mark it `<UNENFORCED>`.

```sh
# Broken intra-repo markdown links
for f in AGENTS.md README.md CLAUDE.md PRD.md docs/*.md; do d=$(dirname "$f");
  grep -oE '\]\(([^)]+)\)' "$f" | sed -E 's/\]\(([^)]+)\)/\1/' | while read -r l; do
    case "$l" in http*|"#"*) continue;; esac; t="${l%%#*}"; [ -z "$t" ] && continue;
    [ -e "$d/$t" ] || echo "MISSING: $f -> $l"; done; done
```

### 7. Stamp review markers
Record the commit the docs were verified against so staleness is visible later:
```sh
git rev-parse --short HEAD
```
- Authoritative note in `docs/README.md`, plus a per-doc header on the most volatile docs (usually
  architecture.md and data-flows.md):
  ```markdown
  <!-- Last reviewed against commit <sha>. Bump when revised against newer code. -->
  ```
- Add a changelog row to `PRD.md` naming the same `<sha>`.

## Document skeletons

Copy these and fill them in. Adapt headings to the project; delete sections that genuinely don't
apply rather than leaving them empty (except PRD sections, which use `<MISSING>`).

### AGENTS.md
```markdown
<!-- Last reviewed against commit <sha>. -->
# <Project> — agent guide

<2–3 sentence system summary. Call out any naming/path gotcha up front.>

## Repository layout
| Path | What lives here |
|------|-----------------|
| ... | ... |

## Build / test / run
<Quick reference. Link to docs/operations.md and docs/testing.md; don't duplicate.>

## Code organization principles
<Non-obvious conventions: codegen, generated-vs-checked-in, dependency rules, datastore footguns,
identity keys, graceful-degradation patterns.>

## Documentation map
- [PRD.md](PRD.md) — product definition (what & why)
- [docs/architecture.md](docs/architecture.md) — components & topology
- [docs/invariants.md](docs/invariants.md) — what must always hold
- ... (link every doc)

## Keeping docs current
| When you change … | Update … |
|-------------------|----------|
| <code area> | <doc> |
```

### CLAUDE.md
```markdown
<!-- keep any required Claude Code header line that already exists here -->
See [AGENTS.md](AGENTS.md) for the canonical project guide. This file intentionally defers to it.
```

### README.md
~~~markdown
# <Project>

<One paragraph: what it is and who it's for.>

```
<ASCII flow diagram of the system at a glance>
```

## Quick start
<Minimal steps to run it.>

## Learn more
- [PRD.md](PRD.md) — product definition
- [AGENTS.md](AGENTS.md) — contributor/agent guide
- [docs/](docs/) — architecture, data flows, operations, testing, invariants
~~~

### PRD.md
```markdown
# <Project> — Product Definition Document

**Version:** 0.1
**Status:** Draft | Active | Deprecated
**Last reviewed against commit:** <sha>

## Changelog
| Date | Version | Change | Commit |
|------|---------|--------|--------|
| YYYY-MM-DD | 0.1 | Initial PRD | <sha> |

## 1. Overview
<What the product is and the problem it solves. `<MISSING>` if unknown.>

## 2. Target audience & personas
<Who uses it; key personas and their context. `<MISSING>` if unknown.>

## 3. User goals
<What users are trying to accomplish. `<MISSING>` if unknown.>

## 4. Key features
<The core capabilities, grounded in what exists. Label aspirational items.>

## 5. Core entities
<The main domain objects and what they represent. Cross-link to docs/data-model.md.>

## 6. Core workflows
<The main end-to-end user/system workflows. Cross-link to docs/workflows.md.>

## 7. Functional requirements
<What the system must do. `<MISSING>` if not derivable.>

## 8. Non-functional requirements
<Performance, scale, security, availability, compliance. `<MISSING>` if unknown.>

## 9. Success metrics
<How success is measured. `<MISSING>` if unknown.>

## 10. Risks & dependencies
<Known risks, external dependencies, assumptions. `<MISSING>` if unknown.>
```

### docs/invariants.md
```markdown
<!-- Last reviewed against commit <sha>. -->
# Invariants

Statements that MUST hold for the system to operate correctly — a fusion of product intent (PRD) and
technical design. Each links back to where it comes from and where it's enforced.

## INV-1: <short title>
- **Statement:** <The system MUST …>
- **Rationale:** <Why this must hold.>
- **Source:** PRD §<n> / [docs/<doc>.md](<doc>.md)
- **Enforcement:** <file:func that guarantees it, or `<UNENFORCED>`>

## INV-2: <short title>
- ...
```

### docs/README.md
```markdown
<!-- Last reviewed against commit <sha>. Authoritative review marker for all docs. -->
# Documentation index

| Doc | Read this when … |
|-----|------------------|
| [architecture.md](architecture.md) | you need the component map / topology |
| [data-flows.md](data-flows.md) | you're tracing how data moves |
| [invariants.md](invariants.md) | you need the rules that must always hold |
| ... | ... |
```

## Quality bar
- **Grounded** — every non-trivial claim traceable to source you (or a verifier) actually read.
- **Non-redundant** — one fact lives in one place; other docs link to it.
- **Maintainable** — the "Keeping docs current" table tells a future editor exactly where each
  change goes.
- **Honest about gaps** — use `<MISSING>` (PRD) and `<UNENFORCED>` (invariants) instead of guessing
  or skipping.
- **No filler** — skip generic advice ("write tests", "handle errors"); document only what's
  specific and non-obvious about *this* project.

## Notes
- This skill is a self-contained superset of basic codebase documentation; it adds the PRD,
  invariants, and the commit-marker trust rules on top.
- Commit/push only when the user asks.
