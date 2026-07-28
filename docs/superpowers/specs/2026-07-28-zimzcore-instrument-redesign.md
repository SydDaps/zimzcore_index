# Zimzcore redesign: Instrument

Date: 2026-07-28
Status: approved from mobile mockups, ready for implementation
Supersedes the visual layer of `2026-07-27-zimzcore-site-rebuild-design.md`

## Why a second pass

The editorial direction shipped on 2026-07-27 and the user rejected it: "on mobile this is trash",
"we need a whole new look". Two process failures caused it:

1. **Every mockup was judged on desktop.** The user judges on a phone, and the audience is mostly
   on phones. Desktop-first mockups produced a design that did not survive contact with mobile.
2. **A signal was noted and ignored.** In the original direction test the user clicked the dark,
   dense option four times before selecting the light editorial one. That hesitation was recorded
   and not acted on.

Both are corrected here. Every mockup for this pass was drawn at 320px inside a phone frame, and
the direction was chosen from those frames.

## What carries over unchanged

- **Information architecture.** Six pages: `/`, `/work`, and four case studies at
  `/work/lokkate`, `/work/live-on-forever`, `/work/kasagandi-ai`, `/work/fellowship-lms`.
- **All body copy.** The user objected to the look, not the words. The Lokkate-brief voice stays.
- **Copy rules.** No em dashes, plain sentences, British spelling, no invented metrics, every
  claim traceable to real work.
- **The contract suite** at `test/site_test.sh`. It must stay green throughout. It has caught six
  real defects and is the only automated guard on this site.
- **SSI partials** in `public/_includes/`, the `set`/`echo` title mechanism, clean URLs via
  `try_files`, and the no build step deploy model.
- **Contact.** WhatsApp `wa.me/233557711911` primary, `hello@zimzcore.com` secondary. The user has
  twice confirmed keeping the email despite the domain having no MX records.

## What changes

Everything visual: typefaces, colour tokens, layout language, header, section structure, and the
contact band. `public/assets/stylesheets/main.css` is replaced rather than edited.

## The direction: Instrument, restrained

A structured, bordered, corporate layout for a hard engineering company. Energy comes from
precision, not decoration.

### Explicitly rejected as gimmickry

The first version of this direction was shown with pulsing status dots, a sweeping purple
underline, an engineering grid behind the hero, a mono button with an arrow, a staggered load
animation, and boxed spec chips. The user's verdict was "less gimmicky" and it was correct. All
six are removed and must not be reintroduced.

The test: **decoration that imitates information is banned.** A dot that blinks does not mean
anything is being monitored. A grid behind a headline does not make the work more technical.
Tabular numerals stay because they are figures. Mono labels stay because they are metadata.
Hairline rules stay because they separate things.

### No animation at all

No load animation, no scroll animation, no hover motion beyond a colour change. This is a
deliberate constraint, not an omission.

## Type

- **IBM Plex Sans** for everything structural: headings, body, navigation, buttons.
- **IBM Plex Mono** for micro labels only: section numbers, status labels, stat captions, the
  spec lines, the hero kicker.

Chosen because it was drawn for an engineering company, has a genuine mono sibling that shares its
skeleton, and is not the typeface every agency site reaches for.

Self hosted woff2 in `public/assets/fonts/`, latin subset only, same as the current setup. The
existing Fraunces, Inter Tight and JetBrains Mono files are removed once nothing references them.

Weights needed: Sans 400, 500, 600. Mono 400, 500. These are static fonts, not variable, so expect
one file per weight. Unlike Fraunces there is no default-weight trap.

## Colour

| Token | Value | Use |
|---|---|---|
| `--bg` | `#ffffff` | Page background. Pure white, not the off white of the editorial version. |
| `--ink` | `#0e0e13` | Headings and body |
| `--ink-2` | `#55556a` | Secondary prose |
| `--ink-3` | `#8a8a9c` | Mono captions, tertiary |
| `--rule` | `#e8e8ef` | Every hairline |
| `--accent` | `#6f0697` | Brand purple. Section numbers, the hero kicker, links. |
| `--live` | `#1a7f4b` | The Live status label only |
| `--btn` | `#0e0e13` | Primary button fill, with white text |

Purple is a label colour, never a fill and never a wash. No gradients, no shadows, no tinted
panels.

## Layout language

- **Header.** Icon mark left, three text links right (Work, Services, Contact), hairline
  underneath. Single row at every width, which the icon mark makes possible.
- **Hero.** Mono kicker, then the h1, then a sub paragraph, then one dark button. Bordered below.
- **Stat strip.** Three cells divided by vertical hairlines, directly under the hero. Mono figures
  with tabular numerals over mono uppercase captions. Real figures only: 04 platforms,
  02 in production, 01 client built.
- **Sections.** A head of `01` in mono purple beside an h2, then a list of items separated by
  hairlines, top and bottom rules included.
- **Items.** Title left, optional status right, description below, optional mono spec line under
  that. This one pattern serves both the capabilities list and the work list.
- **Case studies.** Same item language for the audience segments and the engineering list. Pull
  quote retained. Case top keeps the number and the status with a link out where one exists.
- **Contact band.** Dark `#0e0e13` at the foot of every page, white text, WhatsApp and email.
- **404.** Same chrome, mono `404` kicker, one heading, two links.

## Mobile is the design surface

Approved from 320px phone frames. Non negotiable properties:

- Header stays one row at 320px.
- No horizontal overflow at 320, 375, 390 or 768. Verified by measuring `scrollWidth`, not by eye.
- Body text no smaller than 12.5px, prose line height at least 1.55.
- Tap targets at least 40px tall.

### How to verify mobile, because this was got wrong once

**Never use `--window-size` below 500px.** Headless Chrome on macOS clamps the window to a 500px
minimum and writes a cropped screenshot, which looks like broken layout and is not. That produced
a false bug report on 2026-07-27.

Use the CDP driver at `.superpowers/brainstorm/*/cdp.mjs`, which sets a true viewport via
`Emulation.setDeviceMetricsOverride` and prints `scrollWidth`, `clientWidth` and any overflowing
elements alongside the screenshot.

## Verification

1. `test/site_test.sh` green locally, currently 121 assertions.
2. `scrollWidth == clientWidth` at 320, 375, 390, 768 and 1440 on all six pages.
3. Every page screenshotted at 390px and **looked at**, not merely measured.
4. Contrast checked to WCAG AA on the new tokens.
5. One `h1` per page, alt text on the mark, visible focus states.
6. The user sees real pages on a phone **before** deploy. The previous cycle deployed first and
   asked afterwards.

## Out of scope

- Product screenshots. Still none usable. The layout must not depend on them.
- The `/work` row density and `.seg` contrast refinements noted on the editorial version. Both are
  superseded by this redesign.
- `www.zimzcore.com` returning 526, and the silent failure in `serve`. Both still open, both
  tracked separately.
