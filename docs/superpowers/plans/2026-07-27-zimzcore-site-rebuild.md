# Zimzcore Site Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild zimzcore.com as a six page editorial static site that shows four real shipped platforms and makes a client want to hire Zimzcore.

**Architecture:** Hand written static HTML served by nginx from `public/`. Shared chrome via nginx SSI partials in `public/_includes/` (verified working). Clean URLs come free from the existing `try_files $uri $uri.html`. One hand written stylesheet, self hosted fonts, no build step, no JavaScript framework. A shell based HTTP test suite runs against the real nginx container and is written before the pages it checks.

**Tech Stack:** nginx SSI, plain HTML5, hand written CSS (custom properties, flexbox, grid), self hosted woff2 fonts, Docker for local verification, Kamal for deploy.

**Spec:** `docs/superpowers/specs/2026-07-27-zimzcore-site-rebuild-design.md`

---

## Testing approach, read this first

This is a static site, so there is no unit test framework. The equivalent of TDD here is an
**HTTP contract test suite** that runs against the real nginx container. It is written first, it
fails first, and it is what "done" means.

This matters because the current site shipped `0+ Happy Clients` and two links to 502 pages to
production. Those are exactly the failures an HTTP suite catches.

The suite lives at `test/site_test.sh` and asserts:

- every page returns 200, including clean URLs
- SSI partials assembled (page HTML contains markers only present in the partials)
- partials return 404 on direct request
- no page contains banned copy (`0+`, `cutting-edge`, em dashes, and so on)
- every outbound link resolves
- the WhatsApp number is the correct one

**Never use `cat` or heredocs to create site files.** Use the Write tool. Heredocs dump large
HTML into the terminal and mangle quoting.

---

## File Structure

| File | Responsibility |
|---|---|
| `test/site_test.sh` | HTTP contract suite, run against a local container or production |
| `test/run_local.sh` | Boot the nginx container with the working tree mounted, on port 8099 |
| `public/_includes/header.html` | Document open: doctype, head, meta, fonts, stylesheet, logo, nav |
| `public/_includes/footer.html` | Contact band, copyright, closes document |
| `public/assets/stylesheets/main.css` | The entire visual system, single stylesheet |
| `public/assets/fonts/*.woff2` | Self hosted Fraunces and Inter Tight |
| `public/index.html` | Homepage: hero, four featured projects, capabilities |
| `public/work/index.html` | Complete work index |
| `public/work/lokkate.html` | Case study |
| `public/work/live-on-forever.html` | Case study |
| `public/work/kasagandi-ai.html` | Case study |
| `public/work/fellowship-lms.html` | Case study |
| `public/_errors/404.html` | Restyled to match |

Each case study page is self contained content using shared chrome and shared CSS classes. No
page owns styling; all styling lives in `main.css`.

---

## Task 1: Local container runner and failing test suite

**Files:**
- Create: `test/run_local.sh`
- Create: `test/site_test.sh`

- [ ] **Step 1: Write the container runner**

Create `test/run_local.sh`:

```bash
#!/bin/bash
# Boot the site in the real nginx image with the working tree mounted.
# Usage: test/run_local.sh [start|stop]
set -e

NAME=zimzcore_local
PORT=8099
IMAGE=syddaps/zimzcore_index:latest
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

case "${1:-start}" in
  start)
    docker rm -f "$NAME" >/dev/null 2>&1 || true
    docker run -d --name "$NAME" --platform linux/amd64 \
      -p "$PORT":80 -v "$ROOT":/site "$IMAGE" >/dev/null
    # Wait for nginx to answer rather than sleeping a fixed amount.
    for i in $(seq 1 30); do
      if curl -sS -o /dev/null "http://localhost:$PORT/up.html" 2>/dev/null; then
        echo "up on http://localhost:$PORT"; exit 0
      fi
      sleep 0.5
    done
    echo "container did not come up"; docker logs "$NAME" 2>&1 | tail -20; exit 1
    ;;
  stop)
    docker rm -f "$NAME" >/dev/null 2>&1 || true
    echo "stopped"
    ;;
esac
```

Then: `chmod +x test/run_local.sh`

Note the `-v "$ROOT":/site` mount replaces the whole `/site` directory, so the `serve` script at
the repo root is what the container runs. This is why the mount is the repo root and not
`public/`.

- [ ] **Step 2: Write the failing test suite**

Create `test/site_test.sh`:

```bash
#!/bin/bash
# HTTP contract suite. Runs against a base URL, defaulting to the local container.
# Usage: test/site_test.sh [base_url]
BASE="${1:-http://localhost:8099}"
PASS=0; FAIL=0

ok()   { printf "  ok    %s\n" "$1"; PASS=$((PASS+1)); }
bad()  { printf "  FAIL  %s\n" "$1"; FAIL=$((FAIL+1)); }

status() { curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "$1" 2>/dev/null; }
body()   { curl -sS --max-time 10 "$1" 2>/dev/null; }

expect_status() {
  local path="$1" want="$2" got
  got="$(status "$BASE$path")"
  [ "$got" = "$want" ] && ok "$path -> $want" || bad "$path -> got $got, want $want"
}

expect_contains() {
  local path="$1" needle="$2"
  if body "$BASE$path" | grep -qF -- "$needle"; then
    ok "$path contains '$needle'"
  else
    bad "$path missing '$needle'"
  fi
}

expect_absent() {
  local path="$1" needle="$2"
  if body "$BASE$path" | grep -qF -- "$needle"; then
    bad "$path still contains '$needle'"
  else
    ok "$path free of '$needle'"
  fi
}

PAGES="/ /work /work/lokkate /work/live-on-forever /work/kasagandi-ai /work/fellowship-lms"

echo "== pages return 200 =="
for p in $PAGES; do expect_status "$p" 200; done
expect_status "/up.html" 200

echo "== SSI partials assemble =="
# data-chrome="header" and data-chrome="footer" are markers that exist ONLY in the partials.
for p in $PAGES; do
  expect_contains "$p" 'data-chrome="header"'
  expect_contains "$p" 'data-chrome="footer"'
done

echo "== partials are not directly reachable =="
expect_status "/_includes/header.html" 404
expect_status "/_includes/footer.html" 404
expect_status "/_old.html" 404

echo "== banned copy is gone =="
for p in $PAGES; do
  expect_absent "$p" '>0+<'
  expect_absent "$p" 'cutting-edge'
  expect_absent "$p" 'seamless'
  expect_absent "$p" 'transform your vision'
  expect_absent "$p" 'innovative'
  expect_absent "$p" 'leverage'
  expect_absent "$p" 'cutting edge'
  expect_absent "$p" 'cdn.tailwindcss.com'
  expect_absent "$p" '—'
  expect_absent "$p" '233203669141'
  expect_absent "$p" 'nutriiq.zimzcore.com'
  expect_absent "$p" 'growfastfunding.zimzcore.com'
done

echo "== contact details correct =="
expect_contains "/" 'wa.me/233557711911'

echo "== outbound links resolve =="
for url in https://lokkate.com https://liveonforever.com; do
  got="$(status "$url")"
  [ "$got" = "200" ] && ok "$url -> 200" || bad "$url -> got $got"
done

echo
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" -eq 0 ]
```

