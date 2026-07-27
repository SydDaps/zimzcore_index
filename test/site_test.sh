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

# -L so a redirect to the canonical host is not reported as a broken link.
status() { curl -sSL -o /dev/null -w '%{http_code}' --max-time 10 "$1" 2>/dev/null; }
raw()    { curl -sS --max-time 10 "$1" 2>/dev/null; }

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

echo "== page contract: SSI assembly, contact, banned copy =="
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
done

echo "== partials are not directly reachable =="
for p in $PARTIALS; do expect_status "$p" 404; done
expect_status "/_old.html" 404
expect_status "/_probe-does-not-exist" 404

echo "== referenced assets resolve =="
assets="$(for p in $PAGES; do
  raw "$BASE$p" | grep -oE '(href|src)="[^"]*"' | sed 's/^[a-z]*="//; s/"$//'
done | grep -E '^/?assets/' | sed 's|^assets/|/assets/|' | sort -u)"

if [ -z "$assets" ]; then
  bad "no asset references found on any page"
else
  while IFS= read -r a; do
    [ -z "$a" ] && continue
    # Some image filenames contain spaces, so encode before requesting.
    expect_status "${a// /%20}" 200
  done <<EOF
$assets
EOF
fi

echo "== outbound links resolve =="
if [ "${SKIP_NETWORK:-0}" = "1" ]; then
  echo "  skipped (SKIP_NETWORK=1)"
else
  for url in https://lokkate.com https://liveonforever.com; do
    got="$(status "$url")"
    case "$got" in
      2*|3*) ok "$url -> $got" ;;
      *)     bad "$url -> got $got" ;;
    esac
  done
fi

echo
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" -eq 0 ]
