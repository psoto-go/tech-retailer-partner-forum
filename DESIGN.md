# AuraTech Design System (DESIGN.md)

Design system of the **AuraTech — Official Google Hardware Partner** storefront. Upload this file to your own Stitch project (`upload_design_md` → `create_design_system_from_design_md`) so every new screen matches the existing web in `templates/`.

## Brand & Tone
- Minimalist, premium consumer-hardware retail (Google Store–like). Bright, airy, generous whitespace, soft 1px borders, no heavy shadows, no gradients.
- Text wordmark "AuraTech" (primary blue, bold) on the left of the header. No icon badge, no top announcement bar.
- Top navigation (exact order): Store · Fitbit · Wearables · Accessories · Live Role Poll · Support.

## Colors (Material 3 light scheme)
| Token | Hex | Usage |
|---|---|---|
| primary | #005bbf | Primary buttons, links, active nav underline |
| primary-container | #1a73e8 | Accents, hover states |
| on-primary | #ffffff | Text on primary |
| surface / background | #faf9fd | Page background |
| surface-container-low | #f4f3f7 | Cards, hero banner |
| surface-container | #efedf1 | Chips, inputs |
| surface-container-high | #e9e7eb | Pressed/selected surfaces |
| surface-container-highest | #e3e2e6 | Pills |
| on-surface | #1a1b1e | Main text |
| on-surface-variant | #414754 | Secondary text |
| outline | #727785 | Strong borders |
| outline-variant | #c1c6d6 | Card/section borders (1px) |
| secondary | #5b5f64 | Muted UI |
| tertiary | #006d2a | Success / live badges |
| tertiary-container | #16893a | Success accents |
| error | #ba1a1a | Errors |

## Typography
- Headlines / display: **Plus Jakarta Sans** (600–700). Body / labels: **Inter** (400–600).
- display-hero 56–64px/700 (-0.02em) · headline-lg 40/48px/600 · headline-md 28/36px/600 · headline-sm 20/28px/600
- body-lg 18/28px · body-md 15–16/24px · body-sm 13/20px · label-lg 14/20px/600 · label-md 13px/600 · label-sm 12px/500
- Icons: Material Symbols Outlined.

## Shape & Spacing
- Radius: 4px default, 8px (lg), 12px (xl) cards, 16px hero, full (9999px) for buttons and pills.
- Spacing scale: 4 · 8 · 16 · 24 · 40px; page margin 48px desktop / 20px mobile; grid gutter 24px.
- Max content width 1440px, centered.

## Components
- **Buttons:** pill-shaped. Primary = filled #005bbf, white text. Secondary = white/surface with 1px outline-variant border and primary text.
- **Cards:** surface-container-low, 1px outline-variant border, 12px radius, 24px padding; image area on top, category label, title (headline-sm), short description (body-sm), price + "Add to Bag" row separated by a 1px top border.
- **Hero banner:** rounded 16px, surface-container-low, 1px border, text left (pill label, display title, body copy, price + primary button) and product photo right.
- **Pills/badges:** surface-container-highest background, label-sm text; live badges in tertiary green with a pulse dot.
- **Inputs:** 1px outline-variant border, 8px radius, white background, clear focus ring in primary. No placeholder text in demo forms.
- **Footer:** minimal, light, small links.

## Imagery
- Real product photography only for real products (e.g. `static/images/fitbit-air.png` is the official Google Store photo of Google Fitbit Air). Never invent product details.
