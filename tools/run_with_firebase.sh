#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

IOS_TARGET="${PROJECT_ROOT}/ios/Runner/GoogleService-Info.plist"
ANDROID_TARGET="${PROJECT_ROOT}/android/app/google-services.json"
LOCAL_IOS_PLIST="${PROJECT_ROOT}/firebase/Apple/GoogleService-Info.plist"
LOCAL_ANDROID_JSON="${PROJECT_ROOT}/firebase/Google/google-services.json"
ALT_LOCAL_IOS_PLIST="${PROJECT_ROOT}/apple/GoogleService_Info.plist"
ALT_LOCAL_IOS_PLIST2="${PROJECT_ROOT}/apple/GoogleService-Info.plist"
ALT_LOCAL_ANDROID_JSON="${PROJECT_ROOT}/google/google_services.json"

err() { echo "❌ $*" >&2; }
ok() { echo "✅ $*"; }
info() { echo "ℹ️ $*"; }

check_disk_space_or_die() {
  # Disk space guardrails:
  # - hard minimum (abort): 5GB
  # - recommended (warn below): 10GB
  #
  # You can override via env:
  #   export MIN_FREE_GB=5
  #   export RECOMMENDED_FREE_GB=10
  local min_gb="${MIN_FREE_GB:-5}"
  local rec_gb="${RECOMMENDED_FREE_GB:-10}"
  local min_kb=$((min_gb * 1024 * 1024))
  local rec_kb=$((rec_gb * 1024 * 1024))
  local avail_kb
  avail_kb="$(df -Pk "$PROJECT_ROOT" | awk 'NR==2 {print $4}')"
  if [[ -z "${avail_kb}" ]]; then
    info "Disk space check skipped (could not read df output)."
    return 0
  fi
  local avail_gb=$((avail_kb / 1024 / 1024))
  if [[ "${avail_kb}" -lt "${min_kb}" ]]; then
    err "Zu wenig freier Speicher für iOS Build: ${avail_gb}GB verfügbar, benötigt mindestens ~${min_gb}GB."
    err "Fix (Beispiele):"
    err "  - Xcode DerivedData löschen: rm -rf ~/Library/Developer/Xcode/DerivedData/*"
    err "  - Flutter build löschen: rm -rf $PROJECT_ROOT/build $PROJECT_ROOT/ios/build"
    err "  - iOS Simulator Cleanup: xcrun simctl delete unavailable"
    err "Danach erneut: ./tools/run_with_firebase.sh"
    exit 20
  fi
  if [[ "${avail_kb}" -lt "${rec_kb}" ]]; then
    info "Disk space LOW: ${avail_gb}GB frei (empfohlen ~${rec_gb}GB+). Build kann trotzdem klappen."
  else
    ok "Disk space OK: ${avail_gb}GB frei"
  fi
}

stat_mtime() {
  local f="$1"
  if stat -f %m "$f" >/dev/null 2>&1; then
    stat -f %m "$f"
  else
    stat -c %Y "$f"
  fi
}

is_plist_valid() {
  local plist="$1"
  plutil -p "$plist" >/dev/null 2>&1 || return 1
  plutil -p "$plist" | grep -q '"BUNDLE_ID"' || return 4
  plutil -p "$plist" | grep -q '"GOOGLE_APP_ID"' || return 5
  plutil -p "$plist" | grep -q '"PROJECT_ID"' || return 6
  plutil -p "$plist" | grep -q '"API_KEY"' || return 7
  return 0
}

plist_get_value() {
  local plist="$1"
  local key="$2"
  # plutil -p prints: "KEY" => "VALUE"
  plutil -p "$plist" 2>/dev/null | sed -n "s/^[[:space:]]*\"${key}\" => \"\\(.*\\)\"$/\\1/p" | head -n 1
}

expected_ios_bundle_id() {
  local pbxproj="${PROJECT_ROOT}/ios/Runner.xcodeproj/project.pbxproj"
  if [[ ! -f "$pbxproj" ]]; then
    echo ""
    return 0
  fi
  # Prefer Runner target bundle id (exclude RunnerTests)
  grep -E "PRODUCT_BUNDLE_IDENTIFIER = " "$pbxproj" \
    | grep -v "RunnerTests" \
    | head -n 1 \
    | sed -n 's/.*PRODUCT_BUNDLE_IDENTIFIER = \([^;]*\);.*/\1/p'
}

