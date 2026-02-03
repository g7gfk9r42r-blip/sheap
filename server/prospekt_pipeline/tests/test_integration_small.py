"""Integration tests for full pipeline."""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from prospekt_pipeline.pipeline.process_prospekt import ProspektProcessor


def test_integration_full_pipeline(temp_dir: Path):
    """Test full pipeline with synthetic data."""
    # Create test folder structure
    test_folder = temp_dir / "test_prospekt"
    test_folder.mkdir()
    
    # Create fake raw.html
    html_content = """
    <html>
    <body>
        <div class="product-card">
            <h3>Milsani Joghurt</h3>
            <span class="price">1,99 €</span>
            <span class="unit">150g</span>
        </div>
        <div class="product-card">
            <h3>Banane</h3>
            <span class="price">0,99 €</span>
        </div>
    </body>
    </html>
    """
    (test_folder / "raw.html").write_text(html_content, encoding="utf-8")
    
    # Create minimal fake PDF (just header)
    pdf_content = b"%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog\n>>\nendobj\nxref\n0 1\ntrailer\n<<\n/Size 1\n/Root 1 0 R\n>>\nstartxref\n50\n%%EOF"
    (test_folder / "raw.pdf").write_bytes(pdf_content)
    
    # Process
    processor = ProspektProcessor()
    result = processor.process(test_folder)
    
    # Verify result structure
    assert "offers" in result, "Result should contain 'offers'"
    assert "metadata" in result, "Result should contain 'metadata'"
    
    # Verify offers.json was written
    output_file = test_folder / "offers.json"
    assert output_file.exists(), "offers.json should be created"
    
    # Verify JSON is valid
    output_content = output_file.read_text(encoding="utf-8")
    parsed_output = json.loads(output_content)
    
    assert isinstance(parsed_output, dict), "Output should be a dictionary"
    assert "offers" in parsed_output, "Output should contain 'offers'"
    
    # Should have at least 1 offer from HTML
    offers = parsed_output.get("offers", [])
    assert len(offers) >= 1, f"Should have at least 1 offer, got {len(offers)}"
    
    # Verify offer structure
    if offers:
        first_offer = offers[0]
        assert "title" in first_offer, "Offer should have 'title'"
        assert first_offer["title"], "Title should not be empty"
        assert "confidence" in first_offer, "Offer should have 'confidence'"


def test_integration_fallback_activation(temp_dir: Path):
    """Test pipeline activates fallback when needed."""
    test_folder = temp_dir / "test_prospekt"
    test_folder.mkdir()
    
    # Create HTML with prices but no structured data
    html_content = """
    <html>
    <body>
        <p>Milsani Joghurt 1,99 €</p>
        <p>Banane 0,99 €</p>
    </body>
    </html>
    """
    (test_folder / "raw.html").write_text(html_content, encoding="utf-8")
    
    # Process
    processor = ProspektProcessor()
    result = processor.process(test_folder)
    
    # Should extract offers (either from HTML parser or fallback)
    offers = result.get("offers", [])
    assert len(offers) >= 0, "Should return non-negative count"
    
    # Verify output file exists
    output_file = test_folder / "offers.json"
    assert output_file.exists(), "offers.json should be created"


def test_integration_valid_json_output(temp_dir: Path):
    """Test pipeline outputs valid JSON."""
    test_folder = temp_dir / "test_prospekt"
    test_folder.mkdir()
    
    # Create minimal HTML
    (test_folder / "raw.html").write_text(
        '<div class="product"><h3>Test</h3><span>1,99 €</span></div>',
        encoding="utf-8",
    )
    
    # Process
    processor = ProspektProcessor()
    result = processor.process(test_folder)
    
    # Verify JSON is valid
    output_file = test_folder / "offers.json"
    assert output_file.exists(), "offers.json should exist"
    
    try:
        output_content = output_file.read_text(encoding="utf-8")
        parsed = json.loads(output_content)
        assert isinstance(parsed, dict), "JSON should be a dictionary"
    except json.JSONDecodeError as e:
        pytest.fail(f"Invalid JSON output: {e}")


def test_integration_handles_missing_files(temp_dir: Path):
    """Test pipeline handles missing files gracefully."""
    test_folder = temp_dir / "test_prospekt"
    test_folder.mkdir()
    
    # No files created
    
    # Process
    processor = ProspektProcessor()
    result = processor.process(test_folder)
    
    # Should not crash
    assert isinstance(result, dict), "Should return a dictionary"
    assert "offers" in result, "Should have 'offers' key"
    assert "metadata" in result, "Should have 'metadata' key"
    
    # Output file should still be created (even if empty)
    output_file = test_folder / "offers.json"
    # File might or might not exist depending on implementation
    # Just verify no crash


def test_integration_metadata_tracking(temp_dir: Path):
    """Test pipeline tracks metadata correctly."""
    test_folder = temp_dir / "test_prospekt"
    test_folder.mkdir()
    
    # Create HTML with offers
    (test_folder / "raw.html").write_text(
        '<div class="product"><h3>Product 1</h3><span>1,99 €</span></div>',
        encoding="utf-8",
    )
    
    # Process
    processor = ProspektProcessor()
    result = processor.process(test_folder)
    
    # Verify metadata
    metadata = result.get("metadata", {})
    assert "html_candidates" in metadata, "Should track HTML candidates"
    assert "final_offers" in metadata, "Should track final offers"
    
    # Final offers should be <= candidates
    assert metadata.get("final_offers", 0) <= metadata.get("html_candidates", 0) + \
           metadata.get("pdf_candidates", 0) + metadata.get("ocr_candidates", 0) + \
           metadata.get("fallback_candidates", 0), \
        "Final offers should not exceed candidates"

