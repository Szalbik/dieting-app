#!/usr/bin/env python3
"""Generate synthetic diet PDFs in layouts the repo fixtures don't cover.

Each layout is built from known data, so its golden.json is exact by
construction (no manual correction). Real dietitian PDFs remain the gold
standard; this "layout zoo" checks the parser generalises beyond the one
"Zestaw N" table layout of spec/fixtures/files/*.pdf.

Usage: bin/diet_eval_synthetic.py [corpus_dir]   (default spec/fixtures/diet_corpus)
Writes <corpus_dir>/synth-<layout>/{diet.pdf,golden.json}. PDFs are gitignored
(regenerate with this script); goldens are committed.

Font: needs a TTF with Polish glyphs. DIET_EVAL_FONT=/path/to/font.ttf
overrides the macOS Arial default (Linux: DejaVuSans.ttf).
"""
import json
import os
import sys

import pymupdf

FONT = os.environ.get("DIET_EVAL_FONT", "/System/Library/Fonts/Supplemental/Arial.ttf")
FONT_BOLD = os.environ.get("DIET_EVAL_FONT_BOLD", FONT.replace("Arial.ttf", "Arial Bold.ttf"))
if not os.path.exists(FONT_BOLD):
    FONT_BOLD = FONT

# (type, label, name, [(product, quantity)], kcal)
WEEK = [
    [
        ("breakfast", "Śniadanie", "Owsianka z bananem", [("płatki owsiane", "50 g"), ("mleko 2%", "200 ml"), ("banan", "1 szt. (120 g)"), ("cynamon", "szczypta")], 390),
        ("lunch", "Obiad", "Kurczak z ryżem i brokułem", [("pierś z kurczaka", "150 g"), ("ryż basmati", "60 g"), ("brokuł", "150 g"), ("oliwa z oliwek", "10 ml")], 610),
        ("afternoon_snack", "Podwieczorek", "Jogurt z orzechami", [("jogurt naturalny", "150 g"), ("orzechy włoskie", "15 g")], 190),
        ("dinner", "Kolacja", "Kanapki z twarożkiem", [("chleb żytni razowy", "2 kromki (70 g)"), ("twarożek półtłusty", "100 g"), ("rzodkiewki", "4 szt."), ("szczypiorek", "1 łyżka")], 360),
    ],
    [
        ("breakfast", "Śniadanie", "Jajecznica ze szczypiorkiem", [("jajka", "3 szt."), ("masło", "5 g"), ("szczypiorek", "1 łyżka"), ("pomidor", "1 szt.")], 340),
        ("lunch", "Obiad", "Łosoś z ziemniakami", [("łosoś", "120 g"), ("ziemniaki", "200 g"), ("koperek", "1 łyżka"), ("fasolka szparagowa", "150 g")], 590),
        ("afternoon_snack", "Podwieczorek", "Jabłko z masłem orzechowym", [("jabłko", "1 szt."), ("masło orzechowe", "15 g")], 180),
        ("dinner", "Kolacja", "Sałatka grecka", [("pomidor", "1 szt."), ("ogórek", "1 szt."), ("ser feta", "50 g"), ("oliwki czarne", "30 g"), ("oliwa z oliwek", "10 ml")], 380),
    ],
    [
        ("breakfast", "Śniadanie", "Jogurt z musli i borówkami", [("jogurt naturalny", "150 g"), ("musli bez cukru", "40 g"), ("borówki", "80 g")], 350),
        ("lunch", "Obiad", "Makaron z indykiem w sosie pomidorowym", [("makaron pełnoziarnisty", "70 g"), ("mięso z piersi indyka", "120 g"), ("passata pomidorowa", "150 g"), ("czosnek", "1 ząbek"), ("bazylia", "szczypta")], 620),
        ("afternoon_snack", "Podwieczorek", "Marchewki z hummusem", [("marchew", "1 szt."), ("hummus", "50 g")], 170),
        ("dinner", "Kolacja", "Omlet ze szpinakiem", [("jajka", "2 szt."), ("szpinak", "50 g"), ("ser żółty", "20 g"), ("olej rzepakowy", "5 ml")], 330),
    ],
]

WEEKDAYS = ["Poniedziałek", "Wtorek", "Środa"]

ENGLISH = [
    [
        ("breakfast", "Breakfast", "Scrambled eggs on toast", [("eggs", "2"), ("wholemeal bread", "2 slices"), ("butter", "5 g"), ("cherry tomatoes", "100 g")], 420),
        ("lunch", "Lunch", "Chicken quinoa bowl", [("chicken breast", "140 g"), ("quinoa", "60 g"), ("avocado", "1/2"), ("spinach", "40 g"), ("lemon juice", "1 tbsp")], 640),
        ("dinner", "Dinner", "Baked cod with sweet potato", [("cod fillet", "150 g"), ("sweet potato", "200 g"), ("green peas", "80 g"), ("olive oil", "10 ml")], 520),
    ],
    [
        ("breakfast", "Breakfast", "Overnight oats", [("rolled oats", "50 g"), ("almond milk", "200 ml"), ("chia seeds", "10 g"), ("strawberries", "100 g")], 360),
        ("lunch", "Lunch", "Turkey wrap", [("wholemeal tortilla", "1"), ("turkey breast slices", "80 g"), ("lettuce", "30 g"), ("hummus", "30 g"), ("cucumber", "1/2")], 480),
        ("dinner", "Dinner", "Beef stir-fry with rice", [("lean beef", "130 g"), ("brown rice", "60 g"), ("bell pepper", "1"), ("broccoli", "100 g"), ("soy sauce", "1 tbsp")], 610),
    ],
]