Then: `chmod +x test/site_test.sh`

- [ ] **Step 3: Run the suite and verify it fails**

```bash
test/run_local.sh start
test/site_test.sh
```

Expected: many FAIL lines. `/work` and all four case studies 404 because they do not exist. The
`data-chrome` markers are missing. Banned copy checks fail on `/` because the current homepage
contains `>0+<`, `cdn.tailwindcss.com`, `233203669141` and the two 502 subdomains. This failing
output is the specification.

The needle is `>0+<` rather than `0+ `, because the stat markup renders as
`<div data-target="100">0+</div>` with no trailing space. A bare `0+` would false-positive on
`100+`. This was found by running the suite rather than by reading it.

- [ ] **Step 4: Commit**

```bash
git add test/
git commit -m "Add HTTP contract suite for the site rebuild

Runs against the real nginx container. Asserts pages resolve, SSI
partials assemble, partials stay private, banned copy is absent and
outbound links work. Fails against the current site by design."
```

---

## Task 2: Self host the fonts

**Files:**
- Create: `public/assets/fonts/` (four woff2 files)

- [ ] **Step 1: Fetch the woff2 files**

Google Fonts serves woff2 to modern user agents. Fetch the CSS, extract the URLs, download them.

```bash
mkdir -p public/assets/fonts
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"

for spec in \
  "Fraunces:opsz,wght@9..144,300;9..144,400;9..144,600" \
  "Inter+Tight:wght@400;500;600" \
  "JetBrains+Mono:wght@400;500"
do
  curl -sS -A "$UA" "https://fonts.googleapis.com/css2?family=${spec}&display=swap" \
    | grep -oE 'https://[^)]+\.woff2'
done | sort -u > /tmp/font_urls.txt

wc -l < /tmp/font_urls.txt   # expect several URLs
while read -r u; do
  curl -sS -A "$UA" -o "public/assets/fonts/$(basename "$u")" "$u"
done < /tmp/font_urls.txt

ls -la public/assets/fonts/
```

- [ ] **Step 2: Verify the files are real fonts, not error pages**

```bash
file public/assets/fonts/*.woff2
```

Expected: every file reported as `Web Open Font Format (Version 2)`. If any says `HTML document`
the download failed and must be retried. Do not proceed with broken font files.

- [ ] **Step 3: Commit**

```bash
git add public/assets/fonts/
git commit -m "Self host Fraunces, Inter Tight and JetBrains Mono

Removes the render blocking Google Fonts request from every page load."
```

---

## Task 3: The stylesheet

**Files:**
- Create: `public/assets/stylesheets/main.css`

- [ ] **Step 1: Write the stylesheet**

Create `public/assets/stylesheets/main.css`. Use the exact tokens from the spec. Font `src` URLs
must match the actual filenames produced in Task 2, so list that directory first and adjust.

