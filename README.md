# AsystentDiety

## Ruby version

See `.ruby-version` / `Gemfile`.

## System dependencies

* `poppler-utils` (`pdftotext`, `pdftoppm`) and `tesseract-ocr` (with `pol` + `eng` language data) — PDF text extraction and OCR fallback.
* Python 3 + `pymupdf4llm` — PDF → Markdown conversion for diet parsing (`bin/pdf_to_markdown.py`). Install with:

  ```bash
  pip3 install pymupdf4llm
  ```

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

Kamal (`config/deploy.yml`); see `Dockerfile` for the production image (installs the system dependencies above).
