import 'package:flutter/material.dart';
import '../../models/weekly_bundle.dart';
import '../../repositories/weekly_bundle_repository.dart';
import 'presentation/recipes_screen.dart';

/// Wrapper-Screen, der das WeeklyBundle lädt und dann RecipesScreen anzeigt
class WeeklyRecipesScreen extends StatefulWidget {
  final String? supermarket;
  final String? weekKey;
  final String? assetPath;

  const WeeklyRecipesScreen({
    super.key,
    this.supermarket,
    this.weekKey,
    this.assetPath,
  });

  @override
  State<WeeklyRecipesScreen> createState() => _WeeklyRecipesScreenState();
}

class _WeeklyRecipesScreenState extends State<WeeklyRecipesScreen> {
  WeeklyBundle? _bundle;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBundle();
  }

  Future<void> _loadBundle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String assetPath;
      if (widget.assetPath != null) {
        assetPath = widget.assetPath!;
      } else if (widget.supermarket != null && widget.weekKey != null) {
        assetPath = WeeklyBundleRepository.getAssetPath(
          supermarket: widget.supermarket!,
          weekKey: widget.weekKey!,
        );
      } else {
        // Default: aldi_sued, Woche 2026-W01 (kann später dynamisch berechnet werden)
        assetPath = WeeklyBundleRepository.getAssetPath(
          supermarket: 'aldi_sued',
          weekKey: '2026-W01',
        );
      }

      final bundle = await WeeklyBundleRepository.loadWeeklyBundle(
        assetPath: assetPath,
      );

      if (mounted) {
        setState(() {
          _bundle = bundle;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rezepte'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rezepte'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Fehler beim Laden der Rezepte',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadBundle,
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
    }

    if (_bundle == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rezepte'),
        ),
        body: const Center(
          child: Text('Keine Daten gefunden'),
        ),
      );
    }

    return const RecipesScreen();
  }
}

