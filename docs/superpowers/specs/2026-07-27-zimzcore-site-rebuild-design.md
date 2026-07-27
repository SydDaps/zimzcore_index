# Zimzcore site rebuild: design

Date: 2026-07-27
Status: approved, ready for implementation planning

## Why

zimzcore.com does not convince anyone to hire Zimzcore. The current page:

- Advertises `0+ Projects Delivered`, `0+ Happy Clients`, `0+ Years Experience`. Literal zeros.
- Describes categories rather than work ("We craft extraordinary digital experiences", "Workflow Digitalization").
- Features two projects, NutriIQ and GrowFastFunding, whose subdomains both return 502.
- Links a WhatsApp number (233203669141) that is not the number enquiries should reach.
- Links to Blog, Case Studies, Careers, Documentation, Privacy Policy and Terms. None exist.
- Lists no real work. Four shipped platforms are invisible.

The goal: a client who lands on this site should want to work with Zimzcore, because the site
shows real systems solving expensive problems.

## Positioning

Zimzcore builds software that solves expensive operational problems, and runs its own products
to prove it.

The dual identity, products for clients and products for ourselves, is the strength. Most firms
pitching a client have never had to keep their own product alive with paying customers. Lokkate
and Live On Forever are that evidence.

The voice comes from Lokkate's own project brief:

> Drivers lie about where they've been. Fuel gets stolen and nobody can prove it. Vehicles are
> used after hours without permission.

Nobody writes that without having spoken to real fleet owners. Every project page should read
like it was written by someone who understands that customer.

### Copy rules

- No em dashes anywhere.
- Plain human sentences. Contractions where they fit. Short sentences over long ones.
- Banned: "cutting-edge", "seamless", "transform your vision", "innovative", "extraordinary",
  "leverage", "solutions" used as a noun on its own.
- Concrete over abstract. Name the actual cost, the actual user, the actual system.
- Every claim must trace to something real in the codebases or the live sites. No invented
  metrics, no invented client counts.
- British spelling, consistent with the existing project docs.

## Scope

### In scope

Six pages: the homepage, the `/work` index, and four project pages. Plus a hand written
stylesheet, self hosted fonts, and screenshots for the projects that have them.

### Out of scope

- Blog, Careers, Documentation, Privacy Policy, Terms. Not written, so not linked.
- Any contact form. There is no backend. WhatsApp and email only.
- NutriIQ and GrowFastFunding. Dropped from the site. Both subdomains currently 502.
- A static site generator. Revisit when adding projects faster than one a month, or when a
  layout change means editing more than about eight files.

## Structure

```
public/
  index.html                    /                       positioning, featured work, capabilities, contact
  work/index.html               /work                   complete index of all projects, compact rows
  work/lokkate.html             /work/lokkate
  work/live-on-forever.html     /work/live-on-forever
  work/kasagandi-ai.html        /work/kasagandi-ai
  work/fellowship-lms.html      /work/fellowship-lms
  _includes/header.html         doctype, head, meta, font preloads, stylesheet, logo, nav
  _includes/footer.html         contact band, copyright, closes the document
  _errors/404.html              existing, keep, restyle only
  assets/stylesheets/main.css   single hand written stylesheet
  assets/fonts/                 self hosted woff2
  assets/images/work/           project screenshots
  up.html                       health check, do not touch
```

### Why this scales past ten projects

The homepage features at most four projects and never grows beyond that. Today that means all
four, since there are only four. At ten projects, which four lead becomes a sales decision,
changed to match whoever is being pitched that quarter, and the homepage stays the same length.
`/work` absorbs the growth as a compact list. Nav never grows either, because it points at
`/work` rather than at individual projects.

Per project pages are hand written from a shared template. At ten projects this is fine, because
the per project prose is the real work and cannot be templated anyway. Moving to a generator
later does not change any URL, only how the HTML is produced.

### Clean URLs

The existing nginx `try_files $uri $uri.html $uri/index.html =404` already serves
`work/lokkate.html` at `/work/lokkate`. No nginx change needed.

### Shared chrome via SSI

Pages include shared partials instead of duplicating markup. `ssi on` is already set in
`config/server.conf`, so no nginx change is required.

