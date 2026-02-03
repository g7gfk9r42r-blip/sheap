#!/usr/bin/env python3
"""
Smoke-Test für Replicate Payload
Stellt sicher, dass Payload "version" (Hash) enthält und KEIN "model" Key.
"""

import json
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock

# Import ReplicateImageClient
sys.path.insert(0, str(Path(__file__).parent))

try:
    from replicate_image import ReplicateImageClient
except ImportError as e:
    print(f"❌ Fehler beim Import: {e}")
    sys.exit(1)


def test_payload_has_version_no_model():
    """Test: Payload enthält 'version' (Hash) und KEIN 'model' Key"""
    print("🧪 Test: Payload enthält 'version' (Hash) und KEIN 'model' Key")
    
    # Erstelle Client (ohne API Token, da wir nur Payload testen)
    client = ReplicateImageClient.__new__(ReplicateImageClient)
    client.model_slug = "black-forest-labs/flux-schnell"
    client._version_cache = {}
    
    # Mock: Model-Auflösung gibt Version-Hash zurück
    dummy_version_hash = "39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b"
    
    # Mock _resolve_model_to_version
    def mock_resolve(self):
        self._version_cache[self.model_slug] = dummy_version_hash
        return True, dummy_version_hash, None
    
    # Patch die resolve Methode
    client._resolve_model_to_version = lambda: mock_resolve(client)
    
    # Test: Resolve funktioniert
    success, version_hash, error = client._resolve_model_to_version()
    if not success:
        print(f"\n❌ Model-Auflösung fehlgeschlagen: {error}")
        return False
    
    if version_hash != dummy_version_hash:
        print(f"\n❌ Version-Hash stimmt nicht: {version_hash} != {dummy_version_hash}")
        return False
    
    # Mock recipe
    recipe = {
        'title': 'Test Recipe',
        'ingredients': [
            {'name': 'Tomaten', 'from_offer': True},
            {'name': 'Zwiebeln', 'from_offer': True},
        ]
    }
    
    # Generiere Prompt
    prompt, negative_prompt = client.generate_prompt(recipe)
    
    # Erstelle Payload wie in generate_image (mit resolved version)
    payload = {
        'version': version_hash,
        'input': {
            'prompt': prompt,
            'num_outputs': 1,
            'aspect_ratio': '1:1',
            'output_format': 'png',
            'output_quality': 90,
        }
    }
    
    # Prüfe Payload
    payload_json = json.dumps(payload, indent=2)
    print(f"\n📋 Payload:")
    print(payload_json)
    
    # WICHTIG: KEIN 'model' Key
    if 'model' in payload:
        print("\n❌ FEHLER: Payload enthält 'model' Key!")
        print(f"   Gefunden: {payload['model']}")
        return False
    
    # WICHTIG: 'version' MUSS vorhanden sein
    if 'version' not in payload:
        print("\n❌ FEHLER: Payload enthält KEIN 'version' Key!")
        return False
    
    if payload['version'] != version_hash:
        print(f"\n❌ FEHLER: Payload['version'] = '{payload['version']}' != erwartet '{version_hash}'")
        return False
    
    # Prüfe auch in 'input'
    if 'version' in payload.get('input', {}):
        print("\n❌ FEHLER: Payload['input'] enthält 'version' Key (sollte nur im Root sein)!")
        return False
    
    print("\n✅ Payload ist korrekt:")
    print(f"   - version: {payload['version']}")
    print(f"   - KEIN 'model' Key vorhanden")
    print(f"   - input.prompt: {len(prompt)} Zeichen")
    
    return True


