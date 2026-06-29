# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development server
```bash
bin/dev          # starts Puma + esbuild + Tailwind watchers (Procfile.dev)
```

### Tests
```bash
bundle exec rspec                        # run full suite
bundle exec rspec spec/models/diet_spec.rb  # run a single file
bundle exec rspec spec/models/diet_spec.rb:42  # run a specific line
```

### Linting
```bash
bundle exec rubocop          # lint Ruby
bundle exec rubocop -a       # auto-correct safe offences
```

### Asset build (one-shot, for production or CI)
```bash
yarn build          # esbuild JS → app/assets/builds/
yarn build:css      # Tailwind CSS → app/assets/builds/
```

### Database
```bash
bin/rails db:migrate
bin/rails db:migrate RAILS_ENV=test
bin/rails db:seed
```

### Background jobs (ad-hoc)
```bash
bin/rails runner 'CategorizeProductsJob.perform_later'
bin/rails runner 'TrainCategoryModelJob.perform_later'
```

---

## Architecture

### Domain model hierarchy

The core data model is hierarchical:

```
User
└── Diet           (has_one_attached :pdf)
    └── DietSet    (a "day" within a diet)
        └── Meal
            └── Product   (ingredient line item)
                └── ProductCategory  (ML-assigned category)
```

`DietSetPlan` is a user-selected combination of `DietSet`s (one per day of the week) and drives the shopping workflow. `MealPlan` and `MealPlanProductSubstitution` handle per-plan product swaps. `ShoppingCart` aggregates items from the active `DietSetPlan` and supports collaborative access via `ShoppingCartInvitation`.

### PDF → structured diet pipeline

1. User uploads a PDF to a `Diet` via Active Storage.
2. `Diet#parse_pdf_content_with_chat!` calls `Chat::DietParserService` (OpenAI `gpt-4.1` with a structured JSON schema response). OCR fallback: if `PdfTextExtractor` detects image-based pages (`source: :ocr`), page images are base64-encoded and sent alongside the text.
3. The returned JSON is validated by `DietJsonValidator` against `app/schemas/diet_parser_schema.json` and consolidated by `Chat::DietMealConsolidator`.
4. `PopulateDietFromJsonJob` (background) creates the `DietSet → Meal → Product` tree from the validated JSON.
5. `ClassifyProductsJob` runs the local Naive Bayes classifier (`Classifier::Category`) on each product.

### Product classification (ML)

`Classifier::Category` (`app/services/classifier/category.rb`) is a Naive Bayes classifier backed by `nbayes` gem. The trained model is persisted to `tmp/classifier/category_model.dat` via `Marshal`. Prediction falls back through three strategies in order: exact match on confirmed examples → token-similarity match → Naive Bayes. The model is retrained nightly by `TrainCategoryModelJob`.

### Product substitutions

`ProductSubstitution` records alternative products for any `Product`. The substitution workflow:

- `Chat::SubstitutionExpanderService` (AI) generates synonym/substitute names.
- `ExpandSubstitutionsWithAiJob` runs this in the background.
- `Local::SubstitutionProductMatcherService` or `Chat::SubstitutionProductMatcherService` resolves those names to canonical products.
- `SubstitutionProductMatch` joins a `ProductSubstitution` to a matched `CanonicalProduct`.

### Shopping cart sync

`ShoppingCartSyncService` hydrates the cart from the active `DietSetPlan`. Items from multiple diets are grouped by `ProductCategory`. Soft-deleted items (Paranoia gem) support undo. `SendToTodoistJob` / `CreateTodoistTaskJob` push items to Todoist via `Todoist::Api`.

### Service layer

Service objects live in `app/services/` and are namespaced by concern:

| Namespace | Purpose |
|-----------|---------|
| `Chat::*` | LLM-backed services (OpenAI via `ruby-openai`) |
| `Local::*` | Non-AI local alternatives to Chat:: services |
| `Classifier::*` | Naive Bayes ML classifier |
| `Todoist::*` | Todoist REST API wrapper |
| `*LineParser` / `LineParserfactory` | Legacy regex-based PDF text parsers (superseded by Chat::DietParserService) |

### Authentication

Custom session-based auth — no Devise. `ApplicationController` includes `Concerns::Authentication`. `Current` (ActiveSupport::CurrentAttributes) holds `Current.user` and `Current.session`. Password reset via signed tokens in `PasswordsController`.

---

## Frontend