**Verified working in the nginx container on 2026-07-27**, and confirmed live on production. The
existing `public/_errors/404.html` renders its partial correctly today: `https://zimzcore.com/nope`
returns a full document with `<title>404: Not Found</title>`, and that title element exists only
inside `_includes/header.html`.

An earlier reading of this spec claimed the existing SSI directives were broken. That was wrong.
Container testing showed all of these forms render correctly, at the site root and in
subdirectories:

```
<!--# include file="/_includes/header.html" -->     works
<!--#include virtual="/_includes/header.html" -->   works
<!--# include virtual="/_includes/header.html" -->  works
```

Neither the space after `#` nor `file=` versus `virtual=` breaks anything here. No fix is needed.

**Follow the existing convention rather than replacing it.** The current partials are a document
skeleton, not fragments:

- `_includes/header.html` opens the document: doctype, `<html>`, `<head>`, `<title>`, `<body>`.
- `_includes/footer.html` closes it: `</body></html>`.
- The page title is passed in with `<!--# set var="title" value="..." -->` at the top of each page
  and read by `<!--# echo var="title" -->` inside the header partial. This mechanism is verified
  working on production.

New pages extend this: the header partial gains the nav and the stylesheet link, the footer gains
the contact band. The separate `_includes/head.html` proposed earlier is not needed, because the
header partial already owns the document head.

Also verified in the container: clean URLs and includes work together (`/work/lokkate` resolves
`work/lokkate.html` and renders its partials), and partials still return 404 on direct request
while rendering internally.

### Underscore paths stay private

The fix deployed on 2026-07-27 (`^/_` rather than `^/_$`, commit 3c08c19) means
`/_includes/header.html` returns 404 to a visitor while SSI still assembles it internally. That
is what `internal` provides. Both halves verified against production.

### No build step

Hand written HTML and one CSS file. `git push` reaches the live site in about ten seconds via the
container's polling loop. Only nginx config changes need `kamal deploy`, and this work needs none.

## Case study template

Seven blocks, identical on every project page.

1. **Name, one line description, status.** Status is one of Live, In development, or Delivered.
   Live entries link out.
2. **The problem.** Two or three short paragraphs. Concrete and costly. This block does the
   persuading, which is why it comes first.
3. **Who it is for.** The real customer segments.
4. **What we built.** The shape of the system in plain language, not a feature list.
5. **Notable engineering.** Three or four specifics a technical buyer respects.
6. **Visual.** Screenshots where they exist. A typographic pull quote of the sharpest problem
   line where they do not. The page must not look broken because an image is missing.
7. **Contact CTA.** Same on every page.

Target length: about 250 words of prose per project. Long enough to prove domain understanding,
short enough to be read fully.

### Status is load bearing

Being straight about what is shipped and what is in flight builds more trust than implying all
four are running, and it protects against a prospect clicking a dead link.

| Project | Status | Links out | Screenshots |
|---|---|---|---|
| Lokkate | Live | lokkate.com (verified 200) | capture from live site |
| Live On Forever | Live | liveonforever.com (verified 200) | capture from live site |
| Kasagandi AI | In development | none, no domain resolves | none, pull quote fallback |
| Fellowship LMS | Delivered for EPL Ghana | none, internal client system | 15 existing, see below |

## Project content sources

- **Lokkate.** `~/workspace/ruby/lokkate/docs/project-brief.md` is the single best source. It has
  the problem statement, four customer segments, three product tiers, and real pricing. Models
  confirm the engineering: positions, trips, immobiliser commands, geofence events, gateway
  transactions, subscriptions, an iOS app. Product of Zim Telematics Ltd, a Zimzcore subsidiary.
- **Live On Forever.** Models: memorials, tributes, condolences, donation requests, payout
  accounts, transactions, events, collections, custom tabs, page views. A digital memorial
  platform with real money movement.
- **Kasagandi AI.** `~/workspace/ruby/kasagandi_ai/docs/MANUAL.md`. A Ghana focused fact checking
  marketplace. Public submits claims, admins triage and assign to accredited fact checkers, who
  research and submit verdicts, which admins approve for publication. Three roles, AASM state
  machine over four claim states, evidence and audit trail.
