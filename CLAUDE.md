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
- **Tailwind CSS v4**: Design tokens defined in `.cursor/rules/dieting_app_design.mdc`. Brand colour is emerald; nutrition macros use dedicated semantic colours (`nutrition-protein` red, `nutrition-carbs` amber, `nutrition-fats` purple, `nutrition-fiber` green). Custom shadow scale: `shadow-soft`, `shadow-medium`, `shadow-large`, `shadow-glow`.
- Tailwind class ordering convention: layout → spacing → sizing → typography → backgrounds → borders → effects → transitions → interactive states.

---

## Key configuration

- `config/credentials.yml.enc` — holds `:openai → :api_key` and Todoist OAuth secrets. Access via `Rails.application.credentials.dig(:openai, :api_key)`.
- Multi-database: `config/database.yml` defines `primary`, `queue` (Solid Queue), and `cache` (Solid Cache) SQLite databases.
- Background jobs are monitored at `/jobs` (MissionControl::Jobs, admin-only in production).
- Error tracking: Honeybadger (`config/initializers/honeybadger.rb`).
- Cron schedule: `config/schedule.rb` (Whenever gem) — `CategorizeProductsJob` at midnight, `TrainCategoryModelJob` at 01:00.
- Deployment: Kamal (`config/deploy.yml`).
