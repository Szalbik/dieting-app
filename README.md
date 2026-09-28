# AsystentDiety

## Ruby version

See `.ruby-version` / `Gemfile`.

## System dependencies

The default PDF parser (`native_pdf`, see below) needs none of these — OpenAI reads the PDF itself. They matter only for the `markdown_per_day` fallback strategy:

* Python 3 + `pymupdf4llm` — PDF → Markdown conversion (`bin/pdf_to_markdown.py`; also used by `bin/diet_eval_synthetic.py`). Installed in the production image. Install locally with:

  ```bash
  pip3 install pymupdf4llm
  ```

* `poppler-utils` (`pdftotext`, `pdftoppm`) and `tesseract-ocr` (with `pol` + `eng`) — text/OCR tiers of the markdown fallback. **Not** in the production image; without them the fallback silently skips OCR.

## PDF parser configuration

| Env var | Default | Meaning |
|---|---|---|
| `OPENAI_DIET_PARSER_STRATEGY` | `native_pdf` | `native_pdf` (upload PDF to OpenAI, Responses API) or `markdown_per_day` (local markdown extraction + per-day Chat Completions) |
| `OPENAI_DIET_PARSER_MODEL` | `gpt-5.1` | model for every parser call |
| `OPENAI_DIET_PARSER_REASONING` | `none` | `reasoning_effort` for gpt-5.x models (`none` keeps `temperature: 0.2`) |
| `OPENAI_DIET_PARSER_CONCURRENCY` | `4` | per-day calls in flight at once |

Compare settings on the eval corpus with `bin/rails "diet:benchmark[strategies,efforts,models]"`; run the live regression gate with `bundle exec rspec --tag live_openai` before changing a strategy, prompt or schema. See `spec/fixtures/diet_corpus/README.md`.

## Setup

```bash
bin/setup
bin/dev          # starts Puma + esbuild + Tailwind watchers
```

## Tests

```bash
bundle exec rspec
```

## Linting

```bash
bundle exec rubocop
```

## Deployment

Kamal (`config/deploy.yml`); see `Dockerfile` for the production image (installs Python + `pymupdf4llm` only).