- **Fellowship LMS.** `~/workspace/ruby/fellowship_management_application/docs/EPL-LMS-Delivery-Summary.md`.
  EPL Ghana Public Service Fellowship. Applications, multi stage vetting and interviews, scoring
  sheets, placements, institutions and supervisors, courses, lessons, quizzes, grading,
  discussions, alumni.

### Screenshot handling

EPL have given permission to publish the Fellowship LMS screenshots and to be named as the client.

Open item for implementation: EPL's permission covers their system, but individual fellows' names,
emails and scores appearing in a screenshot are those individuals' personal data, not EPL's. Each
of the 15 images must be reviewed before publishing, and any showing individual records flagged
for a decision rather than published silently or dropped unilaterally.

Lokkate and Live On Forever screenshots are captured from the live public sites, so no permission
question arises.

## Visual system

Direction: editorial. Light, print like, generous whitespace, serif display, hairline rules,
numbered project index. Chosen over a dark technical treatment and a warm studio treatment.

Rationale: the buyer is deciding whether to trust Zimzcore with an expensive build, and editorial
signals judgement. It also differentiates locally, since most Ghanaian tech company sites are dark
with gradients.

One dark element, decided rather than left open: the contact CTA band at the foot of every page
sits on near black `#0d0d10` with off white text. It closes each page with weight, and gives the
rhythm of the dark direction without changing the editorial character of the page. Everything
else is light.

### Tokens

- Background `#fbfaf8`, text `#17161a`, accent `#6f0697` (brand purple), live status green `#1a7f4b`.
- The current cyan `#00d4ff` is removed. Cyan on dark purple is the single strongest "generated
  template" signal on the existing page.
- Purple is an accent on links, labels and rules. Never a wash, never a gradient.

### Type

- Display serif: Fraunces. Variable, open licence, and its optical size axis gives control at both
  hero and heading sizes.
- Body and UI: Inter Tight.
- Mono: small labels and project numbers only.
- Three roles, no more. Self hosted woff2 in `assets/fonts/`, not called from Google Fonts, which
  is a render blocking third party request on every page load.

### Layout

- Single column, measure capped around 62 characters.
- Whitespace and hairline rules separate content. No boxes, no shadows.
- One breakpoint at 768px. Segment grid drops to one column, type scale steps down.
- Mobile is the priority case. Most Ghanaian clients will open this on a phone.

### Tailwind removed

`cdn.tailwindcss.com` goes. Three reasons: the browser CDN build is not intended for production
and blocks rendering while it compiles; Tailwind's defaults are part of why the current site reads
as generated; and the editorial type scale would be fighting those defaults. One static CSS file
keeps deployment exactly as simple as it is today.

### Accessibility

Real heading hierarchy, alt text on every image, visible focus states, contrast checked to WCAG AA.
The current site fails several of these.

## Contact

- **WhatsApp is primary.** 0557711911, linked as `https://wa.me/233557711911`. This is how business
  gets done in Ghana and it converts better than a form.
- **Email secondary.** `hello@zimzcore.com`, forwarding to dapilah.sydney@gmail.com via Cloudflare
  Email Routing. zimzcore.com currently has no MX records, so this must be set up before the address
  goes on the site. Free, roughly fifteen minutes, and Cloudflare already hosts the DNS.
- The existing `wa.me/233203669141` link is wrong and must be replaced.
- No contact form. No backend to receive one.

## Verification before launch

"It looks fine locally" is how `0+ Happy Clients` reached production. Every item below runs before
the deploy is called done.

1. Build and run in the real nginx container locally. Not a `file://` preview, because SSI only
   resolves through nginx.
2. All six pages return 200, including clean URLs like `/work/lokkate`.
3. `_includes` partials return 404 on direct request while rendering correctly inside pages.
4. Every outbound link resolves. Not theoretical: two current links are 502 and the WhatsApp
   number is wrong.
5. WhatsApp link opens a chat to 0557711911.
6. Renders correctly at 375px and 1440px.
7. `hello@zimzcore.com` receives a real test message before the address goes live.
8. Deploy, then re-run 2 through 6 against zimzcore.com.

## Housekeeping folded into this work

- Delete `public/_old.html`. Dead, and now 404 anyway.
- Restyle `public/_errors/404.html` to match the new design. Its SSI already works, so this is a
  content and styling change only.
- `.superpowers/` is already added to `.gitignore` and `.dockerignore`.
