#!/bin/bash
# Test script for pipeline

set -e

echo "=========================================="
echo "Grocify Scraper - Full Test"
echo "=========================================="

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ python3 not found"
    exit 1
fi

# Check dependencies
echo "Checking dependencies..."
python3 -c "import pdfminer" 2>/dev/null || { echo "❌ pdfminer.six not installed"; exit 1; }
python3 -c "import requests" 2>/dev/null || { echo "❌ requests not installed"; exit 1; }
echo "✅ Dependencies OK"

# Run test
echo ""
echo "Running pipeline test on all supermarkets..."
python3 test_all_supermarkets.py --week-key 2025-W52

echo ""
echo "=========================================="
echo "Test completed. Check out/reports/ for results."
echo "=========================================="

