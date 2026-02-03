# Prospekt Pipeline - Ultra-Robust Supermarket Flyer Parser

A fully self-healing, modular parsing pipeline for supermarket prospekt (flyer) extraction. This system **always** produces valid `offers.json` files, even when input data is incomplete, broken, or messy.

## 🎯 Core Philosophy

**Error tolerance is priority #1.** The system never crashes and always produces output, even if it's an empty offers list with detailed error metadata.

## 📁 Architecture

```
prospekt_pipeline/
├── parsers/           # Extraction modules
│   ├── html_parser.py      # BeautifulSoup-based HTML parsing (confidence: 0.85-1.0)
│   ├── pdf_parser.py       # pdfminer text extraction (confidence: 0.50-0.80)
│   ├── ocr_parser.py       # pytesseract OCR fallback (confidence: 0.20-0.50)
│   └── fallback_parser.py  # Last-resort heuristics (confidence: 0.0-0.25)
├── pipeline/         # Orchestration
│   ├── process_prospekt.py  # Main processor (never crashes)
│   ├── merge_results.py     # Deduplication & merging
│   ├── normalize.py         # Data normalization
│   └── validate.py  # Input validation
├── utils/            # Shared utilities
│   ├── logger.py           # Custom logging with FALLBACK level
│   ├── exceptions.py        # Exception hierarchy
│   ├── file_loader.py      # Safe file I/O
│   ├── ocr_cleaner.py      # OCR text cleaning
│   └── brand_heuristics.json # Brand recognition rules
├── cli/              # Command-line interface
│   └── run_parser.py        # Main entry point
└── tests/            # Comprehensive test suite
    ├── test_html_parser.py
    ├── test_pdf_parser.py
    ├── test_ocr_parser.py
    ├── test_fallback_parser.py
    ├── test_merge.py
    ├── test_normalize.py
    ├── test_process_integration.py
    └── test_confidence_scores.py
```

## 🚀 Quick Start

### Installation

```bash
pip install beautifulsoup4 pdfminer.six pdf2image pillow pytesseract
```

### Usage

```bash
# Process all prospekt folders recursively
python -m prospekt_pipeline.cli.run_parser --base media/prospekte

# Process a single folder
python -m prospekt_pipeline.cli.run_parser --folder media/prospekte/edeka/berlin

# With custom log level
python -m prospekt_pipeline.cli.run_parser --base media/prospekte --log-level DEBUG
```

### Expected Folder Structure

```
media/prospekte/
├── edeka/
│   ├── berlin/
│   │   ├── raw.html
│   │   ├── raw.pdf
│   │   └── offers.json  (generated)
│   └── münchen/
│       ├── raw.html
│       ├── raw.pdf
│       └── offers.json  (generated)
└── lidl/
    └── ...
```

## 🔄 Processing Pipeline

1. **Validate Sources** - Check HTML/PDF availability and quality
2. **HTML Parsing** - Primary extraction (highest confidence)
3. **PDF Parsing** - Fallback if HTML missing/incomplete
4. **OCR Parsing** - If PDF text extraction fails
5. **Fallback Parsing** - Last-resort text scavenging
6. **Merge Results** - Deduplicate and combine all sources
7. **Normalize** - Clean and standardize data
8. **Write JSON** - Always produces valid output

## 📊 Output Format

```json
{
  "metadata": {
    "folder": "media/prospekte/edeka/berlin",
    "html_candidates": 45,
    "pdf_candidates": 42,
    "ocr_candidates": 8,
    "fallback_candidates": 0,
    "final_offers": 38
  },
  "offers": [
    {
      "title": "test kaffee",
      "price": 4.99,
      "unit_price": 9.98,
      "confidence": 0.95,
      "source": "html"
    }
  ]
}
```

## 🛡️ Error Handling

- **HTML parsing fails** → Falls back to PDF
- **PDF parsing fails** → Falls back to OCR
- **OCR fails** → Falls back to text scavenging
- **All parsers fail** → Writes empty `offers.json` with error metadata
- **File I/O errors** → Logged, processing continues
- **Invalid data** → Normalized to safe defaults

## 🧪 Testing

```bash
# Run all tests
pytest prospekt_pipeline/tests/

# Run specific test
pytest prospekt_pipeline/tests/test_html_parser.py

# With coverage
pytest prospekt_pipeline/tests/ --cov=prospekt_pipeline
```

## 📝 Confidence Scores

- **HTML Parser**: 0.85-1.0 (structured data, highest reliability)
- **PDF Parser**: 0.50-0.80 (text extraction, medium reliability)
- **OCR Parser**: 0.20-0.50 (image recognition, lower reliability)
- **Fallback Parser**: 0.0-0.25 (heuristic matching, lowest reliability)

## 🔧 Configuration

### Brand Heuristics

Edit `utils/brand_heuristics.json` to add known brands and weak suffixes:

```json
{
  "brands": ["coca cola", "milka", "lindt"],
  "weak_suffixes": ["original", "classic", "medium"]
}
```

### Logging

The logger supports custom `FALLBACK` level (25) for fallback operations:

```python
from prospekt_pipeline.utils.logger import get_logger
logger = get_logger("my_module")
logger.fallback("Using fallback parser")
```

## 🎓 Key Features

- ✅ **Never crashes** - All exceptions caught and logged
- ✅ **Always produces JSON** - Even if empty
- ✅ **Self-healing** - Automatically tries fallbacks
- ✅ **Deduplication** - Fuzzy matching prevents duplicates
- ✅ **Confidence scoring** - Tracks data quality
- ✅ **Comprehensive logging** - INFO, WARNING, FALLBACK, ERROR
- ✅ **Type-annotated** - Full type hints for Python 3.11+
- ✅ **Tested** - Comprehensive test suite

## 📚 Module Documentation

### Parsers

- **html_parser.py**: Extracts structured data from HTML using BeautifulSoup
- **pdf_parser.py**: Extracts text from PDF using pdfminer
- **ocr_parser.py**: OCR fallback using pytesseract with preprocessing
- **fallback_parser.py**: Last-resort text pattern matching

### Pipeline

- **process_prospekt.py**: Main orchestrator (never crashes)
- **merge_results.py**: Deduplicates and merges parser outputs
- **normalize.py**: Cleans and standardizes offer data
- **validate.py**: Validates input files before processing

### Utils

- **logger.py**: Custom logging with FALLBACK level
- **exceptions.py**: Exception hierarchy
- **file_loader.py**: Safe file I/O operations
- **ocr_cleaner.py**: OCR text cleaning utilities

## 🐛 Troubleshooting

### No offers extracted

- Check logs for parser errors
- Verify HTML/PDF files are valid
- Try increasing OCR preprocessing quality
- Check brand_heuristics.json configuration

### Low confidence scores

- HTML parser preferred over PDF/OCR
- Missing prices reduce confidence
- Unit prices increase confidence
- Fallback parser has lowest confidence

### Processing slow

- OCR is the slowest step (only runs when needed)
- PDF parsing is faster than OCR
- HTML parsing is fastest
- Consider processing folders in parallel

## 📄 License

Internal project - All rights reserved.