- **Hotwire**: Turbo Drive for page navigation, Turbo Frames/Streams for partial updates. Stimulus controllers in `app/javascript/controllers/`.
- **Alpine.js**: Lightweight state for components that need more reactivity than Stimulus (loaded alongside Stimulus via `alpine-turbo-drive-adapter`).
- **ViewComponent**: Reusable UI primitives in `app/components/` (`ui/` subdirectory for generic atoms: Button, Card, Badge, Input, SectionHeader).
- **Tailwind CSS v4**: Design tokens defined in `.cursor/rules/dieting_app_design.mdc`. Brand palette is "Peach Skyline" — navy (`brand-navy`) primary CTA/active, peach (`brand-peach*`) accents, sky (`brand-sky*`) info, mint (`brand-mint*`) success, on warm paper (`brand-warm-white`/`brand-paper`) with ink text (`brand-ink*`). Legacy `brand-sage*`/`brand-accent` token names are repointed to this palette so older markup reskins automatically. Nutrition macros keep dedicated semantic colours (`nutrition-protein` red, `nutrition-carbs` amber, `nutrition-fats` purple, `nutrition-fiber` green). Custom shadow scale: `shadow-soft`, `shadow-medium`, `shadow-large`, `shadow-glow`.
- Tailwind class ordering convention: layout → spacing → sizing → typography → backgrounds → borders → effects → transitions → interactive states.

---

## Key configuration

- `config/credentials.yml.enc` — holds `:openai → :api_key` and Todoist OAuth secrets. Access via `Rails.application.credentials.dig(:openai, :api_key)`.
- Multi-database: `config/database.yml` defines `primary`, `queue` (Solid Queue), and `cache` (Solid Cache) SQLite databases.
- Background jobs are monitored at `/jobs` (MissionControl::Jobs, admin-only in production).
- Error tracking: Honeybadger (`config/initializers/honeybadger.rb`).
- Cron schedule: `config/schedule.rb` (Whenever gem) — `CategorizeProductsJob` at midnight, `TrainCategoryModelJob` at 01:00.
- Deployment: Kamal (`config/deploy.yml`).

<!-- BEGIN @przeprogramowani/10x-cli -->

## 10xDevs AI Toolkit — Module 1, Lesson 2

Pick a starter and a stack for the PRD you wrote in Lesson 1, with the **stack chain**:

```
(/10x-init  →  /10x-shape  →  /10x-prd)  →  /10x-tech-stack-selector  →  (bootstrapper)
```

The PRD chain ships from Lesson 1 (re-included in this lesson so you can fix the PRD mid-flight). `/10x-tech-stack-selector` is the lesson's main topic; `/10x-bootstrapper` is the next link, taught in Lesson 3.

### Task Router — Where to start

