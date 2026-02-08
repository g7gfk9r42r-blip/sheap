# Installation Guide

## Requirements

Python 3.8+

## Install Dependencies

```bash
# Using pip
pip install -r requirements.txt

# Or using pip3
pip3 install -r requirements.txt

# If you get permission errors, use virtual environment:
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

## Verify Installation

```bash
python3 -c "import pdfminer; import requests; print('✅ All dependencies installed')"
```

## Run Tests

```bash
# Single supermarket
python3 test_single.py biomarkt

# All supermarkets
python3 test_all_supermarkets.py
```

