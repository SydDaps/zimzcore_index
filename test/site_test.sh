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
  expect_absent "$p" '0+ '
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
