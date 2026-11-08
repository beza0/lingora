#!/usr/bin/env bash
# Vercel derlemesi: Flutter'ı indirir, testleri çalıştırır, web sürümünü build/web klasörüne derler.
# Gerekli ortam değişkenleri (Vercel → Settings → Environment Variables): SUPABASE_URL, SUPABASE_ANON_KEY (publishable, gizli değil).
set -euo pipefail
cd "$(dirname "$0")/.."

FLUTTER_DIR="${HOME}/flutter"
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "==> Flutter (stable) indiriliyor"
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
export CI=true
flutter --version
flutter config --no-analytics >/dev/null
flutter config --enable-web >/dev/null

echo "==> Bağımlılıklar"
flutter pub get

echo "==> Statik analiz"
flutter analyze --no-fatal-infos --no-fatal-warnings || { echo "ANALİZ HATASI"; exit 1; }

echo "==> Testler"
flutter test --reporter expanded

echo "==> drift web dosyaları"
lock_version() { awk -v pkg="$1" '$0 ~ "^  "pkg":$" {f=1} f && /version:/ {gsub(/"/,"",$2); print $2; exit}' pubspec.lock; }
SQLITE_VER="$(lock_version sqlite3)"
DRIFT_VER="$(lock_version drift)"
echo "sqlite3 $SQLITE_VER · drift $DRIFT_VER"
curl -fsSL -o web/sqlite3.wasm "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-${SQLITE_VER}/sqlite3.wasm" || echo "UYARI: sqlite3.wasm indirilemedi (uygulama bellek içi depoya düşer)"
curl -fsSL -o web/drift_worker.js "https://github.com/simolus3/drift/releases/download/drift-${DRIFT_VER}/drift_worker.js" || echo "UYARI: drift_worker.js indirilemedi"

echo "==> Web derlemesi"
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
  --dart-define=AUTH_REDIRECT="${AUTH_REDIRECT:-}"

echo "==> Tamam"
ls -la build/web | head -30