copy_overwrite() {
  local src="$1"
  local dst="$2"
  if [[ "$src" == "$dst" ]]; then
    info "Already in place: $dst"
    return 0
  fi
  cp -f "$src" "$dst"
}

pick_newest_plist() {
  local expected_bundle="${1:-}"
  shift || true
  local best=""
  local best_m=0

  for base in "$@"; do
    [[ -d "$base" ]] || continue
    while IFS= read -r -d '' f; do
      # Filter invalid/mismatching plists early
      if ! is_plist_valid "$f"; then
        continue
      fi
      if [[ -n "$expected_bundle" ]]; then
        local b
        b="$(plist_get_value "$f" "BUNDLE_ID")"
        if [[ "$b" != "$expected_bundle" ]]; then
          continue
        fi
      fi
      local m
      m="$(stat_mtime "$f" 2>/dev/null || echo 0)"
      if [[ -z "$best" || "$m" -gt "$best_m" ]]; then
        best="$f"
        best_m="$m"
      fi
    done < <(
      find "$base" -maxdepth 8 \
        \( \
          -path "*/build/*" -o \
          -path "*/ios/Pods/*" -o \
          -path "*/macos/Pods/*" -o \
          -path "*/DerivedData/*" -o \
          -path "*/CoreSimulator/*" -o \
          -path "*/.pub-cache/*" -o \
          -path "*/.cursor/*" -o \
          -path "*/.symlinks/*" -o \
          -path "*/.dart_tool/*" \
        \) -prune -o \
        -type f -name "GoogleService-Info*.plist" -print0 2>/dev/null || true
    )
  done

  echo "$best"
}

validate_or_die() {
  local plist="$1"
  local expected_bundle="${2:-}"
  if ! plutil -p "$plist" >/dev/null 2>&1; then
    err "Datei ist keine gültige plist: $plist"
    exit 2
  fi

  local bundle_id project_id google_app_id
  bundle_id="$(plist_get_value "$plist" "BUNDLE_ID")"
  project_id="$(plist_get_value "$plist" "PROJECT_ID")"
  google_app_id="$(plist_get_value "$plist" "GOOGLE_APP_ID")"

  if [[ -n "$expected_bundle" && "$bundle_id" != "$expected_bundle" ]]; then
    err "Falsche plist: BUNDLE_ID mismatch."
    err "  expected: $expected_bundle"
    err "  plist:     ${bundle_id:-"(missing)"}"
    err "Fix: Lade die korrekte iOS GoogleService-Info.plist aus der Firebase Console für genau diese Bundle ID."
    exit 5
  fi

  ok "plist vorhanden: $plist"
  ok "BUNDLE_ID: ${bundle_id:-"(missing)"}"
  ok "PROJECT_ID: ${project_id:-"(missing)"}"
  ok "GOOGLE_APP_ID: ${google_app_id:-"(missing)"}"

  # additional required keys check (fail with clear message)
  local missing=0
  for k in "API_KEY" "PROJECT_ID" "GOOGLE_APP_ID" "BUNDLE_ID"; do
    if ! plutil -p "$plist" | grep -q "\"${k}\""; then
      err "Key fehlt in plist: ${k}"
      missing=1
    fi
  done
  if [[ "$missing" -ne 0 ]]; then
    err "Diese plist ist unvollständig. Bitte erneut aus der Firebase Console laden."
    exit 4
  fi

  ok "keys vorhanden"

  if ! plutil -p "$plist" | grep -q '"CLIENT_ID"'; then
    info "CLIENT_ID fehlt (ok für Email/Passwort)"
  fi
  if ! plutil -p "$plist" | grep -q '"REVERSED_CLIENT_ID"'; then
    info "REVERSED_CLIENT_ID fehlt (ok für Email/Passwort)"
  fi
}

