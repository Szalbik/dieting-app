#!/usr/bin/env python3
"""Render a PDF to per-page Markdown using PyMuPDF4LLM.

Shelled out to by Chat::Diet::MarkdownExtractor, mirroring how the app
already shells out to pdftotext/pdftoppm/tesseract for text/OCR extraction.
Markdown (vs. flattened plain text) preserves table structure, which is how
diet PDFs lay out meals/ingredients/nutrition.

Usage: pdf_to_markdown.py <path-to-pdf>
Prints a JSON array of {"page": <1-based int>, "text": <markdown string>} to stdout.
"""
import json
import sys

import pymupdf4llm


def main():
    if len(sys.argv) != 2:
        print("Usage: pdf_to_markdown.py <path-to-pdf>", file=sys.stderr)
        sys.exit(1)

    chunks = pymupdf4llm.to_markdown(sys.argv[1], page_chunks=True)
    pages = [{"page": index + 1, "text": chunk.get("text", "")} for index, chunk in enumerate(chunks)]
    print(json.dumps(pages))


if __name__ == "__main__":
    main()
