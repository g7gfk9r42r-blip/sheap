"""LLM-based offer classification and cleaning"""
import json
import requests
import os
from typing import Dict, List, Optional
from ..utils.retry import retry_on_failure


class OfferLLMCleaner:
    """Use LLM to classify and clean uncertain offers"""
    
    def __init__(self, api_key: Optional[str] = None, model: str = "gpt-4.1-mini"):
        self.api_key = api_key or os.getenv("OPENAI_API_KEY")
        self.model = model
        self.base_url = "https://api.openai.com/v1/chat/completions"
    
    @retry_on_failure(max_retries=2, delay=1.0)
    def classify_batch(self, candidates: List[Dict]) -> List[Dict]:
        """
        Classify batch of uncertain candidates
        
        Returns updated candidates with is_food and confidence
        """
        if not self.api_key:
            return candidates  # Skip LLM if no API key
        
        # Build prompt
        items_text = "\n".join([
            f"{i+1}. {c['title']} - {c['price_now']}€"
            for i, c in enumerate(candidates[:20])  # Max 20 at once
        ])
        
        prompt = f"""Classify each item as FOOD or NON-FOOD. Return only JSON array.

Items:
{items_text}

Output format:
[
  {{"index": 1, "is_food": true, "confidence": 0.9}},
  ...
]"""
        
        try:
            response = requests.post(
                self.base_url,
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": self.model,
                    "messages": [
                        {"role": "system", "content": "You are a food classification expert. Return only valid JSON."},
                        {"role": "user", "content": prompt}
                    ],
                    "temperature": 0.3,
                    "max_tokens": 1000
                },
                timeout=30
            )
            response.raise_for_status()
            
            content = response.json()['choices'][0]['message']['content']
            
            # Parse JSON response
            # Remove markdown if present
            if '```' in content:
                content = content.split('```')[1]
                if content.startswith('json'):
                    content = content[4:]
            
            classifications = json.loads(content.strip())
            
            # Update candidates
            for classification in classifications:
                idx = classification['index'] - 1
                if 0 <= idx < len(candidates):
                    candidates[idx]['is_food'] = classification['is_food']
                    candidates[idx]['confidence'] = max(candidates[idx]['confidence'], classification['confidence'])
            
        except Exception as e:
            print(f"LLM classification failed: {e}")
            # Keep original classifications
        
        return candidates