main() {
  if ! command -v plutil >/dev/null 2>&1; then
    err "plutil nicht gefunden. Das Script benötigt macOS plutil."
    exit 10
  fi

  check_disk_space_or_die

  # Web/Chrome modes
  # - RUN_WEB=1: Preview (no Firebase/Auth), always starts
  # - RUN_WEB_LOCAL_AUTH=1: Chrome with LOCAL auth (no Firebase Web keys required)
  # - RUN_WEB_AUTH=1: Chrome + Firebase Auth (requires FIREBASE_WEB_* in .env)
  if [[ "${RUN_WEB:-0}" == "1" ]]; then
    info "Mode: web (chrome) preview (no auth)"
    info "Running clean build..."
    cd "$PROJECT_ROOT"
    flutter clean
    flutter pub get
    info "Starting app on Chrome..."
    flutter run -d chrome --dart-define=WEB_PREVIEW_NO_AUTH=true --dart-define=WEB_LOCAL_AUTH=true
    exit 0
  fi
  if [[ "${RUN_WEB_LOCAL_AUTH:-0}" == "1" ]]; then
    info "Mode: web (chrome) LOCAL auth (no Firebase Web)"
    info "Running clean build..."
    cd "$PROJECT_ROOT"
    flutter clean
    flutter pub get
    info "Starting app on Chrome..."
    flutter run -d chrome --dart-define=WEB_PREVIEW_NO_AUTH=false --dart-define=WEB_LOCAL_AUTH=true
    exit 0
  fi
  if [[ "${RUN_WEB_AUTH:-0}" == "1" || "${RUN_DEVICE:-}" == "chrome" ]]; then
    info "Mode: web (chrome) WITH Firebase Auth"
    if [[ ! -f "${PROJECT_ROOT}/.env" ]]; then
      err "Missing .env at ${PROJECT_ROOT}/.env"
      err "Fix: add FIREBASE_WEB_API_KEY, FIREBASE_WEB_APP_ID, FIREBASE_WEB_MESSAGING_SENDER_ID, FIREBASE_WEB_PROJECT_ID, FIREBASE_WEB_AUTH_DOMAIN"
      exit 31
    fi
    for k in FIREBASE_WEB_API_KEY FIREBASE_WEB_APP_ID FIREBASE_WEB_MESSAGING_SENDER_ID FIREBASE_WEB_PROJECT_ID FIREBASE_WEB_AUTH_DOMAIN; do
      if ! grep -q "^${k}=" "${PROJECT_ROOT}/.env"; then
        err "Missing ${k} in .env (Firebase Web config)."
        exit 32
      fi
    done
    info "Running clean build..."
    cd "$PROJECT_ROOT"
    flutter clean
    flutter pub get
    info "Starting app on Chrome..."
    flutter run -d chrome --dart-define=WEB_PREVIEW_NO_AUTH=false
    exit 0
  fi

  local expected_bundle
  expected_bundle="$(expected_ios_bundle_id || true)"
  if [[ -n "$expected_bundle" ]]; then
    info "Expected iOS BUNDLE_ID: $expected_bundle"
  else
    info "Expected iOS BUNDLE_ID: (unknown)"
  fi

  # Android config: prefer local folder firebase/Google/google-services.json
  if [[ -f "$LOCAL_ANDROID_JSON" ]]; then
    mkdir -p "$(dirname "$ANDROID_TARGET")"
    cp -f "$LOCAL_ANDROID_JSON" "$ANDROID_TARGET"
    ok "Copied → $ANDROID_TARGET"
  elif [[ -f "$ALT_LOCAL_ANDROID_JSON" ]]; then
    mkdir -p "$(dirname "$ANDROID_TARGET")"
    cp -f "$ALT_LOCAL_ANDROID_JSON" "$ANDROID_TARGET"
    ok "Copied → $ANDROID_TARGET"
  fi
  if [[ -f "$ANDROID_TARGET" ]]; then
    ok "Android google-services.json vorhanden"
  else
    info "Android google-services.json fehlt. Lege sie hier ab:"
    info "  $LOCAL_ANDROID_JSON"
    info "  (oder alternativ) $ALT_LOCAL_ANDROID_JSON"
  fi

  local plist=""
  if [[ -n "${GOOGLE_SERVICE_PLIST:-}" ]]; then
    plist="$GOOGLE_SERVICE_PLIST"
    if [[ ! -f "$plist" ]]; then
      err "GOOGLE_SERVICE_PLIST zeigt auf keine Datei: $plist"
      exit 11
    fi
    info "Using GOOGLE_SERVICE_PLIST=$plist"
  elif [[ -f "$LOCAL_IOS_PLIST" ]]; then
    plist="$LOCAL_IOS_PLIST"
    info "Using local iOS plist: $plist"
  elif [[ -f "$ALT_LOCAL_IOS_PLIST2" ]]; then
    plist="$ALT_LOCAL_IOS_PLIST2"
    info "Using local iOS plist: $plist"
  elif [[ -f "$ALT_LOCAL_IOS_PLIST" ]]; then
    plist="$ALT_LOCAL_IOS_PLIST"
    info "Using local iOS plist: $plist"
  else
    plist="$(pick_newest_plist \
      "$expected_bundle" \
      "$PROJECT_ROOT" \
      "$HOME/Downloads" \
      "$HOME/Desktop" \
      "$HOME/Documents")"
    if [[ -z "$plist" || ! -f "$plist" ]]; then
      err "Keine passende GoogleService-Info.plist gefunden (BUNDLE_ID muss zu iOS Runner passen)."
      err "Lege sie hier ab:"
      err "  $LOCAL_IOS_PLIST"
      err "  (oder alternativ) $ALT_LOCAL_IOS_PLIST"
      err "Setze sie ab jetzt so:"
      err "  export GOOGLE_SERVICE_PLIST='/voller/pfad/GoogleService-Info.plist'"
      err "und starte erneut."
      exit 12
    fi
  fi

  validate_or_die "$plist" "$expected_bundle"

  mkdir -p "$(dirname "$IOS_TARGET")"
  copy_overwrite "$plist" "$IOS_TARGET"
  ok "Copied → $IOS_TARGET"

  validate_or_die "$IOS_TARGET" "$expected_bundle"

  # Prefer iOS simulator/device (avoid accidentally running on Chrome/web).
  local device_id=""
  if [[ -n "${RUN_DEVICE:-}" ]]; then
    device_id="$RUN_DEVICE"
    info "Using RUN_DEVICE=$device_id"
  else
    if command -v python3 >/dev/null 2>&1; then
      # NOTE: don't pipe flutter output into a process that may exit early (can cause "Broken pipe").
      local devices_json
      devices_json="$(flutter devices --machine 2>/dev/null || true)"
      device_id="$(python3 -c "import json,sys\ns=sys.argv[1] if len(sys.argv)>1 else ''\ntry:\n devs=json.loads(s) if s.strip() else []\nexcept Exception:\n devs=[]\n# Prefer iOS simulator\nfor d in devs:\n if d.get('platform')=='ios' and d.get('emulator'):\n  print(d.get('id',''))\n  sys.exit(0)\n# fallback: any iOS device\nfor d in devs:\n if d.get('platform')=='ios':\n  print(d.get('id',''))\n  sys.exit(0)\nprint('')\n" "$devices_json" 2>/dev/null)" || true
    fi
  fi

  if [[ -z "$device_id" ]]; then
    err "Kein iOS Simulator/Device gefunden. Aktuell würde Flutter sonst auf Chrome/web ausweichen (Firebase init fail)."
    err "Fix:"
    err "  1) open -a Simulator"
    err "  2) flutter devices"
    err "  3) dann erneut: ./tools/run_with_firebase.sh"
    err "Optional: RUN_DEVICE setzen:"
    err "  export RUN_DEVICE='<device-id>'"
    exit 30
  fi

  info "Running clean build..."
  cd "$PROJECT_ROOT"
  flutter clean
  flutter pub get

  info "Installing iOS pods..."
  cd ios
  pod install --repo-update
  cd "$PROJECT_ROOT"

  # Pod install and Xcode can consume a lot of space; re-check before the heavy build.
  check_disk_space_or_die

  info "Starting app..."
  flutter run -d "$device_id"
}

main "$@"


