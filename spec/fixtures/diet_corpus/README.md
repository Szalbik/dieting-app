# PDF parser eval corpus

One folder per diet PDF:

```
spec/fixtures/diet_corpus/<slug>/
  diet.pdf       # the real PDF — gitignored (patient/dietitian personal data)
  golden.json    # hand-checked expected output — committed
```

`golden.json`:

```json
{
  "pdf": "diet.pdf",
  "scanned": false,
  "meals_per_day": null,
  "days": [
    { "day": 1, "meals": [
      { "type": "breakfast", "name": "Owsianka", "ingredients": ["płatki owsiane", "mleko 2%"], "kcal": 412 }
    ] }
  ]
}
```

- `pdf` is relative to the folder (repo fixtures point at `../../files/…`).
- `ingredients` are names only; matching ignores case, diacritics and extra words.
- `kcal` is `null` when the PDF gives none for that meal (not scored).
- `meals_per_day` is passed to the parser like the upload form's hint (`null` = no hint).
- `scanned: true` marks image-only PDFs.

Minimum useful corpus: **≥ 6 entries, ≥ 2 different dietitians/layouts, ≥ 1 scanned PDF.**

## Synthetic layouts (`synth-*`)

`bin/diet_eval_synthetic.py` generates six PDFs whose goldens are exact by construction —
weekday headings, a single-day plan, a days-as-columns grid, "Dzień N" without kcal,
English, and an image-only scan. They test that the parser generalises beyond the one
"Zestaw N" layout of the repo fixtures; they do **not** replace real dietitian PDFs.
The PDFs are gitignored; regenerate them with the script (needs a TTF with Polish
glyphs — `DIET_EVAL_FONT=/path/to/DejaVuSans.ttf` on Linux).

Adding an entry:

1. `mkdir spec/fixtures/diet_corpus/<slug>` and copy the PDF in as `diet.pdf`.
2. `bin/rails "diet:golden:draft[<slug>]"` → writes `golden.draft.json` from the current parser.
3. Open the PDF side by side, fix every day/meal/ingredient/kcal, save as `golden.json`.

Then `bin/rails diet:benchmark` scores the current config; see `lib/tasks/diet_eval.rake` for the matrix form.