```css
/* ---- fonts ---- */
@font-face {
  font-family: 'Fraunces';
  src: url('/assets/fonts/FRAUNCES_FILE.woff2') format('woff2');
  font-weight: 300 600;
  font-display: swap;
}
@font-face {
  font-family: 'Inter Tight';
  src: url('/assets/fonts/INTER_TIGHT_FILE.woff2') format('woff2');
  font-weight: 400 600;
  font-display: swap;
}
@font-face {
  font-family: 'JetBrains Mono';
  src: url('/assets/fonts/JETBRAINS_FILE.woff2') format('woff2');
  font-weight: 400 500;
  font-display: swap;
}

/* ---- tokens ---- */
:root {
  --bg: #fbfaf8;
  --ink: #17161a;
  --ink-soft: #3d3a44;
  --ink-mute: #6a6672;
  --rule: #e6e2dc;
  --accent: #6f0697;
  --live: #1a7f4b;
  --dark: #0d0d10;
  --dark-ink: #ecebe8;

  --serif: 'Fraunces', Georgia, serif;
  --sans: 'Inter Tight', system-ui, sans-serif;
  --mono: 'JetBrains Mono', ui-monospace, monospace;

  --measure: 62ch;
  --gutter: 24px;
  --max: 940px;
}

/* ---- reset ---- */
*, *::before, *::after { box-sizing: border-box; }
body { margin: 0; }
img { max-width: 100%; height: auto; display: block; }

body {
  background: var(--bg);
  color: var(--ink);
  font-family: var(--sans);
  font-size: 16px;
  line-height: 1.65;
  -webkit-font-smoothing: antialiased;
}

.wrap { max-width: var(--max); margin: 0 auto; padding: 0 var(--gutter); }

/* ---- type ---- */
h1, h2, h3 { font-family: var(--serif); font-weight: 300; letter-spacing: -.02em; margin: 0 0 .5em; }
h1 { font-size: clamp(38px, 6vw, 64px); line-height: 1.03; }
h2 { font-size: clamp(26px, 3.6vw, 36px); line-height: 1.12; }
h3 { font-size: 20px; line-height: 1.25; }
p { margin: 0 0 1em; max-width: var(--measure); }
.lede { font-size: clamp(17px, 2.2vw, 20px); color: var(--ink-soft); }
.label {
  font-family: var(--mono); font-size: 10px; letter-spacing: .16em;
  text-transform: uppercase; color: var(--accent); margin: 0 0 14px;
}
a { color: var(--accent); text-decoration: none; border-bottom: 1px solid currentColor; }
a:hover { color: var(--ink); }
a:focus-visible { outline: 2px solid var(--accent); outline-offset: 3px; }

/* ---- chrome ---- */
.site-head {
  display: flex; justify-content: space-between; align-items: center;
  padding: 26px 0; border-bottom: 1px solid var(--rule);
}
.site-head img { height: 26px; width: auto; }
.site-nav { display: flex; gap: 26px; }
.site-nav a { font-size: 14px; color: var(--ink); border: 0; }
.site-nav a:hover { color: var(--accent); }

/* ---- work index rows ---- */
.work-row {
  display: flex; justify-content: space-between; align-items: baseline; gap: 16px;
  padding: 18px 0; border-top: 1px solid var(--rule);
}
.work-row:first-of-type { border-top: 1px solid var(--ink); }
.work-num { font-family: var(--mono); font-size: 10px; color: var(--accent); }
.work-name { font-family: var(--serif); font-size: 19px; }
.work-what { font-size: 13.5px; color: var(--ink-mute); }

/* ---- status pill ---- */
.status {
  font-family: var(--mono); font-size: 10px; letter-spacing: .1em; text-transform: uppercase;
}
.status-live { color: var(--live); }
.status-dev, .status-delivered { color: var(--ink-mute); }

/* ---- case study ---- */
.case-top {
  display: flex; justify-content: space-between; align-items: baseline;
  border-bottom: 1px solid var(--ink); padding-bottom: 14px; margin-bottom: 32px;
}
.block { margin: 0 0 40px; }
.seg { display: grid; grid-template-columns: 1fr 1fr; gap: 0 28px; border-top: 1px solid var(--rule); }
.seg > div { padding: 14px 0; border-bottom: 1px solid var(--rule); }
.seg h4 { font-family: var(--serif); font-weight: 400; font-size: 16px; margin: 0 0 4px; }
.seg p { font-size: 13px; color: var(--ink-mute); margin: 0; }
.eng { list-style: none; padding: 0; margin: 0; }
.eng li { font-size: 14.5px; color: var(--ink-soft); padding: 10px 0 10px 22px; border-top: 1px solid var(--rule); position: relative; }
/* Bullet, not an em dash. The site copy rule bans em dashes and that includes generated content. */
.eng li::before { content: "\2022"; position: absolute; left: 0; color: var(--accent); }
.pull {
  font-family: var(--serif); font-weight: 300; font-size: clamp(22px, 3.2vw, 30px);
  line-height: 1.3; border-left: 2px solid var(--accent); padding-left: 24px; max-width: 32ch;
}
figure { margin: 0 0 12px; }
figcaption { font-size: 12.5px; color: var(--ink-mute); margin-top: 8px; }

/* ---- dark contact band ---- */
.contact {
  background: var(--dark); color: var(--dark-ink); margin-top: 80px; padding: 64px 0;
}
.contact h2 { color: var(--dark-ink); }
.contact p { color: #9d9aa3; }
.contact a { color: var(--dark-ink); border-bottom-color: #4a4a55; }
.contact a:hover { color: #fff; }
.contact-actions { display: flex; gap: 28px; flex-wrap: wrap; margin-top: 22px; }

/* ---- footer ---- */
.site-foot {
  background: var(--dark); color: #6f6c78; padding: 0 0 40px; font-size: 12.5px;
}
.site-foot .wrap { display: flex; justify-content: space-between; gap: 16px; flex-wrap: wrap; }

/* ---- responsive ---- */
@media (max-width: 768px) {
  .seg { grid-template-columns: 1fr; }
  .site-nav { gap: 16px; }
  .work-row { flex-direction: column; gap: 4px; }
  .case-top { flex-direction: column; gap: 6px; }
}
```

- [ ] **Step 2: Replace the font filename placeholders**

```bash
ls public/assets/fonts/
```

Edit the three `src: url(...)` lines so they name the real files. Verify none of the strings
`FRAUNCES_FILE`, `INTER_TIGHT_FILE` or `JETBRAINS_FILE` remain:

```bash
grep -n '_FILE' public/assets/stylesheets/main.css && echo "PLACEHOLDERS REMAIN, fix them" || echo "clean"
```

Expected: `clean`.

- [ ] **Step 3: Commit**

```bash
git add public/assets/stylesheets/main.css
git commit -m "Add the editorial stylesheet

Single hand written stylesheet replacing the Tailwind CDN build."
```

---

## Task 4: Shared chrome partials

**Files:**
- Modify: `public/_includes/header.html`
- Modify: `public/_includes/footer.html`

The existing partials already work. Extend them, keeping the `set`/`echo` title mechanism.

- [ ] **Step 1: Write the header partial**

Replace `public/_includes/header.html` entirely:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><!--# echo var="title" --></title>
  <meta name="description" content="<!--# echo var="description" -->">
  <link rel="stylesheet" href="/assets/stylesheets/main.css">
</head>
<body>
<header class="site-head wrap" data-chrome="header">
  <a href="/" aria-label="Zimzcore home" style="border:0">
    <img src="/assets/images/ZIMZCORE LOGO PURPLE AND BLACK.png" alt="Zimzcore">
  </a>
  <nav class="site-nav">
    <a href="/work">Work</a>
    <a href="/#what-we-do">What we do</a>
    <a href="https://wa.me/233557711911">Contact</a>
  </nav>
</header>
<main class="wrap">
```

The `data-chrome="header"` attribute is the marker the test suite greps for. Do not remove it.

- [ ] **Step 2: Write the footer partial**

Replace `public/_includes/footer.html` entirely:

```html
</main>
<section class="contact" data-chrome="footer">
  <div class="wrap">
    <h2>Have a problem shaped like one of these?</h2>
    <p>Tell us what is going wrong and we will tell you honestly whether we can help.</p>
    <div class="contact-actions">
      <a href="https://wa.me/233557711911">WhatsApp 055 771 1911</a>
      <a href="mailto:hello@zimzcore.com">hello@zimzcore.com</a>
    </div>
  </div>
</section>
<footer class="site-foot">
  <div class="wrap">
    <span>Zimzcore, Accra, Ghana</span>
    <span>&copy; 2026 Zimzcore</span>
  </div>
