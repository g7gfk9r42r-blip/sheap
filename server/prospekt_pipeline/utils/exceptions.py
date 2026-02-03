"""Custom exception hierarchy for the prospekt pipeline."""

class ProspektError(Exception):
    """Base exception for the system."""


class ValidationError(ProspektError):
    """Raised when required source files are missing or corrupt."""


class HtmlParsingError(ProspektError):
    """Raised when HTML parsing fails irrecoverably."""


class PdfParsingError(ProspektError):
    """Raised when structured PDF extraction fails."""


class OcrError(ProspektError):
    """Raised when OCR extraction fails."""


class NormalizationError(ProspektError):
    """Raised when output normalization cannot proceed."""
