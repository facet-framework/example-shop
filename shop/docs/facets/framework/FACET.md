# The FACET Framework 0.1.0

**Feature-Anchored Canonical Executable Truth**
_A specification for product-feature documentation as single source of truth, designed for the age of AI-assisted development._

**Status:** Reference specification
**Version:** 0.1.0
**License:** Apache-2.0

> **Implementation scope (informative).** This document defines framework requirements; the source release does not claim complete implementation of every reference interface or projection. Its bundled MCP server exposes five of the twelve reference tool names in §6.2: `feature_find`, `feature_get`, `anchor_resolve`, `anchor_list` and `registry_validate`. The other seven reference tool names and the optional feature-proposal interfaces in §6.4 are not supplied under those names. Additional tools do not establish full conformance. This repository provides the registry engine and CLI, together with agent skill bundles and the plugin and marketplace files that install them into Claude Code and Codex. The local reader is not included; it belongs to Atlas, a separate product that is not included in this release. Generator integrations described here are deployment responsibilities, not a claim that this release supplies every pipeline.

---

## Contents

1. [Overview](#1-overview)
2. [Core Model](#2-core-model)
3. [The Seven Facets](#3-the-seven-facets)
4. [Adjacent Entities](#4-adjacent-entities)
5. [The Feature Registry](#5-the-feature-registry)
6. [The Agent Interface](#6-the-agent-interface)
7. [Projection Tiers and Caching](#7-projection-tiers-and-caching)
8. [Adjacent-Surface Consistency](#8-adjacent-surface-consistency)
9. [Scope Boundary](#9-scope-boundary)
10. [Authoring Workflow](#10-authoring-workflow)
11. [Drift Detection and Integrity](#11-drift-detection-and-integrity)
12. [Change Management](#12-change-management)
13. [Adoption Path](#13-adoption-path)
14. [Appendix A — Reference Schemas](#appendix-a--reference-schemas)
15. [Appendix B — Summary of Changes](#appendix-b--summary-of-changes)

---

## 1. Overview

FACET is a documentation framework that treats each product feature as a first-class, addressable object in the codebase. A feature is described by a structured record with seven facets — **Intent, Contract, Anchor, Verification, Observation, Knowledge, Lineage** — and lives next to the code it anchors. Records are indexed by a central Feature Registry and accessed through both a human-readable view and a machine-readable API.

FACET is designed to satisfy three simultaneous constraints:

1. **Single source of truth** for behavioral, operational, _and user-knowledge_ claims about features.
2. **Executable integrity** — records cannot silently drift from the code they describe.
3. **Agent-native access** — AI coding agents can locate, read, verify, and update records with the same primitives humans use.

FACET defines the agent-interaction surface and how records coexist with adjacent documentation. The **Knowledge** facet drives user-facing documentation through the generator path in §8.5. Generation freshness (§8.6) detects when the source inputs of generated documentation change.

---

## 2. Core Model

### 2.1 Unit of documentation

The unit of documentation is the **feature**: a named, coherent capability of the product that can be reasoned about, changed, and owned independently. Granularity is chosen such that a feature:

- Has a clearly identifiable purpose in the product
- Is implemented in code that can be pointed to
- Has behavioral rules that can be stated as contracts
- Has an owner (team or individual) responsible for it

Neither "a single function" nor "the entire checkout domain" is a feature. A feature is closer to "discount code redemption," "GDPR erasure processing," or "payment retry with backoff."

The last of that judgment cannot be automated. Most of it should not be left open either: a deployment that says only the above gets records two orders of magnitude apart in granularity for comparable products, because whoever writes them has to invent the policy and nobody writes the policy down. §2.1.1 is that policy.

### 2.1.1 The sizing test

A candidate is feature-sized — record-sized — when **all five** gates hold. Four of five almost always means the candidate is one id segment away from correct: go up a level, or go down one.

**1. The name gate.** It can be named as `<verb> the <object>`, or as a noun phrase a user would say unprompted. The name contains no "and", and no technology word.

> "Invite a collaborator to a playlist" passes. "PlaylistService" does not — a component. "Playlists and sharing" does not — the "and" is the split line. "Redis-backed session cache" does not — a mechanism.

**2. The sitting gate.** One user, one sitting, one outcome they would call done. Above that line — a goal spanning sessions, or belonging to the product rather than to a person — is a capability or a domain. Below it — a step nobody would ask for on its own — is a scenario.

> "Create a playlist" passes. "Manage my music" is above it. "Validate the playlist title" is below it.

**3. The contract gate.** It has between two and nine observable scenarios, including at least one failure path. Fewer than two, and there is nothing to contract about: it is a scenario of its parent. More than nine, and the scenarios have started clustering into groups that do not reference each other; those clusters are the features.

This is the only gate a machine can evaluate, which makes it the only one that catches a mis-sized record with no reviewer present. Tooling SHOULD report it (§11.2).

The count is of scenarios, not of cases. A Scenario Outline (§3.2.3) states one rule and counts as **one** scenario however many rows its `examples` blocks carry — otherwise this gate would penalise the consolidation §3.2.3 requires, and the cheapest way to pass it would be to write the cases back out as prose.

**4. The removal gate.** You can say in one sentence what a user loses if it is removed, and the product still stands without it. No sentence means it is implementation, and belongs to an anchor rather than to a record. A product that falls over means it is not separable from its parent, and belongs there as a scenario.

**5. The owner gate.** One team could own it, and would recognise the name on a roadmap. Two teams that must both agree means the boundary is drawn across a seam rather than along it.

#### When both readings pass

Two candidate decompositions will regularly both pass all five. Then:

> **Prefer the coarser record with more scenarios.**

This is an asymmetry in what the two mistakes cost, not a stylistic preference. A scenario is cheap: an id unique within its record, a statement, no anchor, no owner, no lineage edge, no Knowledge slots. A record is expensive: an id immutable for the life of the product (§2.2), at least one anchor to maintain, an owner, five Knowledge slots that warn while empty, and a node in the dependency graph.

So splitting a record later is mechanical — scenarios move into a new file and the anchors gain a second id. Merging two records later costs two immutable ids, a `superseded_by` on both, and a redirect that outlives everyone who remembers why. The costs are not symmetric, so the default must not be either.

#### What is not a feature

Each of these has a home already, and putting it in a record of its own is how a registry acquires records nobody maintains:

| Candidate | What it is |
| --- | --- |
| A service, controller, store, hook, module, util | implementation — an `@facet:` anchor on a record (§3.3) |
| One CRUD verb of a set with no distinct rules | one scenario of the feature that owns the object |
| A screen, page, or route | the answer to `knowledge.discoverability` (§3.6) |
| An API endpoint | implementation, unless the API is the product surface |
| A feature flag or config switch | `flags[]` (§3.8) — exposure, not existence |
| A bug fix | `defects.fixes[]` (§3.9) |
| A bug that is still there | a `deviation` on the scenario describing what the code does (§3.2.2) — never a record of its own, and never a record of the behaviour it ought to have |
| A rewrite, or a second client of the same feature | a variant (§2.4) — never a second record |
| Something serving one other feature, with no name of its own | a scenario there, or a `lineage.depends_on` edge |
| A non-functional property — "fast", "accessible", "compliant" | `observation` SLOs (§3.5), or a policy record (§4.1) |

### 2.2 Canonical identifiers

Every feature has a canonical, stable identifier of the form:

```
<domain>/<capability>/<feature>
```

Examples:

- `checkout/pricing/discount-code-redemption`
- `identity/session/refresh-token-rotation`
- `catalog/search/ranking-personalization`

Rules for IDs:

- Lowercase kebab-case in each segment
- Exactly three segments
- Domain segment corresponds to a **product** domain in the organization's domain model, and never to a team or a service. Teams reorganise and ids do not, so an id built from an org chart is wrong on a schedule; the organisational axis is `lineage.owner.team`, which exists precisely so the two stay apart. Where a deployment declares a taxonomy (§4.4), the domain and capability segments MUST resolve against it
- IDs are immutable after creation; renames produce a new ID plus a redirect record

### 2.3 Record location

FACET does not require a feature-based repository layout. The authoritative bridge between a feature and its code is the set of `@facet:` tags in source files (see §3.3), not the physical location of the `facet.yaml`. A deployment chooses one of three layouts:

**Co-located layout.** The `facet.yaml` lives next to the feature's primary implementation:

```
<repo-root>/<path-to-feature>/facet.yaml
```

Works well when the codebase is organized around features or bounded contexts. Pleasant because related artifacts sit together. Good default for new or feature-oriented codebases.

**Centralized layout.** All records live in a dedicated documentation tree, regardless of where the code lives:

```
<repo-root>/docs/facets/<domain>/<capability>/<feature>.yaml
```

Works for any codebase, including codebases organized horizontally by technical layer (e.g., `/components`, `/stores`, `/api/routes`, `/db/migrations`) where a feature is a horizontal slice with no natural home directory. Good default for existing codebases where imposing a feature-based structure is impractical.

**Hybrid layout.** Some features are co-located, others centralized, within the same repository. Typical for codebases mid-transition, or where a minority of features (e.g., a newly-built module) are feature-organized while the rest are horizontal. Fully supported.

In all layouts the Feature Registry crawler discovers records by file pattern, not by location. A record MAY be split across files in the same directory (e.g., `facet.yaml`, `facet.contract.yaml`) for readability, but logically constitutes one record. File placement carries no semantic meaning for FACET; it is a team convention.

**Implication:** a feature whose implementation is spread across forty files in twelve directories — a keyboard-shortcut system, a telemetry hook, a dark-mode state slice — is fully supported. The record is a single YAML file; the implementation is located by `@facet:` tags across those forty files; no attempt is made to place the record "near" the code because the code has no single near.

### 2.4 Variants

A product with a web client and a native client implements most features twice.
The feature is still one feature — one reason to exist, one contract — but its
realisation, and crucially its *state*, differ per client.

A single `lifecycle` cannot describe that. A feature live on web and unstarted on
native must claim one of the two, and every aggregate computed from that claim
inherits the error. A registry reporting "80% of features active" while the
native client is at zero is worse than no number, because it is believed.

**A variant is an independently deployable place where a feature can exist or
not exist.** Clients qualify — web, iOS, Android — and so do backends, workers
and data pipelines, whenever the question "does this feature exist there yet?"
has its own answer.

The narrower reading, that a variant is only a client, does not survive contact
with a rewrite. A system being replaced duplicates everything: `legacy/api` and
`v2/api`, `legacy/pipelines` and `v2/pipelines`. Classifying those as shared
code would be doubly wrong — they are not shared, they are competing, and it
would make "the backend is migrated, the web client is not" inexpressible, which
is the central question of every migration.

Shared code remains shared: libraries and infrastructure serving several
variants without being one. The test is not what a thing is but whether it can
independently have or lack the feature.

A variant MAY declare that it `replaces` another. This is how a rewrite is
modelled: `v2-api` replaces `legacy-api`, both exist while the migration runs,
and per-variant lifecycle shows exactly how far it has got. The declaration is
for reporting — grouping by migration, counting what is left, listing what
blocks retiring the old variant. It deliberately drives no lint: a check firing
on every not-yet-migrated feature would produce a warning per record for the
duration of the migration, and a signal that loud is not read.

A deployment declares its variants once, mapping each to path patterns.
Patterns MAY match files as well as directories, because the most common
multi-variant layout — platform extensions such as `Button.ios.tsx` and
`Button.web.tsx` in one directory — cannot be expressed otherwise. When several
patterns match a file, **the longest matching pattern wins**; without that rule
the outcome depends on the order entries were written in.

A record that spans variants replaces its `lifecycle` with a per-variant map.
The top-level value is not reconciled but **removed**: an aggregate that exists
will be read, and reading it was the original defect. An absent variant means
the feature does not apply there, which is not a gap and needs no new lifecycle
value.

**Presence requires exclusive code.** A variant counts as implemented when an
anchor sits in a path belonging to that variant and no other. Shared code is
anchored like anything else — it resolves for navigation and drift detection —
but proves no variant, because shared logic existing does not mean a user of a
given client can reach the feature. A conformant linter reports a variant that
is `active` with only shared anchors as a warning: the logic is there, nothing
client-specific reaches it, and whether the feature is actually reachable is
unknown.

Two consequences follow. An anchored file matching no declared pattern MUST be
reported, or the map rots silently and coverage under-reports with nothing
turning red. And aggregates over source MUST dedupe by file, so shared code
counts once rather than once per client it serves.

Contract scenarios MAY narrow to variants, for behaviour that genuinely differs.
Knowledge slots MAY carry per-variant overrides; the shared answer is the
default and an absent override is not a gap. A conformant linter reports
Knowledge gaps **per slot, never per slot per variant** — three variants and
four unanswered slots must not produce twelve findings on one record.

If two clients implement genuinely different features rather than one feature
differently, they are two features with two ids. The test is the Intent: if no
single intent paragraph is true of both, they were never one feature.

---

## 3. The Seven Facets

### 3.1 Intent

**Captures:** Why this feature exists, what user or business problem it solves, what alternatives were considered.

**Form:** `intent.summary` SHOULD be at most three sentences, with explicit links to decision records (ADRs, RFCs, strategy documents). The Intent facet is a summary; it does not restate the reasoning that lives in linked sources.

Needing a fourth sentence is a signal about the record rather than about the writing, and it has four common causes. The commonest by far: the sentence describes behaviour, which belongs in `contract.scenarios` — a rule stated in prose here is one `verification` cannot name, because it names scenario ids. The others: the material belongs at the anchor or in a Knowledge slot; the feature is too coarse and fails §2.1.1 gate 3; or it is prose no reader needs. Exceptions exist and SHOULD say why they are one. Nothing checks this — a linter counting sentences would reward two long ones over three short ones, which is the wrong direction.

**Authorship:** Human-owned. Agents may draft from ADRs, PR descriptions, or product briefs, but Intent is explicitly reviewed by the feature's owner.

### 3.2 Contract

**Captures:** The normative behavior of the feature — the rules that MUST hold.

**Form:** The Contract has two layers, authored together:

**Layer 1 — Scenario (human):** Gherkin-style behavioral statements. One scenario per distinct rule or edge case. Written for readability by engineers and product managers.

```yaml
scenarios:
  - id: discount-cap-applied
    statement: |
      Given a cart subtotal of any amount
      And a discount code that would otherwise produce more than 50% off
      When the code is applied
      Then the resulting discount is exactly 50% of the subtotal
      And the user sees a message indicating the cap
```

**Each step is its own line, and a second step of the same kind begins with `And`.** A `statement` MUST NOT join two conditions, two actions or two consequences into one sentence: `Then a session is created and the user is redirected` states two consequences and MUST be written as two lines. The reason is §2.1.1 gate 1's, one level down — a consequence that cannot be named on its own cannot be held on its own. A conjoined `Then` is a claim no test can falsify by halves, so a `verification` entry naming that scenario asserts more than it checked, and a reader cannot tell which half a passing test established. An `and` **inside** one step is not this and MUST NOT be split: `Given a record with a code and a name` is one condition about one object that has two fields.

**Nothing checks this obligation**, for §3.2.3's reason: telling a joined pair from a single qualified condition requires reading the sentence, and a heuristic over the word "and" would fire on `a record with a code and a name` and stay silent on a `Then` whose halves are joined by a comma or a semicolon. It belongs to review.

**Layer 2 — Pre-state (machine):** An enumerated, unambiguous specification of the scenario's inputs and preconditions. Written for agent consumption and automated verification.

```yaml
pre_state:
  cart:
    subtotal_minor_units: { type: integer, range: [1, inf] }
    currency: { type: string, constraint: ISO-4217 }
    line_items: { type: list, constraint: non-empty }
  discount_code:
    exists_in_codes_table: true
    status: ACTIVE
    expiry_at: { constraint: "> now()" }
    redemptions_remaining: { constraint: "> 0" }
    eligibility: { constraint: "applies_to(user_id)" }
    campaign:
      status: ACTIVE
      start_at: { constraint: "<= now()" }
      end_at: { constraint: "> now()" }
  computed_discount_pct: { constraint: "> 0.50" }
```

The scenario is what humans read. The pre-state is what agents and linters verify against. Both are authored in the same record; divergence between the two is caught by the linter (see §11).

**Authorship:** Owned by the feature team. Agent-drafted pre-states are common and reviewed.

#### 3.2.1 Backing

**Captures:** Whether the data a scenario describes exists yet.

A scenario can be declared, designed, and shipped as a surface while deliberately having nothing to read from. The list renders empty, the panel says "no data", the field comes back `null` — and that is the intended behaviour for now, because the store that will fill it has not been built. This is not `planned`: the code exists, the anchor exists, a user reaches it. It is not a failing test either. It is a **declared behaviour that is not backed by data**.

```yaml
contract:
  scenarios:
    - id: spend-by-category-shown
      statement: |
        Given a customer with categorised transactions
        When they open the spending breakdown
        Then spend is grouped by category
      backing:
        state: unbacked
        reason: |
          Transactions carry no category column yet, so the breakdown renders
          its empty state for every account.
        unblocked_by: ledger/transactions/categorisation
```

**An absent `backing` means `backed`.** A project that never uses the field has no declared gaps.

**`reason` and `unblocked_by` are required when `state` is `unbacked`.** Normative. An unexplained gap is indistinguishable from an oversight, and the entire reason to declare it is that it is not one. The obligation is enforced by the schema, so it holds in the language server and in every validator, not only in the linter.

**`unblocked_by` is a dependency, not a note.** It names what would supply the data: a store, a domain, a service, or an issue reference. When it is written as a canonical `domain/capability/feature` id it becomes an edge in the registry's dependency graph, and tooling MUST warn when the named feature goes `active` while the gap is still declared — the counterpart of the flag-retirement warning in §3.8. A value that is not an id MUST NOT be resolved or reported as dangling: a store name is a legitimate answer the registry cannot look up.

**Per-variant overrides are permitted** on the same terms as Knowledge slots (§2.4): `backing.by_variant.<variant>` replaces the shared state for that variant alone, an absent override is not a gap, and an unbacked override carries the same obligation to explain itself. A behaviour that is backed on web and unbacked on native is the common case, and one value would have to lie about one of them.

**Declaring a gap MUST NOT itself be a finding.** Normative, and the rule most easily got wrong. Declaring the gap is the honest act the field exists to enable; a linter that warns about it teaches authors to go back to prose.

**Why not a `lifecycle` value.** `partial` was considered and rejected for the reason §3.8 gives for refusing a `gated` lifecycle: `lifecycle` describes whether the feature *exists*, and a feature whose empty state ships does exist. A single record-level value would also be an aggregate over its scenarios — one value describing a record where one behaviour of twelve is unbacked — which is the aggregate-that-lies §2.4 removed. Whether a record is partly unbacked is **derived** by reading its scenarios, so no stored value can disagree with them.

**Why not on `verification`.** In practice the improvised markers landed there, inside a test entry's notes, and that is evidence of the constraint rather than of the right home: an unbacked scenario has *no test* to hang a marker on, so the marker attaches to an unrelated entry. `verification` is also optional, so an absence in it is invisible. `contract.scenarios` is the one place where every declared behaviour is guaranteed to be enumerable, which is what makes "list every unbacked behaviour and what would unblock it" answerable at all.

**Authorship:** The feature's owner. An agent may draft the `reason` from what it read, and MUST NOT invent an `unblocked_by`.

#### 3.2.2 Deviation

**Captures:** That the behaviour a scenario describes is not the behaviour anybody wants.

A scenario's `statement` is a promise. Code can nevertheless behave differently from its intended contract. A fictional label editor might accept blank input in one operation while another operation rejects it. Documenting that discrepancy has two inadequate alternatives:

- **State it as a contract.** The registry then cements a malfunction as specification, and every reader downstream — a reviewer, a test author, an agent implementing against the record — treats it as the rule. This is the worse of the two, because it is invisible: the record looks exactly like a record of something intended.
- **Leave it out.** The observation is lost, and the next reviewer rediscovers the same defect from scratch, having no way to know it was ever found.

The following example is fictional: CreateLabel trims input and stores it without a non-empty check, while RenameLabel rejects empty text.

```yaml
# Fictional example; these methods do not describe a deployed system.
contract:
  scenarios:
    - id: empty-label-is-accepted
      statement: |
        Given CreateLabel receives text containing only spaces
        When CreateLabel trims and stores it without a non-empty check
        Then a label with empty text is created
      deviation:
        reason: |
          The fictional CreateLabel stores trimmed text without checking
          whether it is empty. The fictional RenameLabel rejects empty text.
        confirmed_by: code-review
        tracked_as: null
```

**An absent `deviation` means nobody has declared this behaviour to be a defect.** The absence is not a warrant that the behaviour is intended: absence of a defect declaration does not establish correctness.

**`reason` is required.** Normative, and enforced by the schema so it holds in the language server and in every validator rather than only in the linter. It is §3.2.1's obligation in a second place and for the same reason: an unexplained defect claim is indistinguishable from an author who mistrusted the feature, and the entire point of writing it down is that somebody else can check it. The reason is written in terms of the code — which predicate, which value, which neighbouring method does the same thing correctly — because that is what makes it checkable.

**There is deliberately no field for the behaviour the code ought to have, and a conformant deployment MUST NOT add one.** This is the centre of the design, not an omission awaiting a later release. A suspected intent recorded beside an observed one is indistinguishable, to a human reader and to every tool that reads the record, from a contract — and a guess promoted to a promise by nothing but proximity is precisely the failure this field exists to prevent. `reason` says why the behaviour is believed to be unintended; it does not say what should replace it. Where a fix has been decided, it belongs in a separate `planned` record or in a ticket, named by `tracked_as` — a reference a reader has to follow, which cannot be mistaken for a promise the way a sibling field would be.

**The scenario's `id` MUST name the observed behaviour and never the expected one.** `empty-label-is-accepted`, never `empty-label-is-rejected`. An id claiming the behaviour the code does not have, on a scenario whose whole content is that it does not have it, contradicts itself — and the id is what a summary, a diff, a search result, a coverage table and a compressed Contract (§7.2) show without the record ever being opened, so an id that lies is the part of the lie that travels.

**This obligation is deliberately not a lint rule**, and the reason generalises. To decide whether an id names the observed behaviour or the expected one, a checker must know what the expected behaviour is — and this record does not state it, on purpose. What remains is guessing from the wording, and the wording does not cooperate: `admin-token-never-expires` and `cache-serves-stale-prices` are correct ids that read as positive claims, while `empty-label-is-rejected` asserts the expected behaviour and shares no lexical marker with the example above. A check built on such a heuristic would fire on correct ids and stay silent on wrong ones — which is the shape §11.2 already refuses elsewhere: a naive search may speak where an absence is the evidence, never where silence is. And the cost of getting it wrong is asymmetric here in a way it is not for other checks. The field only works while declaring a defect is cheap; a warning that argues with the author's wording every time makes it expensive, and the cheapest way to silence it is to stop declaring the defect. This one belongs to review.

**A scenario MUST NOT declare a `deviation` together with an unbacked `backing`**, including a per-variant override (§2.4). The two answer different questions, and in this one combination the answers contradict: `backing: unbacked` says the empty state ships and that, for now, is intended, while a `deviation` says the behaviour is not intended at all. A reader then cannot answer the only question either field exists to answer. Enforced by the schema, since both values sit in the same object and nothing outside the record is needed to see the contradiction. It is only that combination: a `deviation` beside `backing: backed` is coherent and is accepted — a defect usually has every row it needs and applies them wrongly.

**Declaring a deviation MUST NOT itself be a finding.** The same rule §3.2.1 states for a declared gap, and for the same reason: writing the defect down is the honest act the field exists to enable, and a gate that punished it would teach authors back into the two bad options above.

**`tracked_as` is resolved only when it is a canonical id.** Written as `domain/capability/feature` it names the record that describes the behaviour the product will have instead, and tooling MUST warn when that record goes `active` while the deviation is still declared — the counterpart of §3.2.1's stale-unblocker warning, aimed at how this field goes stale. A defect that was fixed and stayed documented is a lie in the other direction, and it is the only claim in the block a machine can check at all. A value that is not an id — a ticket, a thread — MUST NOT be resolved or reported as dangling. An explicit `null` states that nothing tracks it, which is a different statement from saying nothing.

**Why not §3.9 `defects`.** That block is the ledger of fixes that have *landed*: retrospective, appended by a tool walking version control, attached to the record, and about commits. A deviation is present tense, written by whoever read the code, attached to the scenario, and about behaviour. Putting a live defect there would place an unresolved claim inside a list a backfill appends to and never rewrites, and would attach it to the record rather than to the behaviour — so a defect with no scenario would be invisible, which is the situation this field exists to end. The two meet exactly once: when the defect is fixed, the deviation is removed and a `defects.fixes[]` entry takes its place. §3.9 is where a deviation goes when it stops being one.

**Why on the scenario.** §3.2.1's argument holds unchanged: `contract.scenarios` is the one place where every declared behaviour is guaranteed to be enumerable, which is what makes "list every documented defect" answerable at all. And a defect is a statement about one behaviour; a record-level field would be an aggregate over its scenarios, which §2.4 removed for variants and §3.2.1 refused for backing.

**Why not a `lifecycle` value.** For the reason §3.8 gives for refusing `gated` and §12.3 gives for refusing `partial`: `lifecycle` describes whether the feature exists, and a feature with a defect in it exists. A record-level value would additionally have to be an aggregate over scenarios, and a feature is routinely correct in eleven behaviours and wrong in the twelfth.

**Authorship:** Whoever read or observed the code, human or agent. An agent MAY draft the `reason` from what it read and MUST record `confirmed_by: code-review` when that is what happened, so a later reader can weigh an inference differently from an execution. An agent MUST NOT invent a `tracked_as`, and MUST NOT write the behaviour it believes was intended anywhere in the record.

#### 3.2.3 Scenario Outline

**Captures:** The cases a single rule holds for, where the rule is one sentence and the cases differ only in their values.

**A `statement` describing several structurally identical cases MUST be written as a Scenario Outline** — a parameterised statement with an `examples` table — and MUST NOT flatten them into set notation or a list inside one Given/When/Then. `Status ∈ {Open, Confirmed}`, "applies to A, B and C", "an admin or an owner": each is a test matrix written where nothing can read it and nobody can count it. The rule is normative because the alternative it replaces is not a style lapse but the predictable response to an incentive — without it, an author facing four cases of one rule must either flatten them or spend four scenario ids, and flattening is cheaper. What removes the incentive is the counting rule below; the obligation here only names the result.

**Nothing checks this obligation**, and for §3.2.2's reason: deciding whether a sentence describes several structurally identical cases or one case with a qualified condition requires reading it, and a heuristic over set symbols and the word "or" would fire on `a subtotal of any amount` and stay silent on `applies to trial and paid accounts`. It belongs to review. What a linter can check is an outline once written, and §11.2 carries those two categories.

```yaml
contract:
  scenarios:
    - id: an-id-is-three-lowercase-segments
      statement: |
        Given a record id <id>
        When the linter checks it
        Then it is <verdict>
      examples:
        - name: valid ids
          columns: [id, verdict]
          rows:
            - ["billing/invoice/list", "accepted"]
            - ["registry/integrity/record-validation", "accepted"]
        - name: invalid ids
          rows:
            - ["Billing/Invoice", "rejected"]
            - ["billing/invoice/list/extra", "rejected"]
```

**An Examples table is one scenario, not N.** Normative, and the sentence the rest of this section depends on. §2.1.1 gate 3, §11.4's scenarios-per-record measure, and every other count of what a record asserts count entries under `contract.scenarios`; a block of cases adds none. A count charging per case would make the sizing rule punish exactly the consolidation this section requires — four cases of one rule would read as four behaviours, and the cheapest way to pass gate 3 would be to go back to the set notation. A conformant deployment MUST NOT count rows, and MUST NOT report a scenario differently for having them.

The corollary holds at the other end: an outline is also one **proof** obligation. A `verification` entry naming the scenario's id proves the rule, and a scenario carrying twenty cases is not twenty uncovered scenarios until twenty tests exist. What the rows are worth to a reviewer is that the test can be read against them.

**Cases are grouped into named blocks, one rule per block.** `examples` is a list, not a table: each block carries its own `name` and its own `rows`. Valid cases and invalid cases are two rules and belong in two blocks. A single table holding both has quietly become one rule with a result column — the same conflation as the set notation, moved into a grid, and the reason a reader cannot say what any one row is an example *of*. `name` is optional and worth writing whenever a scenario has more than one block, because it is the only thing distinguishing two tables of the same shape.

**Columns are declared per block and inherited when omitted.** A block declaring no `columns` uses those of the first block that declares any, which is the ordinary case where every block tabulates the same parameters. At least one block MUST declare them; with none, nothing names the values and every table draws an empty heading row. Blocks MAY declare different columns from one another — each table draws its own headings, and a consumer offering a parameter's values unions the columns of every block, so a placeholder answered by one block alone is answered.

**A `<name>` in the statement names a column**, and a consumer substitutes that column's values. A placeholder naming no declared column is never substituted: it stays literal text, and the table beneath it fills nothing. A column that no placeholder names is legitimate and means nothing is wrong — a `reason` or `notes` column says why a case belongs in the table without the sentence reading it, which is ordinary Gherkin.

**Two obligations fall to the linter rather than to the schema, by necessity.** JSON Schema draft-07 has no keyword bounding one array by the length of another, and none reading a sibling string, so neither of these can be stated where `backing`'s required `reason` is stated. §11.2 carries both: a row whose length disagrees with its columns is an **Error**, because values are matched to columns by position and no reading of such a row is correct; a placeholder naming no column is a **Warning**, because what is observed is certain but what it implies is not — prose carries angle brackets that were never meant as parameters, and a build must not fail on a sentence that reads correctly.

**`And` steps need nothing here.** A statement is prose and stays a free string; `Given … And … When … And … Then … And …` is already valid and always was. A consumer that models the steps separately writes them back as prose, so nothing about an outline changes what `statement` is.

**Why named Examples blocks.** A rule usually has cases that pass and cases that fail; with one table they sit in one list distinguished only by a column, and the outline no longer says what it is an outline of. Naming the blocks is what keeps "one rule per outline" true of the data rather than only of the intention.

**Authorship:** The feature's owner, with the statement. An agent MAY draft the rows from cases it found in tests or in code, and MUST NOT add a row it has not seen a reason for: a case nobody checked, sitting in a table that reads as a specification, is a promise the product never made.

#### 3.2.4 Business Rules

**Captures:** The business rules and formulas a feature applies — a discount cap, an eligibility table, a pricing formula — as references into a DMN model.

A scenario states a case. A scenario outline (§3.2.3) states several cases of one rule. Neither states the rule itself: the complete mapping from every input to an answer, with a statement of whether that mapping has gaps. That is what a DMN (Decision Model and Notation, OMG) decision table or literal expression is, and it already has a format, modelers and evaluators. FACET does not re-invent it; a record **points at** it.

```yaml
contract:
  scenarios:
    - id: discount-cap-applied
      statement: |
        Given a code that would produce more than 50% off
        When the code is applied
        Then the discount is exactly 50% of the subtotal
  business_rules:
    - id: discount-eligibility
      kind: table
      model: rules/pricing.dmn
      element: d_discountEligibility
      states: Whether a code applies to this cart, and with which cap.
      scenarios: [discount-cap-applied]
      completeness: claimed
    - id: discounted-total
      kind: formula
      model: rules/pricing.dmn
      element: bkm_discountedTotal
      states: The total after the capped discount.
      scenarios: [discount-cap-applied]
```

**The model is the source; the record is a reference.** `model` names a `.dmn` file by its path from the repository root, `element` names a decision or business knowledge model inside it. The record MUST NOT carry a copy of the rule's logic — no table, no input types, no hit policy. Two copies of one rule drift, and drift between two descriptions of the same thing is the failure this framework exists to catch. What the record adds is what the model cannot say: a stable `id` the rest of the registry can name, one line in `states` for a reader who does not open the model, and the link to the scenarios that are cases of the rule.

**`id` is not the DMN element id.** The element id belongs to the modeler and changes when a node is renamed there; `id` is the name tests and other records use, and is stable the way a scenario id is.

**`kind` is `table` or `formula`.** A formula — a literal expression, on its own or inside a business knowledge model — is as much a business rule as a table is; a pricing formula is not a lesser kind of rule than a discount table. `kind` decides what can be checked: only a table has rows that can be missing or overlap.

**`scenarios` says that a scenario is a case of the rule, not which row it hits.** Which row a scenario's values select is a question only something that evaluates the model can answer. The core reads the record and nothing else, so it MUST NOT claim a row, and MUST NOT describe a rule as *checked* or *verified* because scenarios are listed: listing a scenario is a claim about what the scenario is, the same way `proves:` (§3.4) is a claim about what a test covers.

**`completeness` is a claim, not a proof.** Only for `kind: table`, and only `claimed` or `not-claimed`: whether the author says the table answers every input combination. The schema refuses it on a formula, which has no rows to be complete over. Whatever evaluates the model checks the claim where it can — a decision table over enumerable inputs can be checked exhaustively — and MUST say where it cannot, rather than report silence as a pass.

**What the core does with the field.** It validates the shape (schema), and a reader shows the rules on the feature and under each scenario listed as a case of one — from the record alone. It does not open the model. Opening the model, drawing it, evaluating a scenario against it and checking `completeness` belong to tooling that understands DMN; a deployment without such tooling still sees every rule, what it fixes, and which scenarios are its cases.

**Not on policies yet.** A policy's contract is a list of `clauses`, not of scenarios (§4.1, Appendix A.2), and does not support business-rule references. Business rules on policies are outside this edition.

**Authorship:** The feature's owner. An agent MAY draft `states` from the model and MAY propose `scenarios` from cases it read in tests, and MUST NOT write `completeness: claimed` on a table it has not checked — a claim written by whoever did not look is the kind of promise §3.2.3's authorship note warns about.

#### 3.2.5 Specification sources

A feature scenario MAY declare one `specified_by` reference of the form
`<source>:<spec-id>#<case>`. The spec ID is a slash-separated path of ID
segments, and the source and case are single ID segments. A spec ID segment
MAY have a three-digit prefix followed by a hyphen, as in `003-checkout`,
or a BMAD epic and story prefix, as in `1-2-checkout`.
The scenario retains its `statement` and any `examples`. With an `exact` pin,
the statement MUST contain only Gherkin steps and their arguments in the
pinned file's language.

Lint MUST validate `docs/facets/spec-lock.yaml` and resolve references offline,
using the declared sources and the lock. An undeclared or restricted source, a
missing pin, or an invalid lock is an `unresolved` error. For `exact` pins,
lint MUST compare normalised step types, text and arguments, plus Examples
headers and rows as strings in order. It MUST report `diverged` for a
difference or an unparsable statement. A difference includes a step or
Examples diff. A match produces no conformance finding. Background steps
are pinned in the context digest and are excluded from statement comparison.
For `provenance` pins, lint checks reference resolution and file status.
The statement and Examples are outside that check, and the reference cannot
produce `diverged`. Spec Kit, Kiro, BMAD and Gauge use `provenance`. Exact Gauge
binding would require a statement form for untyped Gauge steps that this
specification does not define.

For each scoped scenario with `specified_by`, `facet test` reports the spec
address, binding strength and one state in the feature's `scenarios` results:

| State | Meaning |
| --- | --- |
| `passed` | The fresh report covers the pinned case, every example row and every step, with passing steps and hooks. |
| `failed` | A reported step or hook failed or was ambiguous. |
| `unproven` | The case was reported with undefined, pending, skipped, duplicate or incomplete evidence. |
| `not-run` | The case or an expected example row is absent from the fresh report. |
| `unmeasured` | The pin, configured runner or usable fresh report is unavailable. |
| `diverged` | The record's scenario differs from the pin, and the run supplies no evidence for it. |
| `provenance` | The reference resolves to a prose unit. It contributes neither execution evidence nor an execution failure. |

Only `passed` supplies executed scenario evidence. The case tag provides the
binding without a separate `proves` entry. The run establishes that the record
matches the pin and that the pinned case completed against the runner's step
definitions. An empty step definition can pass. Review must establish whether
the definitions check what their steps promise.


A feature MAY declare `lineage.specified_by` as a list of
`<source>:<spec-id>` file references. These references establish provenance.
Lint MUST resolve them under the same source restrictions and report a missing
file as `unresolved`. Scenario and lineage references to deprecated files
produce warnings. Draft and approved files can both be referenced.

Specification drift compares pins with the configured branches (§5.4.9).
Agents that see a changed or removed specification MUST report it and
recommend implementing it in an existing or new work item. Changes to the lock,
records or code require authorisation through that work item. The specification
repository is the source of the scenario. Report deviations or resolve them
there.

### 3.3 Anchor

**Captures:** Where in the codebase the feature is implemented.

**Form:** The Anchor facet is **fully derived** from `@facet:` tags in source code. It does not appear as an authored section in `facet.yaml`. The canonical record of anchors is the set of tags in the code; the Registry computes and serves an anchor listing on demand.

**In-code tag format:**

```rust
/// @facet: checkout/pricing/discount-code-redemption
/// @facet-role: primary
pub fn apply_discount_code(cart: &mut Cart, code: &str) -> Result<Discount, Error> {
    // ...
}
```

The tag format is language-neutral; the same `@facet:` comment marker is used in Rust, TypeScript, Python, Java, Go, SQL migrations, YAML configuration files, and anywhere else comments are supported. Tags attach to the following symbol (function, class, type, constant, configuration key), or, if placed at file top with no following symbol, to the file as a whole.

**Roles.** An optional `@facet-role:` tag classifies the anchor: `primary` (the feature's main implementation), `related` (supporting code), `config` (configuration values that parameterize the feature), or `data` (schema or migration). If omitted, `related` is assumed.

A conformant linter SHOULD warn when an active feature carries anchors but none
of them is `primary` — never an error, because `related` is the default and a
project that has never written a role would otherwise fail on adoption. The
warning exists because anchors record presence, not use: when the code that
*called* a feature is deleted, the supporting files keep their anchors and the
record still looks implemented. Which anchor is `primary` is the only thing in
the record that says where the feature actually starts, and therefore the only
thing a reader can check the deletion against.

**Scenario references.** An anchor MAY also carry `@facet-proves:` with the scenario ids its code implements. These references are optional; an anchor without them produces no finding. A declared scenario id MUST resolve within the anchored record.

**Multiple tags per location.** A single symbol MAY carry multiple `@facet:` tags when it legitimately serves multiple features:

```ts
/// @facet: checkout/pricing/discount-code-redemption
/// @facet: checkout/pricing/tax-calculation
/// @facet: checkout/pricing/shipping-fee
export function computeOrderTotals(cart: Cart): OrderTotals {
  /* ... */
}
```

This is valid and common, especially in utility functions, shared stores, and orchestration code. See §3.3.1 for the diagnostic implications.

**High anchor counts are expected.** Horizontal features — a dark-mode toggle, keyboard shortcut system, telemetry hook, internationalization layer — legitimately touch dozens of files. A feature with forty `@facet:` tags is not an anti-pattern; it is an accurate description of where the feature lives. Because anchors are derived, there is no hand-maintenance cost that scales with count.

**Registry behavior.** On crawl, the Registry scans all source files for `@facet:` tags and builds the anchor graph. For any feature, the Registry can produce a list of anchor points grouped by role, file, or symbol. For any file or line range, the Registry can produce the list of features that anchor there (`anchor_resolve` in the agent API, §6.2).

**Authorship:** Developers add `@facet:` tags when writing or modifying code. Reviewers verify the tags are correct during code review. No YAML anchor section exists to maintain.

#### 3.3.1 Architectural diagnostics from anchors

FACET does not require one-feature-per-function. A function carrying multiple `@facet:` tags is a legitimate, supported case. However, the distribution of tags across the codebase produces useful architectural signals for registry analysis:

- **Anchor Density** — anchor symbols per distinct file — indicates feature cohesion. Low density means a feature is scattered.
- **Multi-tag concentration** — symbols carrying three or more tags — indicates coupling hotspots where multiple features share implementation.
- **Change coupling** — a single commit touching anchors of many features — indicates a volatile shared substrate.

These are diagnostics, not enforcement. FACET reports them; the team decides whether to refactor. The philosophy is that FACET makes existing architectural entanglement _visible_ without requiring a cleanup campaign as a precondition for adoption. Teams can adopt the framework first and address coupling where the scores show it matters.

### 3.4 Verification

**Captures:** The tests and property checks that prove the contract holds.

**Form:** References to test identifiers, not copies of them. Each contract scenario SHOULD have one or more linked verifications.

```yaml
verification:
  unit_tests:
    - id: pricing::discount::test_cap_at_50_percent
      proves: [discount-cap-applied]
    - id: pricing::discount::test_expired_code_rejected
      proves: [expired-code-rejected]
  property_tests:
    - id: pricing::discount::prop_cap_never_exceeded
      proves: [discount-cap-applied]
  integration_tests:
    - id: api::promo::it_cap_message_shown
      proves: [discount-cap-applied]
```

A contract scenario with no linked verification is a linter warning. A verification that references a nonexistent test is a linter error.

**Lineage references are checked.** An id in `lineage.depends_on` or
`lineage.depended_on_by` that no record in the project has is a linter error, in
the same sense that an anchor naming no record is one. The reference is judged
against the whole project rather than one registry: it carries no registry
prefix, and in a monorepo the products depend on each other on purpose.

**Authorship:** Mixed. Often agent-assisted — agents are good at matching test names to contract scenarios.

### 3.5 Observation

**Captures:** How the feature's health is known in production.

**Form:** SLO definitions, telemetry queries, alert rules, and references to operational runbooks.

```yaml
observation:
  slos:
    - name: discount-apply-success-rate
      target: 99.9
      window: 28d
      query: "success / total"
      query_source: metrics/discount_apply.promql
  alerts:
    - name: discount-apply-error-spike
      condition: "error_rate > 0.05 for 5m"
      severity: page
      runbook: runbooks/discount-apply-errors.md
  dashboards:
    - url: https://dashboards/checkout/discount-apply
  continuous_checks:
    - id: synthetic::discount::apply_valid_code_5m
      frequency: 5m
```

**Authorship:** Owned by the feature's team, often with SRE input.

#### 3.5.1 Emission

**Captures:** The telemetry the implementation actually emits.

`observation` is operator-facing: it says how the feature's health is *judged* — the SLO, the alert condition, the runbook, the dashboard. It says nothing about which metric names, span names, and log events exist to judge it with. `observability` is the developer-facing peer that does:

```yaml
observability:
  metrics_emitted:
    - name: discount_apply_total
      kind: counter
      labels: [outcome, campaign_id]
      description: discount code redemption attempts
  traces_emitted:
    - span_name: checkout.discount.apply
      parent_span: checkout.session.create
      attributes: [campaign_id]
  log_events:
    - event: checkout.discount.capped
      level: info
      attributes: [trace_id, cart_id]
```

**Why the two are separate rather than one facet.** They have different authors and different failure modes. The failure that motivates writing emissions down is **rename**: an alert whose condition still names `discount_apply_total` after the code started emitting `checkout_discount_apply_total` is a broken alert that fires never, and looks identical to a healthy one. Until the emitted names are in the record there is nothing for a reviewer or a linter to compare the condition against — the alert and the metric drift the way a record and its code drift, which is the class of defect this framework exists to catch. The label list serves the same purpose for cardinality: a reviewer can see what a new label multiplies.

**Every list is optional, and an absent block claims nothing.** It does not assert that the feature is silent. A feature that emits nothing and wants to say so writes an empty list.

**No tooling check is required for emission declarations.** No check is specified for this block. Verifying that a declared metric name appears in source is the natural next step and is the same shape as the flag-key check in §3.8, but it needs a name-matching rule per language and instrumentation library, and shipping a check that half-works on three ecosystems is worse than shipping the field and letting the shape settle first. The field is specified now so that projects stop inventing their own; the check follows when there is evidence about what it should tolerate.

**Authorship:** The implementing developer, usually in the same change that adds the instrumentation.

### 3.6 Knowledge

> Intent, Contract, Anchor, Verification, and Observation collectively cover system behavior, but none captures what a _user_ needs to know to use the feature successfully. Without that, the public knowledge base is rebuilt from scratch by a separate team months after release, drifts on every change, and routinely contradicts the source of truth. Knowledge brings the user-facing layer into the same record.


**Captures:** The questions a user-facing knowledge base must answer for this feature, plus the non-derivable facts that only the feature owner can supply. Designed so that a knowledge-generator pipeline (see §8.5) can render help-center articles, FAQs, and onboarding material without hand-authoring derived prose.

**Form:** Five optional slots, each authored as a question (the invariant) plus optionally a short answer (only required for facts that cannot be derived from source). A `derive_from` hint lists which other record sections or repository sources the generator should load when rendering this slot.

```yaml
knowledge:
  prerequisite_knowledge:
    question: "What must the user already understand to use this feature?"
    answer: |
      The user must understand what a discount code is and where they can
      find one (typically in marketing emails or partner sites).
  not_for:
    question: "When is this the wrong tool for the job?"
    answer: |
      Not for stacking multiple promotional offers on a single cart;
      not for B2B contract pricing (use the quote engine instead);
      not for loyalty point redemption.
  discoverability:
    question: "Where does the user enter this flow in the product?"
    derive_from: [anchors]
    # answer is left blank; the generator inspects @facet:-tagged UI
    # entry points and renders the path on demand.
  common_pitfalls:
    question: "What mistakes do users typically make with this feature?"
    answer: |
      Pasting a code with surrounding whitespace; entering a code that
      has expired but was bookmarked from an old email; assuming the
      discount applies before tax (it applies after).
  success_signal:
    question: "How does the user know it worked?"
    answer: |
      The cart total updates immediately, a green confirmation banner
      shows the discount line item, and the discount appears in the
      order summary email.
```

**Slot semantics.**

| Slot                      | What it answers                                                              | Derivable from source? | Owner-supplied? |
| ------------------------- | ---------------------------------------------------------------------------- | ---------------------- | --------------- |
| `prerequisite_knowledge`  | What concepts/permissions/state the user must have before invoking           | No                     | Yes             |
| `not_for`                 | When the feature is the wrong tool — anti-use-cases                          | No                     | Yes             |
| `discoverability`         | Where the user enters the flow — UI path, CLI command, API endpoint          | Yes (from anchors)     | Optional        |
| `common_pitfalls`         | Frequent user mistakes and how to recognise them                             | Partially              | Yes             |
| `success_signal`          | How the user knows the feature worked for them — the felt confirmation      | No                     | Yes             |

**Question-first authoring.** Slots are authored as questions because UI/implementation churn rapidly invalidates prose answers ("click the blue button at the top right" stops being true after the next redesign), but the underlying question ("Where does the user enter this flow?") is invariant. The generator pipeline produces the time-bound answer on demand from current source.

**Empty slots are valid.** A slot may be entirely absent or carry only a question without an answer. The linter treats empty Knowledge as a warning, never an error (see §11.2). Knowledge may be omitted entirely.

**Authorship:** Mixed. The questions are typically static across the team (the same five slots in every record). The answers are owner-supplied for non-derivable slots and frequently agent-drafted for derivable ones — subject to owner review when the answer is rendered in published material.

#### 3.6.1 Not applicable

**Captures:** That a slot has no answer because there is nothing to answer — not because nobody has got to it yet.

An empty slot carries two meanings, and nothing distinguishes them. *Unanswered* is work an owner owes. *Inapplicable* is not: `common_pitfalls` on a check that runs in CI and either passes or fails, `prerequisite_knowledge` on an anchor scanner no person invokes. The second will never be answered, because there is nothing to answer, and an empty slot would warn on every run for the life of the record.

That is the failure §11.3 describes from the other end. A warning that can never be cleared does not fail a build; it stops being read, and takes the findings beside it with it.

```yaml
knowledge:
  common_pitfalls:
    question: "What mistakes do users typically make with this feature?"
    not_applicable:
      reason: |
        Nobody interacts with this. It runs in CI and either passes or fails.
      confirmed_by: platform-team
```

**`reason` and `confirmed_by` are both required.** Normative, and enforced by the schema so it holds in the language server and in every validator rather than only in the linter. This is §3.2.1's obligation in a third place: an unexplained exception is indistinguishable from an oversight, and the entire point of declaring it is that it is not one.

`confirmed_by` is required here although §3.2.2 makes its namesake optional, and the asymmetry is the point. An unattributed `deviation` still leaves a defect declared, which is more than silence. An unattributed exception leaves nothing: it cannot be told from an agent clearing a warning, which is the ambiguity this field exists to remove. It is reviewable rather than resolved — the registry does not look the name up, exactly as a `tracked_as` naming a ticket is not resolved — and what it buys is that the decision has an author a later reader can ask.

**It is owner-supplied, exactly like the answer it replaces.** Deciding that users cannot make a mistake with a feature is the same kind of judgement as listing the mistakes they do make. An agent that MUST NOT invent an answer MUST NOT invent an exception either, and the cheaper of the two is the one an agent will reach for.

**A slot MUST NOT declare both an `answer` and `not_applicable`**, nor `not_applicable` beside a non-empty `derive_from`. The first is a contradiction a reader cannot resolve; the second instructs a generator to render a slot that has just said it has nothing to render. Both are visible without reading anything outside the slot, so the schema refuses them — the same ground on which §3.2.2 refuses a `deviation` beside an unbacked `backing`.

**Declaring it MUST NOT itself be a finding**, and it silences that slot alone. Never a record-level opt-out: a record declaring one question inapplicable still owes the others, and the warning names exactly those. The rule §3.2.1 and §3.2.2 both state for a declared gap, for the reason both give — a linter that warned about the honest statement would teach authors back to the silence it replaces.

**Whether the reason is true is a review obligation**, not a lint rule. Deciding it requires knowing who the feature's users are, which no field in the record states — the division §3.2.2 draws for a deviation's wording, and drawn here for the same reason.

**Authorship:** The feature's owner. `confirmed_by` records who that was, and MUST NOT name the agent that wrote the record.

`confirmed_by` is a free string, unlike `deviation.confirmed_by`, which is a closed enum. The two are not the same field under one name: there it records a *kind of evidence*, of which there are three, and a fourth invented per registry would make a filter over the field mean something different in each one. Here it records *who decided* — a person or a team, which no enum can enumerate. The consequence is worth stating plainly rather than overstating: this makes the declaration **attributable**, not verified. A deployment wanting more can require the value to match `lineage.owner.team` or a code-owners entry; the specification does not, having no evidence yet about how the field is used in practice.

If, six months after adoption, fewer than 50% of `active` records carry at least three non-empty Knowledge slots, the deployment SHOULD treat this as evidence that the Knowledge facet is not being maintained in production, re-evaluate its design, and consider keeping Knowledge as tooling guidance rather than a record-schema facet.

### 3.7 Lineage

**Captures:** Ownership, history, and relationship to other features and entities.

**Form:**

```yaml
lineage:
  owner:
    team: checkout-pricing
    individual: maintainer
  created_at: 2024-09-02
  superseded_by: null
  depends_on:
    - checkout/cart/line-item-subtotal
    - catalog/promotion/promo-campaign-lookup
  depended_on_by:
    - checkout/summary/cart-summary-display
  related_policies:
    - policy/finance/revenue-recognition-v2
    - policy/legal/promo-disclosure
  related_assumptions:
    - assumption/pricing/discount-codes-do-not-stack
  related_data_entities:
    - data/promo/discount-code
    - data/checkout/cart
  change_history_ref: git://repo/path/facet.yaml
```

Direct history is stored in version control; the Lineage facet records pointers and semantic relationships.

**Authorship:** Mostly agent-maintained from graph traversal; human-reviewed on structural changes.

#### 3.7.1 Tickets

**Captures:** Issues in a tracker — Jira, GitHub, Linear — that are relevant to a feature.

A record states what was built: the intended behaviour, and nothing else. The ticket usually holds what the record deliberately does not — why it was built, why now, who asked for it and who built it, what was weighed and dropped. A reader who needs that, an agent above all, follows the ticket. That is the purpose of the field, and it sets its limit: a ticket adds context, it never adds or changes a promise.

A record MAY name tickets, and only where they are relevant: for the whole feature on `lineage.tickets`, and for one promise on that scenario's `tickets`. Both are optional and independent. A record may carry either, both or neither, and any number of tickets on each; the same ticket may appear on several records. The framework does not say where a given ticket belongs. That a ticket is named on the feature or on a scenario is the author's statement of what it is relevant to, nothing more.

```yaml
contract:
  scenarios:
    - id: invoice-is-sent-when-payment-settles
      statement: |
        Given an Order whose Payment has settled
        When the settlement event is processed
        Then exactly one Invoice is sent to the billing address
      tickets:
        - key: KAN-2
          relation: implements
lineage:
  owner:
    team: billing
  created_at: "2026-10-08"
  tickets:
    - KAN-1
    - key: owner/repo#123
      relation: specifies
      tracker: github
```

**A ticket is written as its key or as an object.** The key is the issue key as the tracker writes it (`KAN-12`, `owner/repo#123`). The object form adds `relation`, `tracker` and `title`; the bare key is the object form with relation `relates`.

**`relation` is a closed list:** `implements`, `specifies`, `verifies`, `tracks-defect`, `relates`. Closed, so a reader can group and filter by it. A relation that fits none of them is `relates`, not a new word.

**`tracker`** names the tracker the key belongs to, by its id in the project's `trackers` list (§5.4.5). It is needed only where a key could belong to more than one tracker; absent, the key is resolved by pattern.

**`title`** is a reader's aid and is not kept in sync with the tracker.

**A ticket is a claim about a relation, not a promise.** The scenarios say what the feature does; a ticket says where work on it was asked for, decided or tracked. Nothing in a ticket is contract. The core validates the shape and never resolves a key: it MUST NOT report a ticket as existing, open, closed or consistent with the record. A reader that can reach the tracker MAY show the issue beside the record; that is a reading, not a verification.

**Not a replacement for the role-specific references.** `deviation.tracked_as` (§3.2.2), `backing.unblocked_by` (§3.2.1) and `defects.fixes[].issue` (§3.9) each name a ticket in one specific role and keep that meaning. A reader that lists the tickets of a record MAY include those references, and SHOULD say which field each one came from, because a declared relation and a reference found in another role are different statements.

### 3.8 Feature Flags

> **Not an eighth facet.** The seven facets describe what a feature
> is; a flag describes who can currently see it.

A feature behind a flag is code that exists and behaviour users may not have.
`lifecycle: active` — implemented and deployed — remains true of the code and
becomes misleading about the product, and nothing in the record says so.

**Lifecycle describes existence; flags describe exposure.** The two axes are
orthogonal and MUST NOT be merged. A `gated` lifecycle value would collapse
them, and a feature can be fully implemented, fully deployed, and visible to
nobody. A record MAY declare the flags gating it, each with a key, optionally
the flag system, a default, the variants it gates, a description of the current
rollout, and a retirement date.

A flag is temporary by construction and permanent in practice. The declaration
exists so the linter can say two things:

- **The key still appears in source.** A declared key found nowhere means the
  gate was removed and the record was not told — the feature is now
  unconditionally on or off, and the record no longer says which. This is an
  error.
- **The retirement date has not passed.** A warning, never a failure, on the
  same reasoning as §8.6: a gate people route around protects nothing. A flag
  past its date is technical debt with a name and a date, which is a
  considerable improvement on the usual situation.

The key check MUST exclude the records themselves. A record declaring a flag
contains that key by definition, so scanning the registry would let every record
satisfy its own check and the lint would never fire.

### 3.9 Defects

> **Not a ninth facet**, on the same grounds §3.8 is not an eighth:
> the seven facets describe what a feature is; a defect entry describes what
> went wrong with it, after the fact.

A record MAY declare `defects`, the ledger of bugfix commits that have landed
in the feature's anchored code — one entry per commit, naming the commit hash,
the date, and which anchored files it touched. It answers the question a
reader asks before deciding where a rewrite, an extra test, or a second
reviewer is worth paying for: which features break, and how often.

**Retrospective and tool-written, unlike `observation`.** The two face
opposite directions in time and are produced by different hands.
`observation` (§3.5) is prospective and human-curated — an SLO target, an
alert condition, a runbook, the instrument a team configures before anything
goes wrong. `defects` is retrospective — the readings, appended by a tool
walking version control, including fixes for bugs that never reached
production and so were never observed at all. The two MUST NOT be merged: a
machine-appended, monotonically growing list inside a block a team hand-edits
would conflict on every run that appended to it, and — by the same reasoning
§10.5 gives `metadata` — is the point at which a record starts becoming a log
file instead of describing one.

A `defects` block has two lists:

- **`fixes`** — one entry per attributed commit: `commit` (full hash),
  `date`, and `files` (the anchored paths that commit touched), all required;
  `subject`, `issue`, and `recorded_by` (`git-history`, `tracker`, or
  `manual`) are optional context. Shaped as a claim with its evidence, the
  same reasoning `verification` already gives a test reference: a number
  nobody can trace is a number nobody can correct, and an attribution a
  heuristic derived will sometimes be wrong.
- **`excluded`** — a commit a reviewer has judged not to be a defect in this
  feature, with `commit` and a required `reason`. Carries the same obligation
  §3.2.1 gives a declared gap: an unexplained exclusion is indistinguishable
  from a count someone quietly trimmed, and without a place to record "the
  attribution was wrong, and here is why," deleting a wrong entry only makes
  the next backfill add it back.

**No total is stored.** The fix count is `fixes` length; the per-file count
is how often a path recurs across it. Both are derived on read, on the same
grounds §2.4 removes an aggregate lifecycle for `variants` and §3.2.1 refuses
one for `backing`: a stored aggregate is free to disagree with the list
beneath it, and a defect count that disagrees with its own evidence is worse
than none, because it is the number a reader would act on.

Tooling that backfills `defects` from git history MUST attribute a commit
to a feature only through files the commit touched that carry that feature's
anchor, and MUST record `recorded_by: git-history` so a reader auditing a
hotspot can weigh a heuristic attribution differently from one a human wrote
down.

---

## 4. Adjacent Entities

### 4.1 Policies

Cross-cutting rules that apply to many features (regulatory, security, business). Policies have their own records, their own IDs (`policy/<domain>/<name>`), and are referenced from features. Examples: `policy/privacy/gdpr-erasure`, `policy/finance/revenue-recognition-v2`.

Policy records have Intent, Contract (the policy rule as enforceable clauses), Scope (which features it governs), Verification (how we check compliance), and Lineage (ownership, regulatory basis).

### 4.2 Assumptions

Named, auditable beliefs about the world that the system's behavior depends on. Each assumption has evidence, an expiration / review date, and a criticality rating. IDs: `assumption/<domain>/<name>`.

Example:

```yaml
id: assumption/pricing/discount-codes-do-not-stack
statement: |
  A single cart can have at most one active discount code at a time.
  Users do not expect to combine multiple codes.
evidence:
  - type: user-research
    reference: research/2024-q1-pricing-study
    date: 2024-03-12
  - type: competitive-analysis
    reference: research/2024-q1-competitor-pricing
    date: 2024-03-10
review_by: 2026-03-01
criticality: high
risk_if_false: |
  If users expect stacking, UX and revenue impact;
  several downstream policies (promo-disclosure) assume single-code.
```

### 4.3 Data Entities

Canonical data models referenced by features. IDs: `data/<domain>/<entity>`. Data Entity records specify schema, ownership, retention, and the features that read or mutate them.

### 4.4 Taxonomy

Every id is `domain/capability/feature` — three levels, which is the decomposition a product actually has. The taxonomy declares the domain and capability segments against which ids are validated.

A deployment MAY declare its decomposition in a **taxonomy**, held at `<records>/taxonomy.yaml` alongside the variant map:

```yaml
schema_version: "0.1"
domains:
  library:
    title: Library
    purpose: Everything a listener has deliberately kept.
    classification: core
    owner:
      team: library
    capabilities:
      playlist:
        title: Playlists
        purpose: Ordered collections a listener creates and edits.
      shared-playlist:
        title: Shared playlists
        classification: supporting
```

Rules:

1. **A record's id MUST resolve against a declared taxonomy.** An id naming an undeclared domain or capability is a linter **Error** — the same treatment a variant name absent from the variant map receives, for the same reason: an id is immutable, so a wrong one is caught while it is still cheap or never.
2. **An absent taxonomy claims nothing.** No taxonomy check fires without the file.
3. **A declared node with no record under it is a Warning.** Declaring a capability before writing its first record is the intended order, so this cannot be an error; leaving half a declared product undocumented is nonetheless the thing a reader must be able to see.
4. **The taxonomy is not a record.** It has no contract, no anchor, no lifecycle, and makes no claim about behaviour. It is a naming authority.
5. **There is no fourth level.** A deployment wanting one is describing scenarios, and §2.1.1 says so.
6. **A capability MUST NOT list the features under it.** Records are the third level and live in their own files; a list here would be a second statement of a set the records already make, free to disagree with them — the defect §2.4 removed for the variants aggregate and §3.9 refused for a stored defect count.

#### 4.4.1 Why declaring it changes the outcome

Guidance about granularity is read once and applied unevenly. A declared taxonomy gives each failure mode a cost at the moment it happens.

To write a record under a capability that does not exist, an author must declare the capability and say in one line what it is for. Hundreds of such nodes are what a registry documented at scenario granularity would require, and the absurdity is visible while writing rather than at the end of an adoption sprint. To stop early, an author must leave declared capabilities standing empty — a hole in a file people read, rather than an absence nobody can see.

#### 4.4.2 Classification

A domain or a capability MAY carry `classification: core | supporting | generic` — Evans' core, supporting and generic subdomains, in his words so that the literature explaining what to do differently with each comes with them.

This is **strategic weight and nothing else**, and it is orthogonal to depth. Authentication sits at the top of most taxonomies and is strategically generic: nobody chooses a music service for its login. A ranking model three segments deep may be the entire business. A field indexed on position would get both backwards, which is why position cannot supply this and it must be stated.

Depth itself is never stored. It is the id. A record carrying its own level beside an id that already states it is the defect §2.4 removed for the variants aggregate, §3.2.1 refused for a backing aggregate and §3.9 refused for a defect counter: a stored value is free to disagree with the evidence beneath it, and the disagreeing number is the one a reader acts on.

Classification sits on the node rather than on the record for a second reason. A product has a dozen domains, and a product lead can defend a dozen judgments. Three thousand records mean three thousand independent judgments made by whoever touched the file last, and such a field is noise within a quarter.

An absent classification means undecided, not "supporting". A capability inherits its domain's value when it declares none, so the common case — a whole domain that is generic — is stated once.

### 4.5 Glossary

Records are written in a product's own vocabulary, and a term of art appears in many of them while being defined in none. `Consignee` — the party named in the transport document who receives the goods, not necessarily the buyer and not the carrier — is either silently presumed by every record that needs it, or explained again in each, with two explanations free to drift apart.

A deployment MAY declare its terminology in a **glossary**, held at `<records>/glossary.yaml` alongside the taxonomy and the variant map:

```yaml
schema_version: "0.1"
categories:
  - id: parties
    title: Parties
    purpose: The people and organisations a shipment passes between.
  - id: documents
    title: Documents
terms:
  - term: Consignee
    category: parties
    definition: |
      The party named in the transport document who receives the goods at
      their destination — not necessarily the buyer, and not the same party
      as the carrier or the shipper.
  - term: Demurrage
    definition: |
      What the carrier charges when a container is held past its free time.
```

Rules:

1. **A term is unique within the glossary, case-sensitively.** `Consignee` and `consignee` are two different terms, and a project declaring both has declared two. The same string declared twice is a linter **Error**: the file exists so a word has one meaning a reader can look up, and two entries under one term leave that reader — and every consumer downstream — with no way to choose.
2. **No record references the glossary.** There is no reference field and no markup. A consumer indexes the declared terms and treats every exact, case-sensitive, **whole-word** occurrence in rendered prose as a reference to the definition. This is association by content rather than by a reference id, the same rule §3.3 already applies to anchors, and it is what keeps a record from changing merely because the glossary grew. A term is matched whole or not at all: `Order` inside `Reordering` is not the term.
3. **A near miss is a Warning.** A word that is not a defined term but is very nearly one — the same letters in a different case, or a small edit distance away — is reported against the record it was found in, naming the term it was probably meant to be. This is the check that stands in for the reference field that does not exist: a term written in the wrong case or with a letter missing links nowhere, reads correctly to its author, and nothing else in the registry has any reason to look at it. It is a Warning and never an Error, because prose is allowed to contain a word that merely resembles a term.
4. **The near-miss check reads the normative prose.** `intent.summary` and `contract.scenarios[].statement`. Knowledge answers are deliberately outside it, and the asymmetry with rule 2 is the point: linking is silent and costs a reader nothing when it is unwanted, while a Warning is a claim that something is wrong — and owner-written answers quote the product's own wording, which an author frequently must not "correct". Consumers still link exact occurrences everywhere they render prose, Knowledge included.
5. **An absent glossary claims nothing.** No glossary check fires without the file.
6. **The glossary is not a record.** It has no contract, no anchor and no lifecycle, and makes no claim about behaviour. It is a naming authority, as the taxonomy is.
7. **A definition says what the word denotes, not what the product does with it.** The second is a claim about behaviour; it belongs in the contract of the record that asserts it, and a copy here would be a second statement free to disagree with the first.
8. **A glossary MAY declare categories, and a term MAY name one.** `categories` is a list of `{ id, title, purpose? }` in the order the project wants them shown; `terms[].category` names one of those ids. A glossary of two dozen terms is a list; one of several hundred is a wall, and the groups its authors already think in had nowhere to be written down.
9. **A term naming an undeclared category is an Error.** The set of correct answers is in the same file, so such a reference is a typo or a category somebody deleted — never a judgement. This is what declaring the categories buys over writing the group name on each term: a mistyped key would otherwise be the one unguarded string in a file where a mistyped term in prose is already a Warning and a term defined twice an Error, and it would split a category in two with nothing to say so.
10. **A declared category no term names is a Warning.** Declaring a category before writing its first term is the intended order, so this cannot be an Error; a heading left standing by a half-finished rename is nonetheless the thing a reader has to be able to see. The same treatment §4.4 rule 3 gives an empty taxonomy node, for the same reason.
11. **Categories are flat, and a term names exactly one.** A category has no parent and no children; there is no second level, and nothing nests. A glossary that seems to want one has usually declared too many categories rather than too few levels, and the depth would then have to be drawn, navigated and kept consistent for the gain of a single heading — the judgement §4.4 rule 5 makes in refusing a fourth id segment. A term belonging to two groups is likewise refused: shown under two headings, it makes "how many terms are there" a question with two answers.
12. **A term naming no category is uncategorised, and that is not a finding.** An absent category means nobody decided, exactly as §4.4.2 says of an absent `classification` — not that the term belongs somewhere general. No check fires on it, nothing defaults, and **a consumer MUST NOT file such terms under an invented heading** such as "Other" or "Misc": that is a category the project never declared, and the count under it measures how far the categorisation got rather than naming a group of related words. A consumer showing them at all names the absence itself and keeps them apart from the declared groups. Where a glossary declares no categories and no term names one, a consumer renders an ungrouped list.

#### 4.5.1 Why no opt-out, and what to do instead

The obvious missing control is a way to say "do not link this term here". It is deliberately absent, and the reason is that the escape hatch already exists at the only place the decision belongs: the list is opt-in per term.

A term that is also an ordinary word will be linked in every sentence that happens to use it, and the links stop meaning anything. The remedy is not a setting — it is to leave that word undefined, or to declare the capitalised form that marks it as a term of art in the first place, which is what a project writing `Consignee` has already done. A per-occurrence opt-out would put that judgement in every record instead of in the one file, which is the state this section is correcting.

The same argument rules out a `glossary_refs` field on the record. Such a field would have to be maintained by hand in every record that uses a term, would be wrong the moment a summary was edited, and would make a record change every time the glossary grew. The two checks above do what it would have done — catch the spellings that link nowhere — without an author ever referencing a term.

#### 4.5.2 Relation to the translation glossary

§8.5's pipeline and `generation-manifest.schema.json` already name `docs/facets/glossary.yaml` and a `"glossary"` input role, for a different purpose: keeping terminology consistent across locales in generated user documentation, where machine translation fails on terminology rather than grammar.

That is the same file, not a collision. A translation pass needs to know which words are terms of art, and this is the list that declares them; a `renderings` map per term reserves the per-locale wording for the pipeline that would consume it. Nothing reads `renderings` today and nothing here promises to. Two separate files would mean declaring `Consignee` twice and handing a translation pass a second list free to disagree with the first — the defect §2.4 removed for the variants aggregate, §3.2.1 refused for backing, §3.9 refused for a defect count and §4.4 refused for a capability's features.

#### 4.5.3 Why the categories are declared rather than written on the term

The cheaper shape is a free-text `category` on each entry, and it is wrong here for a reason specific to this file rather than a general preference for schemas. Every other string in a glossary is already guarded: a term defined twice is an Error, and a term *mistyped in prose somewhere else in the repository* is a Warning that names the spelling it was probably meant to be. A free-text grouping key would be the one string in that file where `Parties`, `parties` and `Partys` produce three headings and nothing anywhere says so — a defect whose only symptom is a surface that looks slightly wrong to somebody who does not know what it should look like.

Declaring the names and referencing them is the pattern §4.4 already uses for the domain and capability segments, and it yields the same three findings for the same reasons. It also makes the interesting failure loud: deleting a category that terms still name becomes an Error naming each of them, where under a free-text key it is invisible.

Two smaller choices follow from what the file already says about itself.

**`categories` is a list, not a map**, unlike the taxonomy's `domains`. §4.5's `terms` is a sequence because the order of a glossary is the project's own and nothing sorts it; a mapping of categories would surrender that order to whatever order a parser hands back, leaving a consumer to sort alphabetically — an opinion about which group comes first — or to carry an explicit integer, which is a second statement of an order the sequence already makes and is free to disagree with it through a tie or a gap.

**A category has an `id` and a `title`**, rather than the heading serving as both. The two change on different schedules: rewording a heading is an editorial decision that should touch one line, and it would otherwise touch every term that names it. The `id` grammar is the segment grammar ids already use, so a project reading this file reads both the same way.

---

## 5. The Feature Registry

### 5.1 Role

The Registry is a _thin index_ over the distributed set of FACET records. It does not own content; records live in-repo. The Registry's responsibilities:

- Crawl repositories on a schedule, on webhook, and on demand
- Parse records, validate schemas, extract in-code `@facet:` tags
- Build indices: by ID, by anchor path, by owner, by tag, by policy, by data entity
- Serve the tool API (§6) and projection layer (§7)
- Run the cross-facet linter (§11) and publish drift reports
- Expose a read-only REST + MCP interface

### 5.2 Deployment

A single logical Registry per product organization is the reference deployment. Federation across organizations is possible but out of scope for this specification.

### 5.3 Storage

Registry storage is a cache of derived data. The source of truth is always the repository. The Registry can be destroyed and rebuilt from source at any time. This is a deliberate design property.

### 5.4 Project configuration

A repository MAY declare its FACET layout in a committed file at its root, `.facetrc.yaml`. Every field is optional and a project that omits the file entirely uses the defaults shown below.

```yaml
schema_version: "0.1"
records: docs/facets          # default
schema: docs/facets/schema    # derived from `records` when absent
sources: [src, packages]      # default: the whole repository
```

A layout supplied only by environment variables depends on the shell running the tooling. A CI job and a developer's session could disagree about where the records live and both report success — the failure mode FACET is built to prevent, reproduced in its own configuration. A committed file is reviewed, versioned, and read identically by every consumer.

Tooling MAY continue to honour environment overrides, and the reference tooling does: a CI job or a migration script pointing the linter at a scratch tree is a real need that a committed file cannot express. Where both are present the environment wins, and it is the caller's responsibility that this is deliberate.

#### 5.4.1 Multiple registries

A repository holding several **unrelated products** MAY declare one registry per product:

```yaml
schema_version: "0.1"
registries:
  storefront:
    records: apps/storefront/docs/facets
    sources: [apps/storefront, packages/shared]
    description: the customer-facing shop
  admin:
    records: apps/admin/docs/facets
    sources: [apps/admin, packages/shared]
    description: the internal back office
```

A registry name follows the id segment grammar (`^[a-z][a-z0-9-]*$`), because it is written in front of an id. Declaring `registries` alongside a top-level `records` or `sources` is invalid: which one the tooling means would have no good answer.

#### 5.4.2 Ids are global

**Feature ids span every registry in a repository.** The same id in two registries is the **same feature**, documented independently by each product — not a collision, and not two unrelated features that happen to share a name.

This is a normative statement about meaning, and it makes coverage across registries computable. "How does `auth/login/password` look in the storefront, and in the admin tool" is a question with an answer, and the id is what joins the two records.

Choosing the same id is therefore **a claim, not an accident**. Two products that mean genuinely different things MUST NOT reuse an id; the way to say they are different is to pick different ids. Tooling SHOULD NOT attempt to detect a mistaken reuse: a heuristic over two prose summaries has an arbitrary threshold, and a warning that fires wrongly is a warning that stops being read.

What a registry separates is therefore **specification**, not naming:

| | Variants (§2.4) | Registries (§5.4.1) |
|---|---|---|
| Records per feature | one | one **per registry** |
| Intent and contract | shared | independent |
| Lifecycle | one per variant, in the record | one per registry, in its own record |
| Comparable | yes, within the record | yes, across records, joined by the id |
| Use when | the feature is specified once and realised several times | each product specifies the feature for itself |

The two therefore form a spectrum rather than an either/or, and the id is the join key throughout.

A rewrite still belongs in **one** registry with per-variant lifecycles. Splitting it duplicates intent and contract, and duplicated normative statements of one behaviour have no tie-break when they diverge — the failure §2.4 exists to prevent. Global ids only mean that a project which splits it anyway keeps its coverage question answerable; they do not make the split correct.

#### 5.4.3 Shared code

Two registries MAY list the same directory under `sources`. Such a directory is scanned by both. Three rules govern it.

**Resolution is permissive.** An `@facet:` tag in shared code resolves as long as **any** registry entitled to claim the file holds a record for that id. Without this, adopting registries would report every shared file as broken by whichever registry does not document that feature. An id **no** registry holds is still an unresolved anchor.

**Exclusive code is not.** A tag in a file only one registry claims MUST resolve within *that* registry. Code belonging to one product alone, implementing a feature that product has no record for, is a defect however many other registries hold the id.

**Presence requires exclusive code.** A record MUST NOT count as `active` in a registry on the strength of shared anchors alone — the same rule §2.4 applies to variants, one level up, and for the same reason: shared logic existing does not establish that this product reaches the feature. Since ids are global, without this rule a single anchor in a shared helper would satisfy every registry documenting that id at once, which is precisely the aggregate-that-lies §2.4 removed. This is a warning rather than an error: it is a question about reachability, not a broken registry.

Where a bare id would be ambiguous — the same id documented by both — a tag MAY name the registry it implements for:

```
// @facet: storefront:billing/checkout/coupons
```

A tag naming a registry that is not declared MUST be an error. Every registry skips such a tag as somebody else's, so without the check the file falls out of the registry in silence, which is worse than the typo.

Agent interfaces (§6) SHOULD accept the qualified form wherever they accept an id, and a tool retrieving a feature by bare id SHOULD return **every** registry's record for it rather than one. Returning a single record would be a quiet wrong answer about which product the caller is looking at, and returning all of them is the comparison the shared id exists to enable. §6.3's ban on fuzzy matching is unaffected: the id is still matched exactly.

#### 5.4.4 Project conventions

A project MAY keep its authoring conventions in one prose document: the working language of human-readable prose, terms that are never translated, what an intent summary is for, where unresolved claims go. Tooling resolves **one effective document per registry**, most specific first, and the first that applies wins outright:

1. the registry's own `conventions` key (§5.4.1);
2. the top-level `conventions` key in `.facetrc.yaml`;
3. `FACET-CONVENTIONS.md` at the repository root, if it exists.

Documents are never merged; an override replaces the shared document for that registry. A declared path MUST stay inside the repository, and one that does not exist is an error. A project with none of the three has no effective conventions document.

The document is **prose, never configuration**. Tooling SHOULD name the effective path wherever an agent or reviewer starts work, and MUST NOT interpret its contents. It cannot change the schema, the specification, or what lint enforces, and where it contradicts them they win. It grants no permissions and does not replace the human review §10.2 and §10.3 require. A rule that should be enforced belongs in validated configuration, not in this document.

---

#### 5.4.5 Trackers

A project MAY declare where it keeps its issues, so a ticket a record names (§3.7.1) can be resolved to a tracker and opened:

```yaml
trackers:
  - id: jira
    pattern: '^[A-Z][A-Z0-9_]+-[0-9]+$'
    url: https://example.atlassian.net/browse/{key}
    default: true
  - id: github
    pattern: '^(?P<repo>[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)#(?P<number>[0-9]+)$'
    url: https://github.com/{repo}/issues/{number}
```

**Resolution** is, in order: the tracker a reference names with `tracker`; else the first entry, in declaration order, whose `pattern` matches the key; else the entry marked `default`. Tooling that resolves by `default` MUST say so, because a recognised key and a fallback are different statements. A key nothing resolves stays a bare key; tooling MUST NOT invent a link for it.

**`pattern`** is a regular expression in RE2 syntax, anchored by the author. Its named groups are placeholders in **`url`**, beside `{key}` for the whole key. A pattern that does not compile is a configuration error, not a tracker that never matches. At most one entry may be `default`.

**No credentials.** The list says where issues live, not how to read them. A private tracker is reached with the reader's own access — a connector, a token in the agent's environment. Tooling MUST NOT read a credential from this list, and a project MUST NOT put one there.

**What tooling does with it.** The agent interface (§6) SHOULD return each ticket a record names together with its resolved tracker and link, so an agent can follow it without parsing keys. The core still never fetches an issue (§3.7.1).

#### 5.4.6 ADR directory

`.facetrc.yaml` MAY carry `adr: {directory: <path>}` to name the project-relative directory its decision records live in; absent, it is `docs/adr`. A path that leaves the repository is a configuration error, and tooling MUST NOT read Markdown outside the configured directory.

#### 5.4.7 Forges

A project MAY declare `forges` in `.facetrc.yaml`, keyed by remote host, to name the forge behind a remote. Tooling MUST use that declaration rather than infer a self-hosted forge from its hostname.

#### 5.4.8 Project wiki

A deployment MAY keep Markdown wiki pages beside its records. Wiki write routes MUST require an `Origin` header.

#### 5.4.9 Specification sources

A project MAY declare a project-wide `spec_sources` list. Each entry MUST
declare a unique segment `id` and a Git `repo` URL or `github:<owner>/<repo>`.
`follow` defaults to `main` and `format` to `facet-spec`. If an entry
declares `registries`, only the named registries may reference it.

| Format | Default `path` | Files and spec IDs | Binding |
| --- | --- | --- | --- |
| `facet-spec` | Repository root | Markdown with FACET frontmatter and Gherkin, using the declared spec ID | `exact` |
| `gherkin` | Repository root | Plain `.feature` files, using their relative paths without extensions | `exact` |
| `gherkin-markdown` | Repository root | `.feature.md` files, using their relative paths without the full suffix | `exact` |
| `openspec` | `openspec/specs` | `<capability>/spec.md`, using the capability directory as the spec ID | `exact` |
| `speckit` | `specs` | `<NNN-name>/spec.md`, using the numbered directory as the spec ID | `provenance` |
| `kiro` | `.kiro/specs` | `<feature>/requirements.md`, using the feature directory as the spec ID | `provenance` |
| `bmad` | `_bmad-output/implementation-artifacts` | BMAD v6 story Markdown, using the file stem as the spec ID | `provenance` |
| `gauge` | `specs` | `.spec` and `.md` files, using their relative paths without extensions | `provenance` |

Plain Gherkin takes its language from the file dialect and is `approved`.
Markdown with Gherkin is `approved` and uses the English dialect. It reads
Gherkin headings, step bullets, indented tables, backtick fences for doc
strings, and backticked `@case:<slug>` tags. Its units have the same step and
context digests as equivalent plain Gherkin.
OpenSpec reads accepted specifications in English with status `approved`.
The `openspec/changes` tree is excluded. Each `#### Scenario:` under a
`### Requirement:` is a unit. Its case slug lowercases the requirement and
scenario names joined with a space, replaces runs outside ASCII letters and
digits with one hyphen, and trims edge hyphens. A slug that would start with a
digit gets a `case-` prefix. A slug with no ASCII letters or digits becomes
`case`. Collisions are errors. This name-derived address is weaker than an
explicit case tag because a rename can move it. Bold `GIVEN`, `WHEN`,
`THEN` and `AND` bullets map to Gherkin steps. `AND` inherits its
predecessor's type. A scenario requires `WHEN` and `THEN` steps.

Spec Kit units are `FR-…` requirements and `SC-…` success criteria, with
the printed ID lowercased for the case address. Numbered acceptance scenarios
are excluded. `**Status**:` values `Accepted` and `Approved` map to
`approved`, ignoring case. `Draft`, missing status and any other value map
to `draft`. The digest covers the item text, with runs of whitespace
collapsed to one space.

Kiro pins numbered EARS acceptance criteria under a `Requirement N` heading as
`<feature>#requirement-<n>-<m>`, where `m` is the printed criterion number.
Inserting and renumbering requirements or criteria can shift those addresses.
Kiro defines no file status marker for this format. FACET treats the file as
`approved`.

BMAD reads the story's `Acceptance Criteria` section. Explicit labels such as
`AC1:` take precedence over ordered-list numbers for `<story>#ac-<n>` addresses.
Renumbering a list can shift addresses derived from its positions. Sections
without numbered criteria pin one
`<story>#story` unit for the whole section. `Status:` uses the Spec Kit mapping.

Gauge pins each scenario's own ordered steps with whitespace normalised. A
scenario-level `Tags: id:<slug>` supplies an explicit address. Otherwise the
scenario heading supplies a slug using the OpenSpec slug rules. Gauge files
are treated as `approved`.
Without a configured source, `facet spec lint` reads a `.spec` file as Gauge
only inside a `specs` directory, and a `.md` file there only when a Gauge
`manifest.json` sits beside that directory.

`facet spec lint` recognises these Markdown formats in their default layouts
and recognises `.feature`, `.feature.md` and `.spec` by extension.

Only `facet spec update` writes the lock. It reads the configured branches at
resolved commits and pins file metadata, unit commits, binding and digests.
An `exact` pin stores the normalised `sequence` and context digest. A
`provenance` pin stores the normalised `text` and writes `binding: provenance`;
an `exact` pin omits `binding`. A missing `binding` in an
existing pin means `exact`, and repeating an update against the same commit
preserves that pin's representation. An update with no source arguments selects every declared source.
A full update replaces each selected source and records its commit. The
source-level commit is absent until its first full update.
Repeatable `--only <spec-id>#<case>` arguments advance the named scenarios
where they exist in the selected sources. A requested address must exist in
at least one selected source. Selective updates retain existing source and
file metadata and add file metadata for newly pinned files. A changed file
language, source repository, follow branch or format requires a full update. An ignored
`.facet/sources.local.yaml` MAY map source IDs to local checkouts under
`spec_sources`. Updates using that override read the local `follow` branch
at its committed revision.

An optional `runner` names a declared `cucumber-json` runner in each registry
allowed to use that source. Provenance formats reject `runner`. An omitted setting
leaves exact scenarios `unmeasured`. Execution reads each exact case's commit
from `.facet/spec-cache/`, fetching a missing commit from the source. It writes
one temporary feature per referenced Markdown Gherkin block, preserving its
Background and Rules, or copies the pinned plain `.feature` file. For
Markdown with Gherkin it renders the pinned file as plain Gherkin. For OpenSpec
it writes one Feature per spec file at the pinned commit, with one Scenario
and one `@case:` tag per unit. It removes the temporary directory after the
run. Provenance units are excluded from materialisation and execution.

The declared command receives these absolute paths as extra shell positional
arguments. Include `"$@"` where the runner accepts feature paths, for example
`command: 'cucumber-js --require steps --format json:report.json "$@"'`.
The runner runs in its declared working directory. These files participate in
scenario evidence only. Regular file discovery and file evidence continue to
use the runner's declared list command. The fresh report binds each scenario
element by feature URI and the selected `@case:` or `@id:` tag. With
`FACET_STRICT_DEPS=1`, unavailable spec dependencies make the command fail.

`facet spec drift [<source>...]` fetches each selected `follow` branch and
compares its committed specifications with the lock. With `--cached` it MUST
use only the last fetched snapshot. The command MUST report:

- `spec-moved` when an exact pin's steps or context digest differs or a
  provenance pin's text digest differs. The finding identifies what changed.
- `orphaned` when a pinned address is absent from the fetched specification.
- `unclaimed` when a pinned case has no scenario reference and its file is
  approved at `follow`. Attribute the finding to every record whose
  `lineage.specified_by` names that file.
- `unmeasured` when the source cannot be fetched or read, including when no
  cached snapshot is available.
- `deprecated` when a referenced pinned file becomes deprecated at `follow`.

Each specification finding names its binding strength. When the source
cannot be identified, the strength is `unknown`. Drift's `--json` emits
state, source, address, binding, records and detail. `--diff` shows changes or
removals in the normalised scenario sequence or provenance text. Findings are warnings by default. `--strict` fails on
any finding, and `FACET_STRICT_DEPS=1` fails on `unmeasured`. Usage and
configuration errors fail independently of strict mode.

For projects with specification sources, the native SessionStart hook refreshes
the cache within a shared ten-second budget. Stop compares the cached snapshots
offline and reports new `spec-moved`, `orphaned` and `unclaimed` addresses
once per session. The reporting rule in §3.2.5 applies.

## 6. The Agent Interface

### 6.1 Rationale

Agents reading a FACET registry without a structured interface fall into the same failure modes as agents reading any other documentation corpus: they guess at IDs, over-fetch, hallucinate relationships, and confidently retrieve the wrong feature. The Agent Interface exists to prevent these failures by exposing explicit tools with explicit verbs.

### 6.2 Reference tool surface

A conformant FACET deployment exposes at least the following tools via an MCP server or equivalent agent-framework interface:

| Tool                                          | Purpose                                                                                | Returns                                                        |
| --------------------------------------------- | -------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `feature_find(query, mode)`                   | Search the index. Modes: `semantic`, `lexical`, `by_anchor_path`, `by_owner`, `by_tag` | Ranked list of `{id, headline}`                                |
| `feature_get(id, facets, projection)`         | Retrieve a single record                                                               | Feature record, scoped to requested facets and projection tier |
| `anchor_resolve(path, line_range)`            | Resolve a code location to feature IDs                                                 | List of feature IDs whose anchors cover the range              |
| `anchor_list(feature_id)`                     | List all anchor points for a feature                                                   | List of `{path, symbol, role}`                                 |
| `contract_run(feature_id, env)`               | Execute contract scenarios                                                             | Per-scenario pass/fail with failure context                    |
| `verification_list(feature_id)`               | List linked tests                                                                      | List of test IDs with scenario mappings                        |
| `observation_status(feature_id, window)`      | Current SLO and metric state                                                           | SLO compliance, key metric values                              |
| `lineage_graph(feature_id, direction, depth)` | Upstream or downstream dependency graph                                                | Graph edges to requested depth                                 |
| `policy_list(feature_id)`                     | Applicable policies                                                                    | List of policy records (headlines)                             |
| `assumption_list(feature_id)`                 | Applicable assumptions                                                                 | List of assumption records (headlines)                         |
| `registry_diff(from_ref, to_ref)`             | Changes in the registry between refs                                                   | Added / modified / removed records                             |
| `registry_validate()`                         | Run the cross-facet linter                                                             | List of errors and warnings with record references             |

### 6.3 Tool design principles

- **Exact matching.** Tools that take a feature ID MUST reject unknown IDs with an error. No fuzzy matching; use `feature_find` for discovery.
- **Explicit projections.** `feature_get` MUST accept a projection parameter (see §7). Default is `working`.
- **Deterministic output.** Tool outputs for identical inputs at identical registry revisions MUST be byte-identical. No nondeterministic reordering.
- **Structured errors.** Tool errors include an error code, a human message, and a suggested next action where applicable.
- **No generation.** Tools retrieve and compute deterministically. They do not generate summaries or explanations; that is the caller's responsibility.

### 6.4 Write tools (optional, guarded)

A deployment MAY expose write tools. If it does:

- Write tools produce _proposed diffs_, not direct mutations.
- Proposed diffs land via the normal code review process (pull requests, owner review).
- Write tools are rate-limited and authenticated per agent identity.
- An audit log records every write proposal, including the agent, task context, and review outcome.

Reference write tools: `feature_propose_create`, `feature_propose_update`, `feature_propose_delete`, `assumption_propose_update`.

---

## 7. Projection Tiers and Caching

### 7.1 Projection tiers

Every FACET record is retrievable at four projection levels. The Registry computes projections deterministically from the canonical record.

| Tier         | Content                                                             | Typical size         | Use case                                  |
| ------------ | ------------------------------------------------------------------- | -------------------- | ----------------------------------------- |
| **Headline** | ID + one-line Intent summary + owner + tags                         | ~50 tokens           | Search results, index listings            |
| **Summary**  | Headline + compressed Intent + bulleted Contract behaviors          | ~400 tokens          | "Roughly what does this feature do"       |
| **Working**  | Intent + full Contract (scenarios only) + Anchor + Verification IDs | ~2,000 tokens        | Agent actively working on the feature     |
| **Full**     | All facets + expanded Lineage + linked Policies and Assumptions     | ~5,000–15,000 tokens | Deep work, refactoring, incident response |

The caller specifies the projection. Default is Working. Tools that return lists default to Headline.

### 7.2 Compressed Contract (for Summary projection)

The Summary projection computes a "compressed Contract" by extracting the scenario IDs and the first clause of each scenario statement, producing a bullet list:

```
- discount-cap-applied: Caps discount at 50% when code would exceed
- expired-code-rejected: Rejects codes past their expiry timestamp
- stackable-code-disallowed: Prevents applying a second active code
```

This is mechanical, not generative. The compressed Contract stays consistent with the canonical Contract by construction.

### 7.3 Caching

The Registry MUST maintain per-projection caches keyed by `(feature_id, registry_revision, projection)`. Cache entries are immutable and can be served indefinitely; they are invalidated by moving to a new registry revision.

### 7.4 Agent prompt structure

For agent consumers, FACET recommends a three-layer prompt structure aligned with commercial prompt-caching features:

1. **Stable prefix (cacheable, session-long):** Schema definition, tool definitions, agent operating instructions, optionally a domain-scoped index slice (e.g., all `checkout/*` headlines).
2. **Retrieval layer (per-task):** Results of tool calls — specific feature records at chosen projection tiers.
3. **Task layer (per-turn):** Current task description, conversation history, output requests.

Prefix stability and explicit layering are not required for correctness, but are strongly recommended for cost.

---

## 8. Adjacent-Surface Consistency

FACET does not attempt to replace all documentation. For each adjacent documentation surface, FACET prescribes one of three patterns.

### 8.1 The three patterns

**Pattern G — Generate.** The adjacent surface is mechanically generated from the FACET record. There is no hand-authoring of the derived artifact. Examples: OpenAPI specs, some types of user-facing docs where tone is acceptable.

**Pattern C — Consistency check.** The adjacent surface is hand-authored but linked to the FACET record by explicit reference. A periodic check flags divergence in factual claims, leaving editorial content untouched. Examples: user help articles, support agent scripts.

**Pattern L — Loose couple.** The adjacent surface is independent and governed by its own process. A link from the surface to the FACET record enables cross-awareness but does not require synchronization. Examples: marketing copy, legal commitments.

### 8.2 The surface mapping

| Surface                     | Pattern | Notes                                                                            |
| --------------------------- | ------- | -------------------------------------------------------------------------------- |
| OpenAPI / JSON Schema       | G       | Generate from Contract pre-states                                                |
| Internal API reference      | G       | Generate from Contract + Anchor                                                  |
| Runbooks                    | C       | Link to Observation; drift check on SLO values                                   |
| Support scripts             | C       | Link to Contract + Knowledge; drift check on numeric values and rule statements  |
| End-user help articles      | G       | Generate from Knowledge facet via the pipeline in §8.5; review-gated publication |
| FAQ / knowledge base        | G       | Generate from Knowledge facet (§8.5)                                             |
| In-product tooltips / hints | G       | Generate from Knowledge.success_signal and Knowledge.common_pitfalls (§8.5)      |
| Release notes               | G       | Generate from `registry_diff`                                                    |
| Marketing copy              | L       | Reference feature IDs; editorial review on change                                |
| Legal / compliance pages    | L       | Assert via Policies; legal owns commitment language                              |
| Internal training materials | L       | Reference; refreshed on scheduled cadence                                        |
| External developer docs     | G       | Generate from Contract + Anchor + OpenAPI projection + Knowledge                 |

### 8.3 Implementation expectations

A conformant deployment SHOULD provide:

- At least one generator for OpenAPI output from Contract pre-states (Pattern G)
- At least one generator for an FAQ-shaped artifact from the Knowledge facet (Pattern G, §8.5)
- A consistency-check facility that compares a markdown document's claims against a referenced feature and flags divergence (Pattern C)
- A reference-tracking facility so that Pattern L surfaces record their feature links in a queryable store

### 8.4 Divergence budget

For Pattern C and Pattern L surfaces, divergence between the authoritative FACET record and the adjacent artifact is expected and managed rather than prevented. Deployments SHOULD define:

- Detection SLA — how quickly divergence is surfaced after a FACET change
- Reconciliation SLA — how quickly divergence is resolved
- Escalation — what happens when reconciliation SLA is missed

### 8.5 Knowledge-Generator Pipeline

> This subsection specifies the reference path from FACET records to the user-facing knowledge base.

**Goal.** Treat the user-facing knowledge base (help center, FAQ, onboarding tooltips, in-product hints, public developer docs) as a Pattern G surface generated from FACET records — specifically from the Knowledge facet, augmented by Intent, Contract, Anchor, and source code.

**Why a separate pipeline.** Existing OpenAPI / API-reference generation (§8.2) operates on Contract pre-states. User knowledge operates on _why a person would care_, _how they enter_, and _what to watch out for_ — none of which is in pre-states. The Knowledge facet exists precisely to feed this pipeline.

**Reference architecture.**

```
                          ┌─────────────────────────┐
  facet.yaml              │  Knowledge-Generator    │
  ├── intent              │                         │
  ├── contract            │  1. Load record         │
  ├── knowledge ──────────┤  2. Resolve derive_from │
  ├── observation         │  3. Load source via     │
  └── lineage             │     anchor_list()       │
                          │  4. Compose LLM prompt  │      ┌────────────────────┐
  source code ────────────┤  5. Render artifact     ├────▶ │ FAQ entry          │
   (resolved via @facet:) │  6. Cite sources        │      │ Help-center page   │
                          │                         │      │ Tooltip / hint     │
  template ───────────────┤                         │      └────────────────────┘
                          └─────────────────────────┘
```

**Stages.**

1. **Load.** Fetch the feature record at projection `full` (see §7.1). Knowledge slots are the primary input; Intent, Contract, and Lineage provide context.
2. **Resolve `derive_from`.** For each Knowledge slot, follow the `derive_from` hints to load additional context: source code via `anchor_list()`, dependent feature headlines via `lineage_graph()`, related policies, etc. This step is deterministic; the generator never invents sources.
3. **Compose.** Build a structured LLM prompt using the three-layer pattern from §7.4: stable prefix (template + tool/agent instructions), retrieval layer (the loaded record + derived sources), task layer (target artifact format).
4. **Render.** The LLM produces the artifact in the target format (FAQ, markdown article, JSON tooltip set). Output MUST be FAQ-shaped — organised around the Knowledge slot questions — not marketing prose. Each rendered question carries a citation to the FACET record revision and the source files consulted.
5. **Review gate.** Generated artifacts are not published directly. They land as a PR on the documentation repository; the feature owner reviews edits as needed; merge triggers publication. (This makes the pipeline Pattern G with Pattern C-style review for the rendered text.)
6. **Drift detection.** On every FACET record change, the pipeline re-renders affected artifacts and surfaces a diff. If the diff exceeds a threshold (e.g. > 20% line change), the pipeline files an issue; small diffs are auto-PRed.

**Required pipeline properties.**

- **Reproducibility.** Identical record revision + identical model + identical template MUST produce byte-identical output. Pipelines using stochastic sampling MUST cache outputs keyed by record revision.
- **Citations.** Every rendered fact MUST be traceable to either a Knowledge slot answer (owner-supplied) or a `derive_from` source (record section or source file path + symbol).
- **No fabrication.** If a Knowledge slot is empty and not derivable, the pipeline MUST omit the corresponding section rather than invent it. Coverage gaps are visible, not papered over.
- **Versioned templates.** The artifact template (the stable prefix) is itself versioned and stored in the repository. Template changes are reviewed.

**Implementation expectations.** A conformant deployment SHOULD provide at least one reference generator (FAQ markdown from Knowledge slots) and SHOULD ship the artifact template alongside the FACET schema. Production-grade pipelines (multi-locale rendering, in-product tooltip extraction, ranked search index generation) are out of scope for the spec but compatible with this architecture.

**What the pipeline does not replace.** Marketing copy, legal/compliance language, and editorial product writing remain Pattern L surfaces (§8.2). Knowledge generation feeds the _knowledge base_ — the place users look for "how do I do X" — not the pages that exist to persuade or to make commitments.

---

**Records MUST NOT be translated.** They state one normative contract. Locale-specific generated artifacts MAY declare their locale and use `source-artifact` and `glossary` input roles in the generation manifest.

### 8.6 Generation Freshness

> This subsection closes the maintenance half of the loop §8.5 opens.

**The gap.** §8.5 stage 6 re-renders when the _record_ changes. But a generated artifact is derived from the record _and_ from the source files the record anchors, and the code changes far more often than the record does. An article whose anchored implementation was rewritten is silently wrong, with nothing anywhere indicating it. §11 detects records drifting from code; nothing detected documentation drifting from the record-plus-code that produced it.

This matters more than it appears, because generation is the point at which FACET stops costing effort and starts producing output. A deployment that generates a hundred articles once and cannot say which twelve went stale has not solved its documentation problem — it has automated it.

**The generation manifest.** A conformant deployment records, for each generated artifact, the inputs that produced it. The manifest is a lockfile, not an attestation: it answers exactly one question — _have the inputs that produced this artifact changed?_ — and is designed to be diffed in a pull request.

Each entry records the artifact (`subject`), the feature it came from, the generator, and the resolved input set: the record plus every source file anchoring that feature at generation time, each with a content digest.

**Required properties.**

- **Content digests, never timestamps.** Comparison MUST be by content hash. Version control does not preserve modification times, so a timestamp comparison marks every artifact stale after a fresh checkout, and a check that always fires is a check nobody reads. The commit identifier MAY be recorded as narration but MUST NOT be the comparison key: rebases and squash merges rewrite it, and shallow clones cannot resolve it.
- **The resolved input set is part of the manifest.** Anchors are resolved by scanning source (§3.3), so the input set is not fixed at generation time — a later commit can add or remove an anchor without touching any file already recorded. A conformant check MUST therefore compare the _set_ of anchors the feature currently resolves to, not only the digests of the inputs it already knows. Omitting this yields a check that appears sound and silently misses a real dependency.
- **The generator is an input.** The pipeline is an LLM and therefore not hermetic. The model identifier and template version MUST be recorded, and a change to either invalidates the artifact exactly as a changed compiler invalidates a build.
- **Staleness is a warning.** A stale artifact MUST NOT block a merge by default. Stale documentation is a maintenance signal, not a broken build, and a gate on generated prose is routed around rather than satisfied. A deployment MAY offer a strict mode for release gating.

**Two tiers.** The digest comparison answers "could this have changed?" and nothing more. It is cheap enough to run on every build. When it fires, a deployment MAY apply a second, semantic tier: ask whether the diff changes anything a user of the feature would notice, caching the verdict against the diff's hash so each change is judged once. The ordering is the design — tier 1 decides _when_ tier 2 runs and never replaces it. Tier 2 is OPTIONAL; requiring it would make conformance depend on an LLM budget.

**Reducing false positives.** Two refinements are available and neither is required. A deployment MAY record which Knowledge slots an artifact consumed, and flag per slot rather than per document. Where a language offers a public-API-surface tool, a deployment MAY digest the API rollup rather than the source file, which makes refactors invisible by construction.

**Prefer inclusion over generation.** Anything derivable verbatim from source SHOULD be transcluded rather than generated. A generated copy can rot; an include cannot. This subsection governs the material that genuinely must be composed — prose synthesised from a record — and deployments SHOULD keep that set as small as they can.

**Implementation expectations.** A conformant deployment SHOULD provide a check that recomputes the manifest and reports each artifact as `current`, `stale` (an input moved), or `orphaned` (its feature record no longer exists), and SHOULD commit the manifest alongside the artifacts it describes.

---

## 9. Scope Boundary

### 9.1 Out-of-scope claim domains

FACET is a single source of truth for a defined domain of claims about features. It is _not_ a single source of truth for everything related to a feature. The following are out of scope:

**Business rationale and strategic context.** The Intent facet is a brief summary. The authoritative source for rationale is the linked decision records (ADRs, RFCs, strategy documents). FACET does not replicate this reasoning.

**Assumption evidence.** Assumption records reference evidence (research, analytics, competitive data) by link. The evidence itself lives in its native systems.

**User experience and interaction design.** FACET contracts describe system behavior under conditions. They do not describe the felt experience of using a feature. Design systems, prototypes, and UX documentation own this.

**Visual design and copy strings.** Design tokens, icons, microcopy, and layout rules live in their respective systems (design system registries, CMSs).

**Probabilistic and ML behaviors.** Gherkin-style pre-state/post-state contracts strain for features whose correctness is statistical (ranking, recommendation, fraud detection). FACET does not prescribe a format for these.

**Historical reconstruction.** FACET records capture the current normative state. Reconstructing the state of a feature at an arbitrary past moment requires git-history tooling external to FACET.

**Customer-facing product positioning.** Marketing and sales materials are governed by their own editorial processes and linked only loosely.

**Organizational processes around features.** Sprint planning, roadmap prioritization, resource allocation, and similar are not FACET concerns.

Deployments that attempt to extend FACET into these domains will encounter friction and are advised not to do so.

### 9.2 Architectural fit

FACET works well when `@facet:` tags can identify feature code with reasonable density — meaning most anchored symbols are tagged with one, two, or occasionally three feature IDs. This covers the majority of real-world codebases, including codebases that do not follow feature-based architecture.

FACET works **less well** in codebases where most functions participate in many features simultaneously. Symptoms of poor fit include:

- Anchor symbols that would legitimately require five or more `@facet:` tags each
- A dominant pattern of very long functions with multiple unrelated responsibilities
- Cross-cutting code paths that touch nearly every feature in the product (a single god-object orchestrator, for example)

In such codebases, the per-symbol tagging cost outgrows the benefit, and architectural analysis produces signals that are too noisy to act on. Typical examples: legacy enterprise Java prior to modularization, older Rails monoliths with fat controllers, long-lived C++ systems with god-classes.

The honest recommendation for these codebases is to defer FACET adoption until a baseline of modularization has been achieved for other reasons (testability, deploy isolation, team ownership). FACET can amplify architectural clarity where it exists but cannot create it where it does not.

A rough heuristic: if more than 20% of the symbols you would tag would require three or more `@facet:` tags, the codebase is likely in the "defer" category. If fewer than 5% do, FACET is a comfortable fit. In between, expect a bumpy first quarter but a workable outcome.

### 9.3 Partial adoption is valid

FACET does not require whole-codebase coverage. A deployment that covers 60% of features — typically the high-change, high-risk ones — is a legitimate and useful deployment. The uncovered 40% is simply not in the Registry; it is not treated as broken or non-conformant. The Scope Boundary includes the implicit boundary of "features the organization has chosen to document."

---

## 10. Authoring Workflow

### 10.1 Principles

- **Agents draft, humans own.** Most initial authoring of records can be agent-assisted, including the Knowledge answers the agent can support with evidence; it leaves the others empty. Ownership remains with the feature's team: the owner reviews what an agent drafted and confirms, corrects or removes it.
- **Granularity is a human decision.** Deciding what constitutes a feature, and where its boundaries are, is editorial judgment that agents are not reliable at.
- **Review is proportional.** Boilerplate facets (anchors, verification links) can be reviewed quickly. Intent and Contract require substantive review.

### 10.2 New-feature authoring

1. Human (typically the feature's technical lead) creates a stub record with a proposed canonical ID, a one-line Intent, and an owner.
2. Agent drafts initial Contract scenarios from existing tests, designs, or the PR's introduced behavior.
3. Agent drafts Anchor section from `@facet:` tags in the code.
4. Agent drafts Verification links by matching test identifiers to scenarios.
5. Agent drafts Knowledge slots: pre-fills the question text from the standard slot template (§3.6); fills derivable answers (e.g. `discoverability`) from anchors; answers the owner-supplied slots (`prerequisite_knowledge`, `not_for`, `success_signal`, `common_pitfalls`) it can answer from the implementation, the contract, existing documentation and real entry points, and leaves the others empty, naming them to the owner; it never invents an answer. Drafted answers are marked as agent-drafted (§10.4).
6. Human reviews and edits, particularly Intent prose, Contract pre-states, Assumption identification, and every agent-drafted owner-supplied Knowledge answer.
7. Record lands with the implementation PR.

Typical time: 15–30 minutes of human time per new feature when agent assistance is available. The Knowledge facet adds 5–10 minutes if the owner-supplied slots are filled at authoring time; deferred completion is permitted (linter warns but does not error). Without agent assistance, typically 60–120 minutes.

### 10.3 Record maintenance

On every PR that touches anchored code, a maintenance agent:

1. Reads the diff.
2. Identifies candidate records that may need updates.
3. Drafts record updates (Anchor changes, Contract scenario additions or edits, Verification reference updates).
4. Opens a follow-up PR (or extends the current PR) with the draft updates.
5. The code PR's human reviewer approves or revises the record update.

Fully autonomous updates are permitted for:

- Anchor section regeneration when `@facet:` tags move but don't change IDs
- Verification reference updates when test files are renamed
- Lineage graph regeneration
- Knowledge slot question text updates (the standard template is owned by the deployment, not the record)
- Knowledge `discoverability` answer regeneration when anchors move and the slot uses `derive_from: [anchors]`

Autonomous updates are rejected for:

- Contract changes (always require human review)
- Intent changes (always require human review)
- Assumption additions or edits (always require human review)
- Ownership changes
- Knowledge `prerequisite_knowledge`, `not_for`, `success_signal`, and `common_pitfalls` answers (owner-supplied; an agent may draft the ones it can support with evidence in the PR, marked as agent-drafted, and leaves the others empty; the owner's review decides whether they land)

### 10.4 Authorship metadata

Every record tracks, per section:

- Human author(s) of the last substantive edit
- Whether the section was agent-drafted originally
- Review status (reviewed by whom, at what revision)

This metadata is used by the UI to highlight areas requiring careful review and by auditors to answer "who actually wrote this."

### 10.5 Tool annotations

Tooling that touches records needs somewhere to leave a note — which discovery pass proposed this record, which document a section was drafted from, which governance review cleared it — and in the absence of a declared place it either invents a top-level key the schema rejects or writes prose into a field meant for something else.

`metadata` is that place: a flat map of string keys to string values, both capped at 1000 characters.

```yaml
metadata:
  discovered_by: discovery-agent@2026-07
  source_ref: "example-review"
  governance_review: cleared 2026-07-14
```

**It is not authoritative record content.** Nothing normative may live here, and no tool may require a key it did not write. A reader who needs to understand the feature reads `intent` and `contract`; `metadata` explains how the record came to exist, not what the feature does.

**It is flat and bounded, where `authorship` (§10.4) is nested and unbounded.** The cap is the whole design: an unbounded free-form map is where a tool eventually writes a log, a diff, or a full LLM response, and a record that has become a log file is no longer a document anybody reads. Structure worth nesting is worth a specified field.

---

## 11. Drift Detection and Integrity

### 11.1 The linter

A conformant deployment MUST provide a cross-facet linter that runs in CI on every record-touching PR and on schedule against the full registry. The linter is the integrity backbone of FACET.

### 11.2 Error categories

| Severity | Category                              | Example                                                                    |
| -------- | ------------------------------------- | -------------------------------------------------------------------------- |
| Error    | Anchor tag references unknown feature | `@facet:` tag in code references a feature ID not in the registry          |
| Error    | Feature with no anchors               | Record exists but no `@facet:` tags in code reference it (orphaned record) |
| Error    | Verification reference                | Linked test ID does not exist in the test suite                            |
| Error    | Schema validation                     | YAML record fails schema                                                   |
| Error    | Scenario/pre-state divergence         | Contract scenario statement contradicts pre-state constraints              |
| Error    | Policy constraint                     | Record violates a Policy that governs it                                   |
| Error    | Broken dependency                     | Lineage `depends_on` references a nonexistent feature                      |
| Error    | Knowledge `derive_from` invalid       | A Knowledge slot's `derive_from` references a section or source that the record does not expose |
| Error    | Undeclared taxonomy segment           | A record's id names a domain or capability the deployment's taxonomy (§4.4) does not declare; silent where no taxonomy is declared |
| Error    | Duplicate glossary term               | The same term is defined twice in the deployment's glossary (§4.5); silent where no glossary is declared |
| Error    | Duplicate glossary category           | The same category id is declared twice in the glossary's `categories` list (§4.5 rule 8) — two headings under one name |
| Error    | Examples row does not match its columns | A row under a scenario's `examples` (§3.2.3) carries more or fewer values than its block has columns, counting the columns it inherits. Values are matched to columns by position, so no reading of such a row is correct: a short row leaves its last column with no value at all. A lint category only because draft-07 has no keyword bounding one array by the length of another |
| Error    | Undeclared glossary category          | A term names a category the glossary does not declare (§4.5 rule 9). The correct answers are in the same file, so this is a typo or a category that was deleted; a term naming no category is silent, because absent means nobody decided |
| Error    | Anchor scenario reference             | An `@facet-proves:` id does not exist in the anchored record's contract scenarios |
| Warning  | Enum divergence                       | Data entities declare different value sets for the same controlled-value field |
| Warning  | Error code reused across domains      | The same stable error-code identifier occurs in records from more than one domain |
| Warning  | Superseded implementation             | A record declares a successor while still active, or remains anchored after its successor becomes active |
| Warning  | Anchored record without scenarios     | Source anchors a record that declares no contract scenarios |
| Warning  | Uncovered scenario                    | Contract scenario has no linked Verification                               |
| Warning  | Stale assumption                      | Linked Assumption is past its `review_by` date                             |
| Warning  | Multi-tag concentration               | Symbol carries ≥ N `@facet:` tags (N configurable, default 4)              |
| Warning  | Broken link                           | Linked ADR, runbook, or dashboard URL returns 404                          |
| Warning  | Empty Knowledge facet (active record) | An `active` record has no Knowledge slots filled; never blocks merge. A slot declaring `not_applicable` (§3.6.1) is not empty — it is answered with the statement that there is nothing to answer — and is silent, while its siblings in the same record are reported as before |
| Warning  | Knowledge "tbd" placeholder           | A Knowledge answer contains placeholder strings (`tbd`, `todo`, `xxx`); placeholders are worse than absence |
| Warning  | Empty taxonomy node                   | A declared domain or capability (§4.4) has no record written under it |
| Warning  | Glossary near miss                    | A word in `intent.summary` or a contract statement is not a defined glossary term (§4.5) but is very nearly one — the same letters in a different case, or a small edit away. The spelling links nowhere and nothing else would say so |
| Warning  | Empty glossary category               | A category the glossary declares (§4.5 rule 10) that no term names — usually a rename that stopped half way. Declaring one before writing its first term is the intended order, so it can never be an Error |
| Warning  | Scenario count out of band            | An `active` record declares a single contract scenario, or far more than §2.1.1 gate 3 allows — the one gate a machine can evaluate. Counted per scenario, never per `examples` row (§3.2.3) |
| Warning  | Placeholder answered by no column     | A `<name>` in a scenario's statement names no column any of its `examples` blocks declares (§3.2.3), so it is never substituted and the table beneath it fills nothing. A Warning rather than an Error because the observation is certain and the inference is not: prose carries angle brackets that were never meant as parameters, and a build must not fail on a sentence that reads correctly. The other direction is silent — a column no placeholder names is ordinary Gherkin |
| Warning  | Unanchored hotspot                    | A substantial source file carries no `@facet:` anchor while most of its directory does; silent where the neighbourhood is undocumented, so a project that has not adopted FACET hears nothing. Judged from the repository rather than from a record |
| Warning  | Undocumented directory                | No source file in a directory carries an anchor while the repository anchors a substantial share of its source. Silent in a repository without anchors. File types are learned from existing anchors; a language never anchored remains outside this check |
| Warning  | Lost implementation reference         | Since a stated baseline, an anchored file was deleted or an anchor removed from a file — reported even while another anchor of the same record survives. Never replaces the "Feature with no anchors" Error, never edits a record. A baseline that cannot be compared is reported as missing evidence, never as no loss |
| Warning  | Stale deviation                       | A scenario declares a `deviation` (§3.2.2) whose `tracked_as` names a record that has since gone `active` — the fix may have shipped while the defect stayed written down. Declaring the deviation is never itself a finding, and nothing checks its wording: whether the scenario's id names the observed behaviour is a review obligation, for the reasons §3.2.2 gives |
| Info     | Low Intent detail                     | Intent is under 50 words or low-entropy (possibly boilerplate)             |
| Info     | Coverage ratio                        | < 80% of scenarios have verifications                                      |
| Info     | Low anchor density                    | Feature's anchors span many files with few symbols per file                |
| Info     | Knowledge coverage ratio              | < 50% of `active` records have ≥ 3 non-empty Knowledge slots (deployment-wide signal) |

### 11.3 Linter enforcement

- CI blocks merge on any Error.
- Warnings are visible in PRs and in the Registry dashboard but do not block merge.
- Teams set their own thresholds for converting Warnings to Errors.
- The linter's output is available to agents via the `registry_validate()` tool; agents can proactively check and fix their own work.
- **A run's summary SHOULD report warnings per category, not only as a total.** One number is what a reader starts using as a checksum — *still 46* read as *nothing broke* — and a figure used that way has stopped being a warning. The failure is then structural rather than careless: a new finding moves the total by one, exactly as a cleared one does, so the category is the only thing that says which happened.

  This matters most where it is least convenient. A check that lands many findings on its first run is not a regression, and a total that jumps for no stated reason claims one. Reported per category it reads as one new figure beside unchanged neighbours, and the standing backlog stays legible through the change. The categories in §11.2 differ in who owes the work and by when, which is the distinction a single total destroys; ordering by count and then by name keeps two runs over an unchanged registry comparable.

  This is necessary and not sufficient. A change that reclassifies existing claims rather than adding findings — moving scenarios between states, say — is counted along a different axis than findings-per-category, and reporting it honestly needs its own figures. What the breakdown guarantees is only that such a change cannot arrive disguised as a moved total.

### 11.4 Calibration

Every check in §11.2 judges one record. Granularity is a property of the whole list and invisible from inside any entry of it: a registry of three thousand records with one scenario each and a registry of thirty with forty scenarios each both pass every check, and they are the same product documented two levels apart.

A conformant deployment SHOULD therefore report the registry's **shape** as well as its integrity:

| Measure | Typical | Investigate |
| --- | --- | --- |
| Domains per product | 3–12 | 1–2 (the segment distinguishes nothing), > 15 |
| Capabilities per domain | 2–10 | 1, > 12 |
| Features per capability | 2–12 | 1 (the same thing named twice), > 12 (a level is missing) |
| Scenarios per record | 2–9 | 0–1 (it is a scenario), > 12 (it is a capability) |

The ranges above are calibration heuristics, not measured adoption rates. A registry can mix narrowly grouped capabilities with broad groups. A single median can hide that mixture; reporting the groups separately makes the relevant cleanup visible.

Four constraints on such a report:

1. **It reports; it does not gate.** A deployment whose shape is genuinely unusual keeps its shape, and a check that could fail a build would be answered by tuning the number rather than the records.
2. **Medians, not means.** One forty-scenario record among two thousand single-scenario records leaves an unremarkable mean, and the mean is what conceals this.
3. **It names the level, not the number.** "The median record declares one scenario" is a measurement; "records are being written at scenario granularity" is the finding, and only the second tells a reader what to do.
4. **It says where the registry disagrees with itself.** A measure whose samples fall into two populations is reported as two, because which one a reader is in decides what they do next.

Scenario count, not record count, is the measure of how much a registry actually asserts. Two registries documenting one product at different granularities describe the same behaviour, so the assertion count should barely move between them; where it does, the difference is work that was never done rather than a decomposition that was chosen.

---

## 12. Change Management

### 12.1 Changes that require record updates

Any of the following MUST produce a record update in the same PR:

- Changes to normative behavior of a feature
- Addition, removal, or relocation of `@facet:` tags (these update the derived Anchor automatically; the PR must still reflect that the feature's code footprint has changed)
- New tests proving contract behavior
- Changes to SLOs or alert rules
- Transfers of ownership
- Changes to policies governing the feature
- Changes to user-visible behavior that invalidate any populated Knowledge slot (e.g. permission requirements change → `prerequisite_knowledge` must be re-reviewed; new common failure mode → `common_pitfalls` updated)

### 12.2 Changes that do not require record updates

- Internal refactors that do not change behavior or add/remove `@facet:` tags
- Performance improvements within existing SLO envelope
- Cosmetic changes, formatting, dependency version bumps

### 12.3 Lifecycle states

A record's `lifecycle` field carries one of four values:

| Value | Meaning | Anchor required? |
|-------|---------|-----------------|
| `planned` | Feature is designed and documented, but not yet implemented in source code. No `@facet:` tags are expected; the orphan-record linter is silent. | No |
| `active` | Feature is implemented and deployed. At least one `@facet:` anchor must exist in source; the linter enforces this. | **Yes** |
| `deprecated` | Feature is being phased out. Set `superseded_by: <new-id>` and a sunset date. Record remains in the registry until sunset. | No (relaxed) |
| `sunset` | Feature has been removed. Record moves to the `graveyard/` area. IDs are never reused. | No |

There is deliberately **no `partial` value**, and no value between `planned` and `active`. A feature that ships a surface whose data does not exist yet is `active` — the code is there, the anchor is there, a user reaches it — and the unbacked behaviour is declared per scenario with `backing` (§3.2.1). The reasoning is §3.8's: `lifecycle` describes existence, and adding a value for a different axis makes the field mean two things at once. A record-level value would additionally be an aggregate over scenarios, which §2.4 removed for variants for the same reason it would fail here.

**Transitioning from `planned` to `active`:** Add `@facet:` tags to all implementing files and change `lifecycle` to `active` in the same PR. The CI anchor-check will then enforce coverage.

**Deprecation procedure:** Set `lifecycle: deprecated`, `superseded_by: <new-id>`, and record the planned sunset date in `lineage.change_history_ref`. The record remains queryable until the sunset date.

### 12.4 Versioning within records

Records themselves are versioned through git. The framework does not prescribe semantic versioning of records. For features whose Contract is consumed externally (e.g., a public API), semantic versioning of the Contract is recommended but out of scope for this spec.

---

## 13. Adoption Path

### 13.1 Greenfield projects

Adopt FACET from the first feature so records and source anchors are authored with the initial implementation.

### 13.2 Small mature codebases (< 50 features)

Pilot on a single domain first. Expand incrementally after the records, source anchors and review workflow have been exercised by that project.

### 13.3 Large mature codebases (500+ features)

Scope and pace depend on the project. An illustrative sequence is:

1. Registry infrastructure, schema, linter, basic UI. Pilot domain selected.
2. Document the pilot domain and capture baseline metrics.
3. Agent tool surface deployed. Agent-assisted authoring enabled.
4. Expansion to additional domains, prioritized by change frequency and risk.
5. Prioritize coverage of high-change features. Generator integrations for OpenAPI and release notes.
6. Completeness drive. Pattern C consistency checks deployed for user help, support scripts, runbooks. Pattern L reference tracking for marketing and legal.
7. **Ongoing:** Maintain; iterate.

### 13.4 Organizational prerequisites

FACET assumes:

- Docs-as-code is culturally acceptable
- Pull request review processes are trusted
- Tests are a first-class engineering artifact, not an afterthought
- Some budget for tooling investment exists

Organizations without these will struggle with adoption regardless of framework quality.

---

## Appendix A — Reference Schemas

### A.1 Feature record

```yaml
# facet.yaml
schema_version: "0.1"
id: checkout/pricing/discount-code-redemption
lifecycle: planned # planned | active | deprecated | sunset
intent:
  summary: |
    Allows users to apply a promotional code at checkout, reducing their
    cart total according to the code's rules and the campaign's terms.
    Exists to enable marketing-driven promotional campaigns.
  decision_records:
    - adr/2024/adr-017-discount-engine.md
    - rfc/2024/rfc-042-promo-campaigns.md
contract:
  scenarios:
    - id: discount-cap-applied
      statement: |
        Given a cart subtotal of any positive amount
        And a discount code whose raw discount would exceed 50% of subtotal
        When the code is applied
        Then the effective discount equals 50% of subtotal
        And the user sees a "capped" advisory message
      pre_state:
        cart:
          subtotal_minor_units: { type: integer, range: [1, inf] }
        discount_code:
          exists: true
          status: ACTIVE
          raw_discount_pct: { constraint: "> 0.50" }
      post_state:
        effective_discount_minor_units: "floor(subtotal * 0.50)"
        user_message_code: DISCOUNT_CAPPED
    - id: campaign-budget-remaining-shown
      statement: |
        Given a discount code belonging to a budgeted campaign
        When the code is applied
        Then the remaining campaign budget is shown to the user
      backing: # §3.2.1 — declared, shipped, deliberately not backed yet
        state: unbacked
        reason: |
          Campaign budgets are tracked in the finance ledger, which exposes no
          per-campaign balance yet, so the advisory renders without a figure.
        unblocked_by: finance/ledger/campaign-budgets
# NOTE: No `anchor:` section. Anchors are derived from `@facet:` tags in source
# code and served by the Registry. See §3.3.
verification:
  unit_tests:
    - id: pricing::discount::test_cap_at_50_percent
      proves: [discount-cap-applied]
observation: # operator-facing: how health is judged
  slos:
    - name: discount-apply-success-rate
      target: 99.9
      window: 28d
  alerts:
    - name: discount-apply-error-spike
      runbook: runbooks/discount-apply-errors.md
observability: # §3.5.1 — developer-facing: what is actually emitted
  metrics_emitted:
    - name: discount_apply_total
      kind: counter
      labels: [outcome, campaign_id]
      description: discount code redemption attempts
  traces_emitted:
    - span_name: checkout.discount.apply
      parent_span: checkout.session.create
  log_events:
    - event: checkout.discount.capped
      level: info
      attributes: [trace_id, cart_id]
knowledge:
  prerequisite_knowledge:
    question: "What must the user already understand to use this feature?"
    answer: |
      The user must have a discount code from a marketing email or partner
      site, and an active cart with at least one item.
  not_for:
    question: "When is this the wrong tool for the job?"
    answer: |
      Not for stacking multiple promotional offers; not for B2B contract
      pricing; not for loyalty point redemption.
  discoverability:
    question: "Where does the user enter this flow in the product?"
    derive_from: [anchors]
  common_pitfalls:
    question: "What mistakes do users typically make?"
    answer: |
      Pasting whitespace with the code; using a code that has expired
      but was bookmarked from an old email; assuming the discount applies
      before tax (it applies after).
  success_signal:
    question: "How does the user know it worked?"
    answer: |
      The cart total updates immediately, a green confirmation banner
      shows the discount line item, and the discount appears in the
      order summary email.
lineage:
  owner:
    team: checkout-pricing
    individual: author-one
  created_at: 2024-09-02
  depends_on: [checkout/cart/line-item-subtotal]
  related_policies: [policy/finance/revenue-recognition-v2]
  related_assumptions: [assumption/pricing/discount-codes-do-not-stack]
authorship:
  intent:
    { author: author-one, last_edited: 2025-11-18, agent_drafted: false }
  contract:
    {
      author: reviewer-one,
      last_edited: 2026-03-02,
      agent_drafted: true,
      agent_reviewed_by: reviewer-one,
    }
```

### A.2 Policy record

```yaml
schema_version: "0.1"
id: policy/privacy/gdpr-erasure
intent:
  summary: |
    On a verified user erasure request, all personal data associated with
    the user must be deleted or irreversibly anonymized within 30 days.
  regulatory_basis: GDPR Art. 17
contract:
  clauses:
    - id: erasure-sla
      requirement: "Erasure completed within 30 days of verified request"
    - id: erasure-completeness
      requirement: "All linked data entities for the user are processed"
scope:
  governs_features:
    - identity/account/account-deletion
    - commerce/orders/order-history
    - support/tickets/customer-tickets
verification:
  compliance_checks:
    - id: compliance::gdpr::erasure_timeliness
      cadence: weekly
  audit_artifacts:
    - report/compliance/gdpr-quarterly
lineage:
  owner: { team: privacy-program, individual: privacy-officer }
  created_at: 2023-01-15
```

### A.3 Assumption record

```yaml
schema_version: "0.1"
id: assumption/pricing/discount-codes-do-not-stack
statement: |
  Users expect and desire that a cart has at most one active discount
  code at a time. Stacking is not expected, and introducing it would
  create UX and revenue complexity.
evidence:
  - type: user-research
    reference: research/2024-q1-pricing-study
    date: 2024-03-12
review_by: 2026-03-01
criticality: high
risk_if_false: |
  Several features assume single-code semantics; changing the
  assumption requires coordinated redesign of the promo engine
  and revenue recognition pipeline.
referenced_by:
  - checkout/pricing/discount-code-redemption
```

### A.4 Data entity record

```yaml
schema_version: "0.1"
id: data/promo/discount-code
canonical_schema:
  fields:
    - { name: code, type: string, constraints: [unique, "length:4-32"] }
    - { name: campaign_id, type: uuid, references: data/promo/campaign }
    - { name: status, type: enum, constraints: ["enum:ACTIVE,EXPIRED,DISABLED"] }
    - { name: raw_discount_pct, type: decimal, constraints: ["range:0-1"] }
    - { name: redemptions_remaining, type: integer, constraints: ["min:0"] }
retention:
  policy: retain-2y-after-campaign-end
ownership: { team: promo-platform }
read_by:
  - checkout/pricing/discount-code-redemption
  - checkout/summary/cart-summary-display
mutated_by:
  - checkout/pricing/discount-code-redemption
  - promo/admin/code-management
```

---
## Appendix B — Summary of Changes

### B.1 Edition 0.1.0

First public edition of the FACET specification. All FACET record and project
schemas declare `schema_version: "0.1"`. The specification edition and product
release versions are independent.

---

_End of specification._