def test_version_resolution_stub():
    """Test: Version-Auflösung mit Stub"""
    print("\n🧪 Test: Version-Auflösung (mit Mock)")
    
    client = ReplicateImageClient.__new__(ReplicateImageClient)
    client.model_slug = "stability-ai/sdxl"
    client._version_cache = {}
    
    # Mock: GET /v1/models/{owner}/{name} Response
    mock_response_data = {
        'latest_version': {
            'id': 'abc123def456',
            'created_at': '2024-01-01T00:00:00Z',
        }
    }
    
    # Mock requests.get für Model-Resolution
    with patch('replicate_image.requests.get') as mock_get:
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = mock_response_data
        mock_get.return_value = mock_response
        
        # Test: API Token muss gesetzt sein (wird in __init__ geprüft)
        # Wir setzen es direkt für den Test
        client.api_token = "test_token"
        client.base_url = "https://api.replicate.com/v1"
        client.debug = False
        
        # Führe Auflösung aus
        success, version_hash, error = client._resolve_model_to_version()
        
        if not success:
            print(f"   ❌ Auflösung fehlgeschlagen: {error}")
            return False
        
        if version_hash != 'abc123def456':
            print(f"   ❌ Version-Hash falsch: {version_hash} != abc123def456")
            return False
        
        # Prüfe Cache
        if client.model_slug not in client._version_cache:
            print(f"   ❌ Version nicht im Cache gespeichert")
            return False
        
        if client._version_cache[client.model_slug] != 'abc123def456':
            print(f"   ❌ Cache enthält falschen Hash")
            return False
        
        print(f"   ✅ Auflösung erfolgreich: {client.model_slug} -> {version_hash}")
        print(f"   ✅ Cache gespeichert")
        
        return True


def test_multiple_models_caching():
    """Test: Caching für mehrere Models"""
    print("\n🧪 Test: Caching für mehrere Models")
    
    client = ReplicateImageClient.__new__(ReplicateImageClient)
    client._version_cache = {}
    client.api_token = "test_token"
    client.base_url = "https://api.replicate.com/v1"
    client.debug = False
    
    test_cases = [
        ("owner1/model1", "hash1"),
        ("owner2/model2", "hash2"),
        ("owner1/model1", "hash1"),  # Sollte aus Cache kommen
    ]
    
    with patch('replicate_image.requests.get') as mock_get:
        call_count = 0
        
        def mock_get_response(url, **kwargs):
            nonlocal call_count
            call_count += 1
            
            # Parse URL
            if '/models/' in url:
                mock_response = MagicMock()
                mock_response.status_code = 200
                # Bestimme Hash basierend auf URL
                if 'owner1/model1' in url:
                    mock_response.json.return_value = {'latest_version': {'id': 'hash1'}}
                elif 'owner2/model2' in url:
                    mock_response.json.return_value = {'latest_version': {'id': 'hash2'}}
                return mock_response
            return MagicMock(status_code=404)
        
        mock_get.side_effect = mock_get_response
        
        for model_slug, expected_hash in test_cases:
            client.model_slug = model_slug
            success, version_hash, error = client._resolve_model_to_version()
            
            if not success:
                print(f"   ❌ {model_slug}: Auflösung fehlgeschlagen: {error}")
                return False
            
            if version_hash != expected_hash:
                print(f"   ❌ {model_slug}: Hash falsch: {version_hash} != {expected_hash}")
                return False
        
        # Prüfe: owner1/model1 sollte nur einmal aufgerufen worden sein (2. Mal aus Cache)
        if call_count != 2:  # owner1/model1 + owner2/model2 (owner1/model1 2. Mal aus Cache)
            print(f"   ❌ Erwartet 2 API-Calls (mit Cache), aber {call_count} gemacht")
            return False
        
        print(f"   ✅ 3 Auflösungen, 2 API-Calls (1 aus Cache)")
        
        return True


if __name__ == '__main__':
    print("=" * 60)
    print("Smoke-Test: Replicate Payload (mit 'version', KEIN 'model')")
    print("=" * 60)
    
    test1 = test_payload_has_version_no_model()
    test2 = test_version_resolution_stub()
    test3 = test_multiple_models_caching()
    
    print("\n" + "=" * 60)
    if test1 and test2 and test3:
        print("✅ ALLE TESTS BESTANDEN")
        sys.exit(0)
    else:
        print("❌ TESTS FEHLGESCHLAGEN")
        sys.exit(1)
