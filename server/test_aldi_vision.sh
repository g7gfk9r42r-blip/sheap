#!/bin/bash
# Quick test script for ALDI Nord Vision AI

echo "🧪 Testing ALDI Nord Vision AI with Reference Baseline"
echo "=================================================="
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ .env file not found"
    echo "   Please create .env with OPENAI_API_KEY=..."
    exit 1
fi

# Run test
python3 -m prospekt_pipeline.aldi_nord.test_vision_reference

