#!/usr/bin/env bash
set -euo pipefail
API_BASE_URL="${API_BASE_URL:-http://localhost:3000}"
ADMIN_SECRET="${ADMIN_SECRET:-changeme}"

green() { printf "\033[32m%s\033[0m\n" "$1"; }
red()   { printf "\033[31m%s\033[0m\n" "$1"; }

fail() { red "❌ $1"; exit 1; }

echo "→ Health check..."
HEALTH=$(curl -fsS "$API_BASE_URL/healthz" || fail "healthz unreachable")
echo "$HEALTH" | grep -q '"ok":true' || fail "healthz not ok"
green "✅ /healthz ok"

echo "→ Admin refresh offers..."
REFRESH_OFFERS=$(curl -fsS -X POST "$API_BASE_URL/admin/refresh-offers" \
  -H "x-admin-secret: $ADMIN_SECRET" \
  -H "Content-Type: application/json" || fail "offers refresh failed")
echo "$REFRESH_OFFERS" | grep -q '"weekKey":' || fail "offers refresh no weekKey"
echo "$REFRESH_OFFERS" | grep -q '"totals":' || fail "offers refresh no totals"
green "✅ offers refresh ok"

echo "→ Admin refresh recipes..."
REFRESH_RECIPES=$(curl -fsS -X POST "$API_BASE_URL/admin/refresh-recipes" \
  -H "x-admin-secret: $ADMIN_SECRET" \
  -H "Content-Type: application/json" || fail "recipes refresh failed")
echo "$REFRESH_RECIPES" | grep -q '"weekKey":' || fail "recipes refresh no weekKey"
echo "$REFRESH_RECIPES" | grep -q '"totals":' || fail "recipes refresh no totals"
green "✅ recipes refresh ok"

echo "→ Fetch LIDL offers..."
OFFERS=$(curl -fsS "$API_BASE_URL/offers?retailer=LIDL" || fail "offers failed")
echo "$OFFERS" | grep -q '\[' || fail "offers not array"
green "✅ offers endpoint ok"

echo "→ Fetch recipes..."
RECIPES=$(curl -fsS "$API_BASE_URL/recipes" || fail "recipes failed")
echo "$RECIPES" | grep -q '\[' || fail "recipes not array"
echo "$RECIPES" | grep -q '"recipes":' || fail "recipes missing recipes field"
green "✅ recipes endpoint ok"

echo "→ Verify database persistence..."
if [ "$DB" = "sqlite" ] || [ -z "$DB" ]; then
  if [ -f "server/data/app.db" ]; then
    green "✅ SQLite database created"
  else
    red "❌ SQLite database not found"
    exit 1
  fi
else
  if [ -f "data/offers.json" ]; then
    green "✅ offers.json file created"
  else
    red "❌ offers.json file not found"
    exit 1
  fi
fi

green "🎉 Smoke success"