| Skill | Use it when |
| --- | --- |
| **Stack selection (lesson focus)** | |
| `/10x-tech-stack-selector` | You have a PRD at `context/foundation/prd.md` and need to pick a starter. Opens with an explicit choice (take the recommended default for your `(product_type, language_family)` cell, or design your own), walks the follow-up question set when you design your own, applies four agent-friendly quality gates, reasons over the language-aware starter registry, and writes `context/foundation/tech-stack.md`. Optional `[path-to-prd]` argument lets you point at a non-default PRD location (e.g., `/10x-tech-stack-selector @context/foundation/prd-v2.md`); without it the skill defaults to `context/foundation/prd.md`. Use AFTER `/10x-prd`, BEFORE `/10x-bootstrapper`. |
| **Re-run upstream if needed** | |
| `/10x-init` / `/10x-shape` / `/10x-prd` | Bundled so you can fix the PRD mid-flight. If `/10x-tech-stack-selector` surfaces a gap (e.g., a Functional Requirement that forces a feature your recommended starter doesn't carry), re-run `/10x-prd` to amend the PRD before the stack pick. |

### How the chain hands off

- `/10x-tech-stack-selector` reads `context/foundation/prd.md` frontmatter (`product_type`, `target_scale`, `timeline_budget`) as priors. If the PRD is absent, it refuses with a one-sentence redirect to `/10x-shape` — no inline mini-PRD fallback.
- The skill writes `context/foundation/tech-stack.md` with a 4-key frontmatter (`starter_id`, `package_manager`, `project_name`, `hints`) plus a one-paragraph `## Why this stack` body. The hand-off is intentionally minimal — bootstrapper does not parse rationale, only fields.
- `/10x-bootstrapper` (Lesson 3) reads `tech-stack.md` and the registry to scaffold the project.

### What tech-stack-selector captures (and what it does NOT)

- **Captured**: starter pick (registry-shaped), language family, package manager (open string per ecosystem — `pnpm`, `uv`, `bundle`, `cargo`, etc.), team size, deployment target (drawn from the chosen starter's `deployment_defaults`), CI/CD provider + flow, bootstrapper confidence (`verified | first-class | best-effort`), path taken (standard | custom), self-check answers (custom path), quality override (set when the user proceeds with a starter that failed ≥1 agent-friendly gate), feature flags (auth/payments/realtime/AI/background-jobs).
- **NOT captured (deliberate)**: strategic test plan, strategic deployment plan, strategic implementation decisions. Those are downstream of stack selection — a future technical-roadmap concern, not yet planned. Tech-stack-selector owns *framework-shaped* test/deploy/CI choices because those are inseparable from stack pick; what defers is the *strategic* layer ("we TDD on X surface", "preview environment per PR").

### The opening choice (load-bearing)

The first question is an explicit choice — never silent. The skill names the recommended starter for your `(product_type, language_family)` cell up front and asks for explicit confirmation:

- **Standard path** — accept the recommended default. The skill skips the feature audit, team profile, tech preferences, and framework-variant questions; it asks only the deployment, CI/CD, and project-name questions. The hand-off records `path_taken: standard` under `hints`.
- **Custom path** — design your own. The skill walks the full follow-up set (feature audit, team profile, tech preferences, deployment, CI/CD, framework variant), drills into a testing-runner question only when the chosen starter leaves it ambiguous, and closes with a 5-point readiness self-check (from prework lesson 4.1) before locking in. The hand-off records `path_taken: custom` and populates `self_check_answers`.

The recommended-default-per-cell map is multi-language: web/JS and saas/JS both → 10x-astro-starter (the 10x-branded starter leads whenever it competes in a JS cell); api/JS → hono; api/Python → fastapi; web/Python → django; web/Ruby → rails; api/Go → go; api/Rust → axum; mobile/Dart → flutter; desktop/Rust → tauri; etc. Cells with no vetted default carry `<none>` and force the custom path.

### Quality gates (agent-friendly criteria)

Every starter card carries four booleans the LLM filters against:

1. **Typed** — explicit types/schemas the agent can reason from without running the program.
2. **Convention-based** — strong opinions on layout, routing, configuration.
3. **Popular in training data** — assessed *per language family*, not globally (Django is popular within Python training data; Spring within Java; etc.).
4. **Well-documented** — current, version-pinned, link-able docs.

Candidates failing any gate are excluded from the unprompted recommendation set. If you explicitly name a failing starter as your preference, the skill challenges that pick — surfacing the strongest higher-criteria alternative AND the compensation path (CLAUDE.md instructions that patch the gaps) — and asks you to confirm or pivot. Confirming the known-friction pick records the override on the hand-off so bootstrapper can adjust.

### Bootstrapper confidence

Every recommendation surfaces `bootstrapper_confidence` verbatim — never silently elided:

- **`verified`** — bootstrapper has been run end-to-end on this stack; scaffolding will be smooth.
- **`first-class`** — registered with a valid CLI, expected to work but not battle-tested; expect mostly-smooth scaffolding with occasional manual steps.
- **`best-effort`** — limited support; manual steps likely; expect friction (and bootstrapper's CLAUDE.md generation compensates with extra ecosystem-specific context).

This is the heads-up before running `/10x-bootstrapper` so you know what to expect.

### Foundation paths used by this lesson

- `context/foundation/prd.md` — input (from Lesson 1)
- `context/foundation/tech-stack.md` — output (the chain hand-off)
- `context/foundation/lessons.md` — recurring rules & pitfalls
- `docs/reference/contract-surfaces.md` — load-bearing names registry

### Universal language

The shipped skill carries no 10xDevs / cohort / certification references. The recommended-default registry is multi-language (JS, Python, Ruby, Java, Go, Rust, PHP, .NET, Dart) and the cohort's `10x-astro-starter` is one card in the JS+web cell — not "the" recommended path for everyone.

Skills must not write to `context/archive/`. Archived changes are immutable; if a resolved target path starts with `context/archive/`, abort with: "This change is archived. Open a new change with `/10x-new` instead."

<!-- END @przeprogramowani/10x-cli -->

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
