"""Integration test for full pipeline."""
import json
from pathlib import Path
from tempfile import TemporaryDirectory

from prospekt_pipeline.pipeline.process_prospekt import ProspektProcessor

SAMPLE_HTML = """
<html>
  <body>
    <article data-testid="offer-card">
      <div data-testid="offer-title">Test Kaffee</div>
      <span data-testid="price">4,99 €</span>
    </article>
  </body>
</html>
"""


def test_processor_creates_offers_json():
    processor = ProspektProcessor()
    with TemporaryDirectory() as tmp:
        folder = Path(tmp) / "supermarkt" / "stadt"
        folder.mkdir(parents=True)
        (folder / "raw.html").write_text(SAMPLE_HTML, encoding="utf-8")
        (folder / "raw.pdf").write_bytes(b"%PDF-1.4 test")

        result = processor.process(folder)
        assert result["offers"] is not None
        output = folder / "offers.json"
        assert output.exists()
        data = json.loads(output.read_text(encoding="utf-8"))
        assert "offers" in data
        assert "metadata" in data
