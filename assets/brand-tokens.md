# TRAKTION brand tokens

Brand: **VASEY/AI** (AI tooling). Keep separate from VASEY.AUDIO per `CLAUDE.md` §10.

## Color

| Token | Hex | Use |
| --- | --- | --- |
| `trak.amber` | `#F59E0B` | Gradient start — badge, accents |
| `trak.ember` | `#EA580C` | Gradient end — badge, accents |
| `trak.mark` | `#FFFFFF` | The T glyph on the badge |
| `trak.wordmark` | `#7D8590` | Wordmark text; legible on light and dark backgrounds |
| `trak.ink` | `#111827` | Body text on light surfaces |
| `trak.paper` | `#F9FAFB` | Light surface |

Badge gradient runs top-left `trak.amber` → bottom-right `trak.ember`.

## Type

System stack for now (no licensed brand face selected):
`ui-sans-serif, system-ui, -apple-system, "Segoe UI", Helvetica, Arial, sans-serif` —
wordmark at weight 800 with wide letter-spacing.

## Source files

- `traktion-icon.svg` — square badge mark (512 grid). Master for any raster/PWA icon
  suite per §10; rasterize preserving transparency.
- `traktion-logo.svg` — horizontal lockup: badge + wordmark (1024×256 grid).
