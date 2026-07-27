#!/bin/bash
# HTTP contract suite. Runs against a base URL, defaulting to the local container.
# Usage: test/site_test.sh [base_url]
#   SKIP_NETWORK=1 test/site_test.sh    # skip outbound checks when offline
set -u

BASE="${1:-http://localhost:8099}"
BASE="${BASE%/}"                      # tolerate a trailing slash in the argument
PASS=0; FAIL=0

ok()  { printf "  ok    %s\n" "$1"; PASS=$((PASS+1)); }
bad() { printf "  FAIL  %s\n" "$1"; FAIL=$((FAIL+1)); }

# Page and asset assertions must NOT follow redirects: a clean URL that only
# works via a 301 is not a clean URL. Only the outbound check follows.
status()        { curl -sS  -o /dev/null -w '%{http_code}' --max-time 10 "$1" 2>/dev/null; }
status_follow() { curl -sSL -o /dev/null -w '%{http_code}' --max-time 10 "$1" 2>/dev/null; }
raw()           { curl -sS --max-time 10 "$1" 2>/dev/null; }

# Fetch once, then flatten newlines to spaces. Multi-word needles like
# "transform your vision" must not be defeatable by a line wrap.
fetch_norm() { raw "$1" | tr '\n\r\t' '   ' | tr -s ' '; }

expect_status() {
  local path="$1" want="$2" got
  got="$(status "$BASE$path")"
  [ "$got" = "$want" ] && ok "$path -> $want" || bad "$path -> got $got, want $want"
}

# $1 label, $2 haystack, $3 needle. Case-insensitive: banned marketing copy
# appears title-cased in headings ("Innovation", "Seamless Integration").
expect_body_contains() {
  if printf '%s' "$2" | grep -qiF -- "$3"; then ok "$1 contains '$3'"; else bad "$1 missing '$3'"; fi
}

expect_body_absent() {
  if printf '%s' "$2" | grep -qiF -- "$3"; then bad "$1 still contains '$3'"; else ok "$1 free of '$3'"; fi
}

PAGES="/ /work /work/lokkate /work/live-on-forever /work/kasagandi-ai /work/fellowship-lms"
PARTIALS="/_includes/header.html /_includes/footer.html"

# Stems rather than whole words, so inflections are caught too. The em dash is
# listed in all three renderings because &mdash; and &#8212; display identically
# to the literal character and would otherwise slip past.
BANNED='>0+<
cutting
seamless
transform your vision
innovat
leverag
cdn.tailwindcss.com
—
&mdash;
&#8212;
233203669141
nutriiq.zimzcore.com
growfastfunding.zimzcore.com'

echo "== pages return 200 =="
for p in $PAGES; do expect_status "$p" 200; done
expect_status "/up.html" 200

echo "== page contract: SSI assembly, contact, banned copy, assets =="
for p in $PAGES; do
  b="$(fetch_norm "$BASE$p")"
  # data-chrome markers exist ONLY in the partials, so finding them proves
  # SSI actually assembled the page rather than proving a string exists.
  expect_body_contains "$p" "$b" 'data-chrome="header"'
  expect_body_contains "$p" "$b" 'data-chrome="footer"'
  expect_body_contains "$p" "$b" 'wa.me/233557711911'

  while IFS= read -r needle; do
    [ -n "$needle" ] && expect_body_absent "$p" "$b" "$needle"
  done <<EOF
$BANNED
EOF

  # Asset refs are checked per page so a failure names where it came from.
  # A relative ref is a FAILURE, not something to normalise: on /work/lokkate
  # "assets/x.png" resolves to /work/assets/x.png, which is not where it lives.
  #
  # Split srcset on commas, then strip only a trailing "1x"/"640w" descriptor.
  # Deliberately NOT a whitespace split: some image filenames contain spaces
  # (including one with a double space), and truncating at the first space
  # would report a 404 for a file that exists and is referenced correctly.
  refs="$(printf '%s' "$b" \
    | grep -oE '(href|src|srcset)="[^"]*"' \
    | sed 's/^[a-z]*="//; s/"$//' \
    | tr ',' '\n' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
    | sed -E 's/[[:space:]]+[0-9.]+[xw]$//' \
    | grep -E '(^|\./|/)assets/' \
    | sort -u)"
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    case "$ref" in
      /*) # Absolute. Encode spaces; other reserved characters are not
          # handled, which is fine for the filenames in use today.
          expect_status "${ref// /%20}" 200 ;;
      *)  bad "$p references '$ref' relatively (use an absolute /assets/... path)" ;;
    esac
  done <<EOF
$refs
EOF
done

echo "== partials are not directly reachable =="
for p in $PARTIALS; do expect_status "$p" 404; done
expect_status "/_old.html" 404
expect_status "/_probe-does-not-exist" 404

echo "== outbound links resolve =="
if [ "${SKIP_NETWORK:-0}" = "1" ]; then
  echo "  skipped (SKIP_NETWORK=1)"
else
  for url in https://lokkate.com https://liveonforever.com; do
    got="$(status_follow "$url")"
    case "$got" in
      2*|3*) ok "$url -> $got" ;;
      *)     bad "$url -> got $got" ;;
    esac
  done
fi

echo
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" -eq 0 ]
