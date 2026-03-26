# DietApp Design System

## Foundations

- **Typography**
  - `font-sans`: `DM Sans`
  - `font-serif`: `Playfair Display`
- **Core brand colors**
  - `brand-sage`: primary action accent
  - `brand-sage-dark`: primary CTA background
  - `brand-accent`: highlight and conversion accents
  - `brand-cream` / `brand-warm-white`: surfaces and page backgrounds
  - `brand-charcoal` / `brand-soft-gray`: text hierarchy

## Components

- `Ui::ButtonComponent`
  - Variants: `primary`, `secondary`, `ghost`, `danger`
  - Sizes: `sm`, `md`, `lg`
  - Supports links (`href`) and regular button element (`type`)
- `Ui::CardComponent`
  - Surface wrapper for sections and cards
  - Padding variants: `sm`, `md`, `lg`
- `Ui::InputComponent`
  - Label + field wrapper with `hint` or `error`
  - Pair with `app-input` class for consistent inputs
- `Ui::BadgeComponent`
  - Variants: `neutral`, `success`, `accent`
- `Ui::SectionHeaderComponent`
  - Standardized section intro (`label`, `title`, `subtitle`)

## Utility classes

- `app-shell`: page-width wrapper
- `app-section`: generic section container
- `app-label`: standard field label
- `app-input`: standard text input style

## Usage rules

- Prefer ViewComponents over inline utility duplication.
- Use semantic brand tokens (`brand-*`) instead of raw hardcoded colors for new UI.
- Keep CTA hierarchy consistent:
  - Primary action: `brand-sage-dark`
  - Secondary action: outline/neutral
  - Destructive action: danger variant

## Preview

- Live preview page: `/style-guide`
- Source: `app/views/main/style_guide.html.erb`

## Phase 2 Recolor Checklist

- Migrate remaining legacy views in `app/views/products/**`.
- Migrate remaining legacy views in `app/views/product_categories/**`.
- Normalize flash/banner colors in shared partials and admin paths.
- Replace hardcoded `emerald/gray` color classes with `brand-*` tokens where possible.
- Keep new UI changes aligned with landing palette before adding new colors.