def golden(days, scanned=False, kcal_printed=True, day_numbers=None):
    return {
        "pdf": "diet.pdf",
        "scanned": scanned,
        "meals_per_day": None,
        "days": [
            {
                "day": (day_numbers[i] if day_numbers else i + 1),
                "meals": [
                    {"type": t, "name": name, "ingredients": [p for p, _ in ings], "kcal": (kcal if kcal_printed else None)}
                    for (t, _label, name, ings, kcal) in meals
                ],
            }
            for i, meals in enumerate(days)
        ],
    }


class Writer:
    """Minimal top-to-bottom text flow with page breaks."""

    def __init__(self, doc):
        self.doc = doc
        self.new_page()

    def new_page(self):
        self.page = self.doc.new_page()
        self.page.insert_font(fontname="F", fontfile=FONT)
        self.page.insert_font(fontname="FB", fontfile=FONT_BOLD)
        self.y = 60

    def line(self, text, size=11, bold=False, indent=0, gap=4):
        if self.y > 780:
            self.new_page()
        self.page.insert_text((56 + indent, self.y), text, fontsize=size, fontname="FB" if bold else "F")
        self.y += size + gap


def flow_pdf(path, headings, days, kcal_printed=True, footer=None):
    doc = pymupdf.open()
    w = Writer(doc)
    for index, (heading, meals) in enumerate(zip(headings, days)):
        if index:
            w.new_page()
        w.line(heading, size=20, bold=True, gap=14)
        for (_t, label, name, ings, kcal) in meals:
            title = f"{label}: {name}" + (f" ({kcal} kcal)" if kcal_printed else "")
            w.line(title, size=13, bold=True, gap=6)
            for product, qty in ings:
                w.line(f"• {product} – {qty}", indent=14)
            w.y += 10
        if footer:
            w.y = max(w.y, 800)
            w.line(footer, size=8)
    doc.save(path)


def grid_pdf(path, days):
    """Days as columns, meals as rows — one landscape page, no day headings in text flow."""
    doc = pymupdf.open()
    page = doc.new_page(width=842, height=595)
    page.insert_font(fontname="F", fontfile=FONT)
    page.insert_font(fontname="FB", fontfile=FONT_BOLD)
    page.insert_text((40, 40), "Jadłospis tygodniowy – 3 dni", fontsize=16, fontname="FB")
    left, top, label_w = 40, 60, 90
    col_w = (842 - 2 * left - label_w) / len(days)
    rows = len(days[0])
    row_h = (595 - top - 40 - 24) / rows
    for d in range(len(days)):
        x = left + label_w + d * col_w
        page.draw_rect(pymupdf.Rect(x, top, x + col_w, top + 24), color=(0, 0, 0), width=0.6)
        page.insert_text((x + 6, top + 16), f"Dzień {d + 1}", fontsize=11, fontname="FB")
    for r in range(rows):
        y = top + 24 + r * row_h
        page.draw_rect(pymupdf.Rect(left, y, left + label_w, y + row_h), color=(0, 0, 0), width=0.6)
        page.insert_textbox(pymupdf.Rect(left + 4, y + 4, left + label_w - 4, y + row_h), days[0][r][1], fontsize=10, fontname="FB")
        for d, meals in enumerate(days):
            _t, _label, name, ings, kcal = meals[r]
            x = left + label_w + d * col_w
            rect = pymupdf.Rect(x, y, x + col_w, y + row_h)
            page.draw_rect(rect, color=(0, 0, 0), width=0.6)
            body = f"{name} – {kcal} kcal\n" + "\n".join(f"{p} {q}" for p, q in ings)
            page.insert_textbox(rect + (4, 4, -4, -2), body, fontsize=7.5, fontname="F")
    doc.save(path)


def scanned_pdf(path, source_path):
    """Rasterise a text PDF into image-only pages (what a phone scan looks like to the parser)."""
    src = pymupdf.open(source_path)
    out = pymupdf.open()
    for page in src:
        pix = page.get_pixmap(dpi=110, colorspace=pymupdf.csGRAY)
        img_page = out.new_page(width=page.rect.width, height=page.rect.height)
        img_page.insert_image(img_page.rect, stream=pix.tobytes("jpeg", jpg_quality=70))
    out.save(path)


def write(corpus, slug, build, gold):
    folder = os.path.join(corpus, slug)
    os.makedirs(folder, exist_ok=True)
    build(os.path.join(folder, "diet.pdf"))
    with open(os.path.join(folder, "golden.json"), "w", encoding="utf-8") as f:
        json.dump(gold, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"wrote {folder}")


def main():
    corpus = sys.argv[1] if len(sys.argv) > 1 else "spec/fixtures/diet_corpus"
    footer = "Gabinet Dietetyczny Przykład | tel. 000-000-000 | www.example.com"

    write(corpus, "synth-weekday", lambda p: flow_pdf(p, WEEKDAYS, WEEK, footer=footer), golden(WEEK))
    write(corpus, "synth-single-day", lambda p: flow_pdf(p, ["Jadłospis na 1 dzień"], WEEK[:1]), golden(WEEK[:1]))
    write(corpus, "synth-grid", lambda p: grid_pdf(p, WEEK), golden(WEEK))
    write(corpus, "synth-no-kcal-dzien", lambda p: flow_pdf(p, [f"Dzień {i + 1}" for i in range(3)], WEEK, kcal_printed=False),
          golden(WEEK, kcal_printed=False))
    write(corpus, "synth-english", lambda p: flow_pdf(p, ["Day 1", "Day 2"], ENGLISH), golden(ENGLISH))

    weekday_pdf = os.path.join(corpus, "synth-weekday", "diet.pdf")
    write(corpus, "synth-scanned", lambda p: scanned_pdf(p, weekday_pdf), golden(WEEK, scanned=True))


if __name__ == "__main__":
    main()
