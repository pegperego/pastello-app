# Design guidelines

Visual direction: **"paper and crayons"**. The UI is a calm, warm drawing
table; strong colors belong to the drawing, not to the buttons.

Principles: the drawing is the star · big and round · icons, not words ·
obvious state · playful, not noisy.

The original proposal (in Italian) is in
[`analisi/risorse/design/`](../../analisi/risorse/design/).

## UI color tokens

| Token | Value | Usage |
|---|---|---|
| `paper` | `#FFF8EE` | App background |
| `sheet` | `#FFFFFF` | Drawing area |
| `ink` | `#2D2A32` | Text, icon outlines |
| `graphite` | `#6B6672` | Secondary text |
| `border` | `#EADFCF` | Dividers |
| `coral` | `#E8553A` | Primary: "+" button, active tool |
| `sun` | `#FFC53D` | Accent, toggles on |
| `sky` | `#2C7BE5` | Selection, handles |
| `mint` | `#1E9E85` | Confirm |
| `raspberry` | `#D93D42` | Delete |

Light theme only in v1.

## Drawing palette

Fixed colors: red `#E63946` · orange `#FF8C42` · yellow `#FFD23F` ·
light green `#8BD346` · dark green `#2A9D3F` · light blue `#4CC9F0` ·
blue `#1D4ED8` · purple `#8E44AD` · pink `#FF7EB6` · brown `#8B5A2B` ·
black `#1F1F1F` · white `#FFFFFF`.

A "more colors" grid adds 40 presets (skin tones, pastels, darks, greys and
vivid colors).

## Typography

- **Fredoka** for titles and buttons, **Andika** for body text.
- Text on drawings can also use **Playwrite IT Moderna** and **Comic Neue**.
- All fonts are SIL OFL 1.1 and bundled with the app.

## App icon

A smiling crayon on a light blue sky with sun and grass. It is also the app's
mascot. Delivered as an Android adaptive icon (foreground and background
layers, subject inside the safe zone) plus a monochrome layer for themed
icons.

## Icons

- **Tools** are small colored illustrations with an `ink` outline; the tip
  takes the currently selected color.
- **Actions** use a thick, rounded stroke.
- All icons are hand-made SVGs; no icon library is used.

## Motion and accessibility

- Animations are short (150–300 ms) and never block input; Android's
  "remove animations" setting is respected.
- Contrast: `ink` on `paper` 13.4:1, `graphite` on `paper` 5.3:1 (WCAG AA).
  White on `coral` (3.6:1) is only used for icons and large text (≥ 24 px).
- Touch targets ≥ 56 dp (tools 64 dp). Active state is never shown by color
  alone. Every button has a screen reader label.
