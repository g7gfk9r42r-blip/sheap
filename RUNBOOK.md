# RUNBOOK - Terminal Commands (ohne # Kommentare)

python3 tools/promote_weekly_to_canonical.py

python3 tools/repair_recipes.py

python3 tools/validate_recipes.py --strict-count --repair-before-validate

python3 tools/build_offline_assets.py --fill-missing-with-placeholder --only-allowed-markets

./tools/switch_week.sh 2026-W01

flutter pub get

flutter clean

flutter run
