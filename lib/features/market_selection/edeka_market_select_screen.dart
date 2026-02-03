import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// EDEKA Market Selection Screen
/// 
/// Ermöglicht dem Nutzer:
/// 1. PLZ eingeben
/// 2. EDEKA-Märkte in der Nähe anzeigen
/// 3. Markt auswählen und speichern
/// 4. Zurück zum Hauptbildschirm
class EdekaMarketSelectScreen extends StatefulWidget {
  const EdekaMarketSelectScreen({super.key});

  @override
  State<EdekaMarketSelectScreen> createState() => _EdekaMarketSelectScreenState();
}

class _EdekaMarketSelectScreenState extends State<EdekaMarketSelectScreen> {
  final TextEditingController _plzController = TextEditingController();
  final String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  List<EdekaMarket> _markets = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _plzController.dispose();
    super.dispose();
  }

  Future<void> _searchMarkets() async {
    final plz = _plzController.text.trim();
    
    if (plz.isEmpty || !RegExp(r'^\d{5}$').hasMatch(plz)) {
      setState(() {
        _error = 'Bitte geben Sie eine gültige 5-stellige PLZ ein.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _markets = [];
    });

    try {
      final uri = Uri.parse('$baseUrl/edeka/markets?plz=$plz');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body);
      final marketsList = (data['markets'] as List?)
          ?.map((m) => EdekaMarket.fromJson(m as Map<String, dynamic>))
          .toList() ?? [];

      setState(() {
        _markets = marketsList;
        _loading = false;
        if (_markets.isEmpty) {
          _error = 'Keine EDEKA-Märkte in der Nähe gefunden.';
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Fehler beim Laden der Märkte: ${e.toString()}';
        _loading = false;
      });
    }
  }

  Future<void> _saveMarket(EdekaMarket market) async {
    try {
      final uri = Uri.parse('$baseUrl/edeka/markets');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': market.id,
          'name': market.name,
          'address': market.address != null
              ? {
                  'street': market.address!['street'],
                }
              : null,
          'zipCode': market.address?['zipCode'],
          'city': market.address?['city'],
          'coordinates': market.coordinates != null
              ? {
                  'latitude': market.coordinates!['latitude'],
                  'longitude': market.coordinates!['longitude'],
                }
              : null,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Markt "${market.name}" gespeichert!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Zurück zum Hauptbildschirm
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EDEKA-Markt auswählen'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PLZ-Eingabe
            TextField(
              controller: _plzController,
              decoration: InputDecoration(
                labelText: 'Postleitzahl',
                hintText: '80331',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _loading ? null : _searchMarkets,
                ),
              ),
              keyboardType: TextInputType.number,
              maxLength: 5,
              onSubmitted: (_) => _searchMarkets(),
            ),
            const SizedBox(height: 16),

            // Suche-Button
            ElevatedButton.icon(
              onPressed: _loading ? null : _searchMarkets,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_loading ? 'Suche läuft...' : 'Märkte suchen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            // Fehler-Anzeige
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Märkte-Liste
            Expanded(
              child: _markets.isEmpty
                  ? Center(
                      child: Text(
                        _loading
                            ? 'Suche nach Märkten...'
                            : 'Geben Sie eine PLZ ein, um Märkte zu finden.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _markets.length,
                      itemBuilder: (context, index) {
                        final market = _markets[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade100,
                              child: Icon(
                                Icons.store,
                                color: Colors.green.shade700,
                              ),
                            ),
                            title: Text(
                              market.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (market.address != null) ...[
                                  if (market.address!['street'] != null)
                                    Text(market.address!['street']),
                                  if (market.address!['zipCode'] != null &&
                                      market.address!['city'] != null)
                                    Text(
                                      '${market.address!['zipCode']} ${market.address!['city']}',
                                    ),
                                ],
                                if (market.distance != null)
                                  Text(
                                    '${market.distance!.toStringAsFixed(1)} km entfernt',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _saveMarket(market),
                              tooltip: 'Markt speichern',
                            ),
                            onTap: () => _saveMarket(market),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// EDEKA Market Model
class EdekaMarket {
  final String id;
  final String name;
  final Map<String, dynamic>? address;
  final Map<String, dynamic>? coordinates;
  final double? distance;

  EdekaMarket({
    required this.id,
    required this.name,
    this.address,
    this.coordinates,
    this.distance,
  });

  factory EdekaMarket.fromJson(Map<String, dynamic> json) {
    return EdekaMarket(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as Map<String, dynamic>?,
      coordinates: json['coordinates'] as Map<String, dynamic>?,
      distance: json['distance'] != null
          ? (json['distance'] as num).toDouble()
          : null,
    );
  }
}

