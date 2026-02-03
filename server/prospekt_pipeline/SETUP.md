# Setup Guide

## Installation

```bash
# Install all dependencies
pip install -r prospekt_pipeline/requirements.txt

# For testing (optional)
pip install pytest pytest-cov
```

## Quick Test

```bash
# Test logger fix
python3 -c "from prospekt_pipeline.utils.logger import setup_logger; import logging; setup_logger(level=logging.INFO); print('✅ Logger works')"

# Test CLI
python3 -m prospekt_pipeline.cli.run_parser --help
```

## Running Tests

### Option 1: Using the test runner script (recommended)
```bash
./prospekt_pipeline/run_tests.sh
```

### Option 2: Using pytest directly
```bash
# Make sure you're in the virtual environment
source crawl4ai_env/bin/activate  # or your venv

# Install pytest if needed
pip install pytest

# Run all tests
python3 -m pytest prospekt_pipeline/tests/ -v

# Or if pytest is in PATH
pytest prospekt_pipeline/tests/ -v

# Run specific test
python3 -m pytest prospekt_pipeline/tests/test_html_parser.py -v
```

### Option 3: Without pytest (basic import test)
```bash
python3 prospekt_pipeline/run_tests.sh
```

## Common Issues

### "command not found: pytest"
Solution: Install pytest
```bash
pip install pytest
```

### Logger AttributeError
✅ **FIXED** - Logger now handles both int and string levels

### Import errors
Make sure you're in the `server/` directory and all dependencies are installed:
```bash
cd server
pip install -r prospekt_pipeline/requirements.txt
```

