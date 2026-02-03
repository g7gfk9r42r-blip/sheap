#!/bin/bash
# Test runner for prospekt_pipeline
# Automatically detects and uses the correct Python environment

set -e

cd "$(dirname "$0")/.."

printf "🧪 Running prospekt_pipeline tests...\n\n"

# Try venv first (most reliable)
if [ -d "crawl4ai_env" ]; then
    printf "✅ Using pytest from venv\n"
    crawl4ai_env/bin/python -m pytest prospekt_pipeline/tests/ -v
    exit $?
fi

# Try system python with pytest
if python3 -m pytest --version &> /dev/null 2>&1; then
    printf "✅ Using pytest from system Python\n"
    python3 -m pytest prospekt_pipeline/tests/ -v
    exit $?
fi

# Fallback: basic import test
printf "⚠️  pytest not found, running basic import tests...\n"
python3 << 'PYEOF'
import sys
sys.path.insert(0, '.')

errors = []
try:
    from prospekt_pipeline.utils.logger import setup_logger
    print("✅ Logger import works")
except Exception as e:
    errors.append(f"Logger: {e}")

try:
    from prospekt_pipeline.pipeline.normalize import Normalizer
    print("✅ Normalizer import works")
except Exception as e:
    errors.append(f"Normalizer: {e}")

try:
    from prospekt_pipeline.parsers.pdf_parser import PdfParser
    print("✅ PDF parser import works")
except Exception as e:
    errors.append(f"PDF parser: {e}")

if errors:
    print("\n❌ Import errors:")
    for err in errors:
        print(f"   {err}")
    sys.exit(1)

print("\n✅ All basic imports successful!")
print("💡 Install dependencies: pip install -r prospekt_pipeline/requirements.txt")
print("💡 Then run: python3 -m pytest prospekt_pipeline/tests/")
PYEOF