</footer>
</body>
</html>
```

- [ ] **Step 3: Verify the logo filename is exact**

The logo files contain spaces and one has a double space. Confirm before trusting the path:

```bash
ls public/assets/images/*.png
```

Expected to include `ZIMZCORE LOGO PURPLE AND BLACK.png`. If the name differs, correct the
header partial. A broken logo is the first thing a visitor sees.

- [ ] **Step 4: Commit**

```bash
git add public/_includes/
git commit -m "Extend the shared header and footer partials

Adds nav, stylesheet link, dark contact band and the data-chrome test
markers. Keeps the existing set/echo title mechanism."
```

---

## Task 5: Homepage

**Files:**
- Modify: `public/index.html` (full replacement)

- [ ] **Step 1: Write the homepage**

Replace `public/index.html` entirely. Every claim here traces to a real project. No statistics.

```html
<!--# set var="title" value="Zimzcore, software that solves expensive problems" -->
<!--# set var="description" value="A Ghanaian software company building and running its own products. Fleet tracking, fact checking, digital memorials and fellowship management." -->
<!--#include virtual="/_includes/header.html" -->

<section style="padding: 72px 0 56px">
  <p class="label">Accra, Ghana</p>
  <h1>We build software that solves expensive problems.</h1>
  <p class="lede">Fleet owners losing fuel to theft. Fellowship programmes drowning in paper
  applications. Families with nowhere to gather after a funeral. We build the system that fixes
  it, then we run it.</p>
  <p>We build for clients, and we build for ourselves. Two of our own platforms are live with
  paying customers, which is the part most software firms cannot show you.</p>
</section>

<section style="padding: 0 0 56px">
  <p class="label">The work</p>

  <div class="work-row">
    <span><span class="work-num">01</span> <span class="work-name">Lokkate</span>
      <span class="work-what">Drivers lie about where they have been. Now the vehicle answers for itself.</span></span>
    <span><a href="/work/lokkate">Read</a></span>
  </div>

  <div class="work-row">
    <span><span class="work-num">02</span> <span class="work-name">Live On Forever</span>
      <span class="work-what">A place for a family to grieve together when they are scattered across the world.</span></span>
    <span><a href="/work/live-on-forever">Read</a></span>
  </div>

  <div class="work-row">
    <span><span class="work-num">03</span> <span class="work-name">Kasagandi AI</span>
      <span class="work-what">A rumour spreads in a day. Checking it properly takes a week and nobody pays for it.</span></span>
    <span><a href="/work/kasagandi-ai">Read</a></span>
  </div>

  <div class="work-row">
    <span><span class="work-num">04</span> <span class="work-name">Fellowship Management</span>
      <span class="work-what">Hundreds of applicants, several interview rounds, and a spreadsheet holding it together.</span></span>
    <span><a href="/work/fellowship-lms">Read</a></span>
  </div>
</section>

<section id="what-we-do" style="padding: 0 0 40px">
  <p class="label">What we do for clients</p>
  <h2>Three things, all of which we have shipped.</h2>

  <div class="block">
    <h3>Operational systems</h3>
    <p>Work that moves through stages, with different people responsible at each one. Applications
    that get vetted, scored and decided. Claims that get assigned, researched and published.
    Roles, permissions and an audit trail of who did what.</p>
  </div>

  <div class="block">
    <h3>Hardware and payments</h3>
    <p>Systems that touch the physical world and real money. GPS trackers streaming position data
    off vehicles. Commands sent back to those vehicles. Mobile money collection, subscription
    billing and payouts, reconciled against the gateway.</p>
  </div>

  <div class="block">
    <h3>End to end delivery</h3>
    <p>From the first conversation to a running system with customers on it. We design it, build
    it, deploy it and keep it alive. We are small and senior, so you talk to the people writing
    the code.</p>
  </div>
</section>

<!--#include virtual="/_includes/footer.html" -->
```

- [ ] **Step 2: Run the suite**

```bash
test/run_local.sh start
test/site_test.sh
```

Expected: `/` now passes 200, both `data-chrome` checks, and every banned copy check. The four
case study pages and `/work` still fail with 404. That is correct at this point.

- [ ] **Step 3: Commit**

```bash
git add public/index.html
git commit -m "Rebuild the homepage

Removes the 0+ stat block, the Tailwind CDN, the generic services copy
and the two dead project links. Replaces them with the four real
platforms and capability claims traceable to shipped work."
```

---

## Task 6: Work index page

**Files:**
- Create: `public/work/index.html`

- [ ] **Step 1: Write the index**

```html
<!--# set var="title" value="Work, Zimzcore" -->
<!--# set var="description" value="Platforms Zimzcore has built and runs: fleet tracking, digital memorials, fact checking and fellowship management." -->
<!--#include virtual="/_includes/header.html" -->

<section style="padding: 64px 0 40px">
  <p class="label">Everything we have built</p>
  <h1>Work</h1>
  <p class="lede">Four platforms. Two are live with paying customers, one is in development, one
  was delivered to a client and is in daily use.</p>
</section>

<section style="padding: 0 0 40px">
  <div class="work-row">
    <span><span class="work-num">01</span> <span class="work-name">Lokkate</span>
      <span class="work-what">Vehicle tracking and fleet management</span></span>
    <span class="status status-live">Live</span>
    <span><a href="/work/lokkate">Read</a></span>
  </div>
  <div class="work-row">
    <span><span class="work-num">02</span> <span class="work-name">Live On Forever</span>
      <span class="work-what">Digital memorials and tributes</span></span>
    <span class="status status-live">Live</span>
    <span><a href="/work/live-on-forever">Read</a></span>
  </div>
  <div class="work-row">
    <span><span class="work-num">03</span> <span class="work-name">Kasagandi AI</span>
      <span class="work-what">Fact checking marketplace</span></span>
    <span class="status status-dev">In development</span>
    <span><a href="/work/kasagandi-ai">Read</a></span>
  </div>
  <div class="work-row">
    <span><span class="work-num">04</span> <span class="work-name">Fellowship Management</span>
      <span class="work-what">Applications, vetting and learning platform</span></span>
    <span class="status status-delivered">Delivered</span>
    <span><a href="/work/fellowship-lms">Read</a></span>
  </div>
</section>

<!--#include virtual="/_includes/footer.html" -->
```

- [ ] **Step 2: Verify the clean URL resolves**

```bash
curl -sS -o /dev/null -w '%{http_code}\n' http://localhost:8099/work
```

Expected: `200`, served by `try_files $uri/index.html`.

- [ ] **Step 3: Commit**

```bash
git add public/work/index.html
git commit -m "Add the work index page

Absorbs project growth so the homepage never gets longer."
```

---

## Task 7: Lokkate case study

**Files:**
- Create: `public/work/lokkate.html`

Source: `~/workspace/ruby/lokkate/docs/project-brief.md`

- [ ] **Step 1: Write the page**

```html
<!--# set var="title" value="Lokkate, vehicle tracking for Ghana, Zimzcore" -->
<!--# set var="description" value="Real time GPS tracking, geofence alerts and remote immobilisation for Ghanaian fleet owners, rental companies and vehicle financiers." -->
<!--#include virtual="/_includes/header.html" -->

<div class="case-top" style="margin-top:56px">
  <span class="work-num">01 / WORK</span>
  <span class="status status-live">Live at <a href="https://lokkate.com">lokkate.com</a></span>
</div>

<h1>Lokkate</h1>
<p class="lede">Vehicle tracking and fleet management, built for how Ghanaian businesses actually
operate.</p>

<div class="block">
  <p class="label">The problem</p>
  <p>Businesses with vehicles lose money every day and cannot prove any of it. Drivers lie about
  where they have been. Fuel disappears. Vehicles go out at night and come back before morning.</p>
  <p>Rental companies hand over a car and lose sight of it completely. They cannot tell whether it
  has left Accra or when it is coming back. Financiers carry the same exposure on every vehicle
  they fund. When a borrower stops paying, the asset is somewhere out on the road, and asking
  nicely is the only option left.</p>
</div>

<div class="block">
  <p class="label">Who it is for</p>
  <div class="seg">
    <div><h4>Individual owners</h4><p>One car, one driver, and a suspicion that the car moves at night.</p></div>
    <div><h4>Fleet operators</h4><p>Two to thirty vehicles. Needs to see all of them at once, and to be told when something is wrong.</p></div>
    <div><h4>Rental companies</h4><p>Needs the car inside permitted zones and back on time, enforceable rather than merely requested.</p></div>
    <div><h4>Vehicle financiers</h4><p>Protects the asset behind the loan. Missed payment, remote immobilisation, restored on payment.</p></div>
  </div>
</div>

<div class="block">
  <p class="label">What we built</p>
  <p>A GPS tracker goes into the vehicle and streams position data over the mobile network to the
  platform. The owner signs in from anywhere and sees where the vehicle is now, everywhere it has
  been, how fast it was driven, and whether the trip matches what the driver said.</p>
  <p>For rental and financing customers it goes past reporting into enforcement. A vehicle can be
  stopped from starting when a payment is missed or when it leaves a zone it should not have left.</p>
</div>

<div class="block">
  <p class="label">Notable engineering</p>
  <ul class="eng">
    <li>Continuous GPS telemetry ingestion from physical trackers, turned into trips, positions and driver behaviour history</li>
    <li>Remote immobiliser command pipeline, safety critical, acknowledged and fully audited</li>
    <li>Route playback with a timeline scrubber, plus geofence, speeding, after hours and ignition alerts</li>
    <li>Subscription billing against Ghanaian payment rails with gateway reconciliation</li>
    <li>A native iOS application alongside the web platform</li>
  </ul>
</div>

<div class="block">
  <figure>
    <img src="/assets/images/work/lokkate-map.png" alt="Lokkate live map showing tracked vehicle positions">
    <figcaption>The live map. Every vehicle, current position, at a glance.</figcaption>
  </figure>
</div>

<div class="block">
  <p class="pull">You always know where everything is.</p>
</div>

<!--#include virtual="/_includes/footer.html" -->
```

- [ ] **Step 2: Note the image dependency**

`/assets/images/work/lokkate-map.png` does not exist yet. Task 11 captures it. Until then the page
renders with a broken image. That is expected and Task 11 closes it. Do not invent a placeholder
image, and do not remove the `<figure>`, because Task 11 depends on it being here.

- [ ] **Step 3: Run the suite and commit**

```bash
test/site_test.sh
git add public/work/lokkate.html
git commit -m "Add the Lokkate case study"
```

Expected: `/work/lokkate` now passes 200 and all copy checks.

---

## Task 8: Live On Forever case study

**Files:**
- Create: `public/work/live-on-forever.html`

Source: models in `~/workspace/ruby/live_on_forever/app/models/` (memorial, tribute, condolence,
donation_request, payout_account, transaction, event, collection, custom_tab, page_view).

- [ ] **Step 1: Write the page**

```html
<!--# set var="title" value="Live On Forever, digital memorials, Zimzcore" -->
<!--# set var="description" value="A digital memorial platform where families gather, share tributes and raise funeral contributions from anywhere in the world." -->
<!--#include virtual="/_includes/header.html" -->

<div class="case-top" style="margin-top:56px">
  <span class="work-num">02 / WORK</span>
  <span class="status status-live">Live at <a href="https://liveonforever.com">liveonforever.com</a></span>
</div>

<h1>Live On Forever</h1>
<p class="lede">A place for a family to remember someone together, even when they are spread
across four countries.</p>

<div class="block">
  <p class="label">The problem</p>
  <p>When someone dies, a Ghanaian family is rarely in one place. Children are in London and
  Toronto, cousins are in Kumasi, and the funeral is being organised over a dozen WhatsApp groups
  that nobody can follow.</p>
  <p>Contributions are the hardest part. Money comes in from everywhere, someone writes the
  amounts in a notebook, and by the end nobody can say with confidence who gave what. The
  memories are worse. Photographs and tributes sit in private phones and are gone within a year.</p>
</div>

<div class="block">
  <p class="label">Who it is for</p>
  <div class="seg">
    <div><h4>The organising family</h4><p>Usually one or two people carrying the funeral, needing everyone else informed without repeating themselves.</p></div>
    <div><h4>Family abroad</h4><p>Cannot attend in person. Wants to contribute, be present, and see what happened.</p></div>
    <div><h4>Friends and colleagues</h4><p>Wants to leave a tribute and give something, without a bank transfer to a stranger's account.</p></div>
    <div><h4>The family afterwards</h4><p>Comes back on anniversaries. The memorial is the thing that lasts.</p></div>
  </div>
</div>

<div class="block">
  <p class="label">What we built</p>
  <p>A memorial page for the person, owned by the family. Tributes and condolences from anyone
  invited. Photographs collected into albums rather than scattered. Funeral events with details
  everyone can see instead of asking.</p>
  <p>Contributions run through the platform itself, with donation requests, tracked transactions
  and payouts to the family's own account. Every contribution is recorded, so there is no notebook
  and no argument later.</p>
</div>

<div class="block">
  <p class="label">Notable engineering</p>
  <ul class="eng">
    <li>Donation collection with recorded transactions and payouts to family held accounts</li>
    <li>Memorials with configurable custom sections, so a family shapes the page to the person</li>
    <li>Moderated tributes and condolences, because grief pages attract abuse</li>
    <li>Per memorial analytics, so a family can see the reach of what they built</li>
  </ul>
</div>

<div class="block">
  <figure>
    <img src="/assets/images/work/live-on-forever.png" alt="A Live On Forever memorial page showing tributes and photographs">
    <figcaption>A memorial page. Tributes, photographs and funeral details in one place.</figcaption>
  </figure>
</div>

<div class="block">
  <p class="pull">Grief does not respect distance. The place you gather should not either.</p>
</div>

<!--#include virtual="/_includes/footer.html" -->
```

- [ ] **Step 2: Run the suite and commit**

```bash
test/site_test.sh
git add public/work/live-on-forever.html
git commit -m "Add the Live On Forever case study"
```

---

## Task 9: Kasagandi AI case study

**Files:**
- Create: `public/work/kasagandi-ai.html`

Source: `~/workspace/ruby/kasagandi_ai/docs/MANUAL.md`

This page has **no screenshot and no outbound link**. It uses the pull quote as its only visual.
This is the fallback the spec requires, and it is the proof the template degrades cleanly.

- [ ] **Step 1: Write the page**

```html
<!--# set var="title" value="Kasagandi AI, fact checking for Ghana, Zimzcore" -->
<!--# set var="description" value="A Ghana focused fact checking marketplace where the public submits claims and accredited checkers publish verdicts with evidence." -->
<!--#include virtual="/_includes/header.html" -->

<div class="case-top" style="margin-top:56px">
  <span class="work-num">03 / WORK</span>
  <span class="status status-dev">In development</span>
</div>

<h1>Kasagandi AI</h1>
<p class="lede">Somewhere between a rumour and the truth there is a week of unpaid work. This is
the system that organises it.</p>

<div class="block">
  <p class="label">The problem</p>
  <p>A claim goes around Ghanaian WhatsApp and by the evening a few hundred thousand people have
  seen it. Checking it properly takes days of real research, and the people capable of doing that
  work have no route to it and no way to be paid for it.</p>
  <p>So the checking either does not happen, or it happens in a newsroom nobody outside can see.
  The verdict, when it exists, arrives with no evidence attached and no way to tell how it was
  reached. Asking the public to trust a bare conclusion is exactly the problem that started this.</p>
</div>

<div class="block">
  <p class="label">Who it is for</p>
  <div class="seg">
    <div><h4>Members of the public</h4><p>Saw something suspicious and wants to know whether it is true.</p></div>
    <div><h4>Accredited fact checkers</h4><p>Has the skill to investigate. Wants assignments and a record of the work.</p></div>
    <div><h4>Editors and administrators</h4><p>Triages what comes in, assigns it, and decides what gets published.</p></div>
    <div><h4>Anyone reading</h4><p>Browses published verdicts without an account, and can see the evidence behind each one.</p></div>
  </div>
</div>

<div class="block">
  <p class="label">What we built</p>
  <p>A marketplace with three roles. The public submits claims. Administrators triage them and
  assign them to accredited fact checkers. Checkers research, attach their evidence, and submit a
  verdict. An administrator approves it, and only then does it appear publicly.</p>
  <p>The whole journey from a suspicious headline to a verdict with its research trail attached
  lives in one auditable system, so a reader can see not only the conclusion but how it was
  reached.</p>
</div>

<div class="block">
  <p class="label">Notable engineering</p>
  <ul class="eng">
    <li>A claim state machine governing submission, assignment, verdict and publication, with every transition recorded</li>
    <li>Three role types over one identity, driving both routing and authorisation</li>
    <li>Invitation only onboarding for fact checkers, since accreditation is the whole value</li>
    <li>An audit log covering every action taken on a claim</li>
    <li>Evidence attached to verdicts as first class records rather than pasted links</li>
  </ul>
</div>

<div class="block">
  <p class="pull">A verdict nobody can check is just another rumour with better manners.</p>
</div>

<!--#include virtual="/_includes/footer.html" -->
```

- [ ] **Step 2: Confirm the page reads as finished without an image**

```bash
test/run_local.sh start
open http://localhost:8099/work/kasagandi-ai
```

Look at it. The pull quote should carry the block where a screenshot would be. If the page looks
unfinished, that is a real problem, because this layout is the fallback for every future project
without screenshots. Fix the spacing in `main.css` rather than adding a decorative image.

- [ ] **Step 3: Commit**

```bash
git add public/work/kasagandi-ai.html
git commit -m "Add the Kasagandi AI case study

No screenshot and no outbound link. Uses the pull quote fallback, which
is the template's degraded path for projects without visuals."
```

---

## Task 10: Fellowship LMS case study

**Files:**
- Create: `public/work/fellowship-lms.html`

Source: `~/workspace/ruby/fellowship_management_application/docs/EPL-LMS-Delivery-Summary.md`

- [ ] **Step 1: Review the screenshots for personal data before anything else**

EPL have approved naming them and publishing screenshots. Their approval covers their system. It
does not cover individual fellows' personal data appearing inside a screenshot.

```bash
ls ~/workspace/ruby/fellowship_management_application/docs/images/
```

Open each image and check for real people's names, email addresses, or individual scores.
Sort them into two lists:

- **Clear:** no individual personal data. Safe to publish.
- **Flag:** shows a named individual, an email address, or a person's score.

**Stop and ask the user about every image in the Flag list.** Do not publish them, and do not
silently drop them either. The user decides.

- [ ] **Step 2: Copy the clear images**

```bash
mkdir -p public/assets/images/work
cp ~/workspace/ruby/fellowship_management_application/docs/images/fellow-catalogue.png \
   public/assets/images/work/lms-catalogue.png
cp ~/workspace/ruby/fellowship_management_application/docs/images/fellow-course-content.png \
   public/assets/images/work/lms-course-content.png
```

Adjust the source filenames to whatever survived Step 1. If a chosen image is on the Flag list,
use a different one.

- [ ] **Step 3: Write the page**

```html
<!--# set var="title" value="Fellowship management for EPL Ghana, Zimzcore" -->
<!--# set var="description" value="An applications, vetting and learning platform built for the EPL Ghana Public Service Fellowship." -->
<!--#include virtual="/_includes/header.html" -->

<div class="case-top" style="margin-top:56px">
  <span class="work-num">04 / WORK</span>
  <span class="status status-delivered">Delivered for EPL Ghana</span>
</div>

<h1>Fellowship Management</h1>
<p class="lede">Everything from an open application to a graduating fellow, for the EPL Ghana
Public Service Fellowship.</p>

<div class="block">
  <p class="label">The problem</p>
  <p>A competitive fellowship gets hundreds of applications for a handful of places. Each one has
  to be read, scored by more than one assessor, taken through several interview rounds, and
  decided. Most programmes run that on spreadsheets and email.</p>
  <p>It falls apart in predictable ways. Two assessors score the same candidate and nobody can
  reconcile the sheets. An applicant is dropped between rounds because a row was sorted wrong.
  Nobody can answer where a candidate is in the process without opening four files. Then the
  fellows arrive and the whole teaching side has to be run somewhere else entirely.</p>
</div>

<div class="block">
  <p class="label">Who it is for</p>
  <div class="seg">
    <div><h4>Applicants</h4><p>Applies once, and can see how far they have got.</p></div>
    <div><h4>Assessors and interviewers</h4><p>Scores against a defined sheet, without a spreadsheet each.</p></div>
    <div><h4>Fellowship managers</h4><p>Sees every candidate's stage, moves them forward, and decides.</p></div>
    <div><h4>Fellows and instructors</h4><p>Courses, lessons, quizzes and discussions once the cohort begins.</p></div>
  </div>
</div>

<div class="block">
  <p class="label">What we built</p>
  <p>One system covering the full lifecycle. Configurable application forms, then a pipeline that
  carries a submission through vetting, two interview rounds, career direction and a final
  decision, with scores recorded against a defined sheet at each stage and multiple assessors on
  the same candidate.</p>
  <p>Once the cohort starts, the same system teaches them. Courses with image led catalogues and
  progress, lessons with videos and materials, quizzes with automatic marking for multiple choice
  and a clean grading screen for written answers, plus per lesson discussions. Placements,
  institutions, supervisors and alumni are all tracked through to the end.</p>
</div>

<div class="block">
  <p class="label">Notable engineering</p>
  <ul class="eng">
    <li>A multi stage application pipeline with per stage scoring and controlled progression between rounds</li>
    <li>Configurable application forms, so the programme changes its questions without a code change</li>
    <li>Nine distinct user roles, each with its own permissions and views</li>
    <li>Automatic marking for multiple choice with a dedicated manual grading screen for written answers</li>
    <li>An automated test suite covering the learner and instructor journeys so the flows keep working</li>
  </ul>
</div>

<div class="block">
  <figure>
    <img src="/assets/images/work/lms-catalogue.png" alt="The fellow's course catalogue, showing progress and status on each course card">
    <figcaption>The fellow's course catalogue. Each card knows whether to say Start, Resume or Review.</figcaption>
  </figure>
</div>

<div class="block">
  <figure>
    <img src="/assets/images/work/lms-course-content.png" alt="A course presented as a step by step learning path with completed lessons marked">
    <figcaption>A course as a learning path, so a fellow always knows the next step.</figcaption>
  </figure>
</div>

<div class="block">
  <p class="pull">Hundreds of applicants, several rounds, and a spreadsheet holding it together. Until it did not.</p>
</div>

<!--#include virtual="/_includes/footer.html" -->
```

- [ ] **Step 4: Verify the images actually load**

```bash
for i in lms-catalogue lms-course-content; do
  printf "%-22s %s\n" "$i" "$(curl -sS -o /dev/null -w '%{http_code}' http://localhost:8099/assets/images/work/$i.png)"
done
```

Expected: `200` for both. A 404 means the filename in the HTML does not match the copied file.

- [ ] **Step 5: Commit**

```bash
git add public/work/fellowship-lms.html public/assets/images/work/
git commit -m "Add the EPL Ghana fellowship management case study

Screenshots published with EPL's permission, reviewed for individual
personal data before inclusion."
```

---

## Task 11: Capture screenshots from the live products

**Files:**
- Create: `public/assets/images/work/lokkate-map.png`
- Create: `public/assets/images/work/live-on-forever.png`

Lokkate and Live On Forever are public live sites, so no permission question arises.

- [ ] **Step 1: Capture both**

Use headless Chrome, which is already on most macOS machines with Chrome installed:

```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p public/assets/images/work

"$CHROME" --headless --disable-gpu --window-size=1440,900 \
  --screenshot="public/assets/images/work/lokkate-map.png" https://lokkate.com

"$CHROME" --headless --disable-gpu --window-size=1440,900 \
  --screenshot="public/assets/images/work/live-on-forever.png" https://liveonforever.com

file public/assets/images/work/*.png
```

Expected: both reported as `PNG image data, 1440 x 900`.

If Chrome is not installed, take the screenshots manually at 1440 wide and save them to those
exact paths. Do not substitute stock photography.

- [ ] **Step 2: Check what the screenshots actually show**

Open both files and look at them. A public marketing homepage is a weak screenshot for a case
study about a tracking platform. If the captures are just landing pages rather than the product,
say so and ask the user for authenticated screenshots of the real interface. A weak screenshot is
worse than the pull quote fallback.

- [ ] **Step 3: Verify they load and commit**

```bash
for i in lokkate-map live-on-forever; do
  printf "%-22s %s\n" "$i" "$(curl -sS -o /dev/null -w '%{http_code}' http://localhost:8099/assets/images/work/$i.png)"
done
git add public/assets/images/work/
git commit -m "Add screenshots for Lokkate and Live On Forever"
```

---

## Task 12: Restyle the 404 page and remove dead files

**Files:**
- Modify: `public/_errors/404.html`
- Delete: `public/_old.html`

- [ ] **Step 1: Rewrite the 404 page**

Its SSI already works. This is content and styling only.

```html
<!--# set var="title" value="Page not found, Zimzcore" -->
<!--# set var="description" value="That page does not exist." -->
<!--#include virtual="/_includes/header.html" -->

<section style="padding: 96px 0 72px">
  <p class="label">404</p>
  <h1>That page does not exist.</h1>
  <p class="lede">It may have moved, or the link may be wrong.
  <a href="/work">See what we have built</a>, or go back to the
  <a href="/">homepage</a>.</p>
</section>

<!--#include virtual="/_includes/footer.html" -->
```

- [ ] **Step 2: Delete the dead page**

```bash
git rm public/_old.html
```

- [ ] **Step 3: Verify the 404 still works as an error page**

```bash
curl -sS http://localhost:8099/definitely-not-a-page | head -20
curl -sS -o /dev/null -w '%{http_code}\n' http://localhost:8099/definitely-not-a-page
```

Expected: the styled 404 content, and status `404`. The status must stay 404 and not become 200.
An error page that returns 200 is invisible to search engines and to monitoring.

- [ ] **Step 4: Commit**

```bash
git add public/_errors/404.html
git commit -m "Restyle the 404 page and delete the dead _old.html"
```

---

## Task 13: Set up hello@zimzcore.com

This task is the user's to perform. It is in the plan because the footer already links the
address, and a bouncing address on a contact page is worse than no address.

- [ ] **Step 1: Confirm the current state**

```bash
dig +short MX zimzcore.com
```

Expected right now: empty, meaning no mail is configured.

- [ ] **Step 2: Ask the user to enable Cloudflare Email Routing**

In the Cloudflare dashboard for zimzcore.com: Email, then Email Routing, then create the address
`hello@zimzcore.com` forwarding to `dapilah.sydney@gmail.com`. Cloudflare adds the MX records
itself. The destination address has to be verified by clicking a link Cloudflare emails.

- [ ] **Step 3: Verify it works before launch**

```bash
dig +short MX zimzcore.com
```

Expected: Cloudflare MX records present. Then send a real test message to hello@zimzcore.com and
confirm it lands in the Gmail inbox.

If the user chooses not to set this up, remove the email line from
`public/_includes/footer.html` and leave WhatsApp as the only channel. Do not ship a dead
address.

---

## Task 14: Full verification and deploy

- [ ] **Step 1: Run the full suite locally, expecting zero failures**

```bash
test/run_local.sh start
test/site_test.sh
```

Expected: `failed: 0`. Do not continue until this is true.

- [ ] **Step 2: Check both viewport widths by eye**

```bash
open http://localhost:8099/
```

In the browser device toolbar check 375px and 1440px on the homepage, the work index and one case
study. The segment grid must collapse to one column on mobile, nothing may scroll sideways, and
the nav must stay usable.

- [ ] **Step 3: Check contrast and heading structure**

Contrast ratios for the token pairs in `main.css`, which must all clear WCAG AA (4.5:1 for body
text, 3:1 for large text):

```bash
python3 - <<'PY'
def lum(h):
    c = [int(h[i:i+2], 16) / 255 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4 for x in c]
    return .2126 * c[0] + .7152 * c[1] + .0722 * c[2]

def ratio(a, b):
    la, lb = sorted([lum(a), lum(b)], reverse=True)
    return (la + .05) / (lb + .05)

pairs = [
    ("body text",    "#17161a", "#fbfaf8"),
    ("soft text",    "#3d3a44", "#fbfaf8"),
    ("muted text",   "#6a6672", "#fbfaf8"),
    ("accent link",  "#6f0697", "#fbfaf8"),
    ("live status",  "#1a7f4b", "#fbfaf8"),
    ("dark band",    "#ecebe8", "#0d0d10"),
    ("dark muted",   "#9d9aa3", "#0d0d10"),
    ("footer text",  "#6f6c78", "#0d0d10"),
]
for name, fg, bg in pairs:
    r = ratio(fg, bg)
    print(f"{name:14} {fg} on {bg}  {r:5.2f}  {'PASS' if r >= 4.5 else 'CHECK'}")
PY
```

Any pair below 4.5 must either be darkened in `main.css` or confirmed to be used only at large
sizes. `footer text` is the likeliest to fail; darken it rather than shipping unreadable text.

Then confirm heading structure: exactly one `<h1>` per page, and no level skipped.

```bash
for p in / /work /work/lokkate /work/live-on-forever /work/kasagandi-ai /work/fellowship-lms; do
  printf "%-26s h1=%s\n" "$p" "$(curl -sS "http://localhost:8099$p" | grep -c '<h1')"
done
```

Expected: `h1=1` on every page.

- [ ] **Step 4: Verify every internal link resolves**

```bash
for p in / /work /work/lokkate /work/live-on-forever /work/kasagandi-ai /work/fellowship-lms; do
  curl -sS "http://localhost:8099$p" \
    | grep -oE 'href="/[^"#]*"' | sed 's/href="//;s/"//' | sort -u
done | sort -u | while read -r link; do
  printf "%-34s %s\n" "$link" "$(curl -sS -o /dev/null -w '%{http_code}' "http://localhost:8099$link")"
done
```

Expected: every line 200. Anything else is a broken internal link and must be fixed before deploy.

- [ ] **Step 5: Confirm no credential files would enter the image**

```bash
grep -c load_env .dockerignore
```

Expected: at least 1. This was fixed in commit 3c08c19 and must stay true, because the Docker Hub
repository is public.

- [ ] **Step 6: Commit, push and deploy**

```bash
git status
git push origin main
source ./load_env.sh && kamal deploy
```

The push alone updates page content within about ten seconds through the container's git polling.
`kamal deploy` is still needed here because this work adds new files and directories, and a full
deploy is the clean way to land a change of this size.

- [ ] **Step 7: Re-run the suite against production**

```bash
test/site_test.sh https://zimzcore.com
```

Expected: `failed: 0`.

- [ ] **Step 8: Confirm the WhatsApp link opens the right chat**

Open `https://wa.me/233557711911` on a phone and confirm it opens a chat with 055 771 1911. This
is the site's primary conversion path and it is currently wrong on the live site, so it is worth
checking by hand rather than trusting the string.

- [ ] **Step 9: Final commit if anything changed**

```bash
git status
```

Expected: clean.

---

## Deferred, not in this plan

- Fixing `www.zimzcore.com`, which returns 526. Needs a Cloudflare redirect rule to the apex, or
  `www` added to `proxy.host` in `config/deploy.yml` plus a fresh certificate. The user's call.
- The silent failure mode in `serve`, where both git commands end in `|| true`, so a revoked token
  freezes the site with no signal.
- `.kamal/` shipping inside the image. Already added to `.dockerignore`, lands on the next deploy.
- Migrating to a static site generator. Revisit past roughly ten projects.
