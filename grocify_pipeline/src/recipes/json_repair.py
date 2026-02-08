"""JSON repair utilities"""
import json
import re


def repair_json(text: str) -> str:
    """Attempt to repair malformed JSON"""
    
    # Remove markdown
    if '```' in text:
        parts = text.split('```')
        for part in parts:
            if part.strip().startswith('[') or part.strip().startswith('{'):
                text = part
                break
    
    # Remove 'json' label
    text = re.sub(r'^json\s*', '', text.strip())
    
    # Fix common issues
    # Trailing commas
    text = re.sub(r',(\s*[}\]])', r'\1', text)
    
    # Unescaped quotes in strings (simple heuristic)
    # This is risky, but can help in some cases
    
    return text.strip()


def validate_and_repair(text: str) -> tuple[bool, any]:
    """
    Validate JSON and attempt repair if needed
    
    Returns (success, parsed_data or error_msg)
    """
    try:
        data = json.loads(text)
        return True, data
    except json.JSONDecodeError as e:
        # Attempt repair
        repaired = repair_json(text)
        try:
            data = json.loads(repaired)
            return True, data
        except json.JSONDecodeError:
            return False, f"JSON repair failed: {e}"

