import 'package:flutter/material.dart';
import 'water_tracker_card.dart';

/// Demo Page for Water Tracker Card
/// 
/// This page demonstrates the WaterTrackerCard widget with interactive state.
/// You can tap any cup to fill water up to that cup.
class WaterTrackerDemoPage extends StatefulWidget {
  const WaterTrackerDemoPage({super.key});

  @override
  State<WaterTrackerDemoPage> createState() => _WaterTrackerDemoPageState();
}

class _WaterTrackerDemoPageState extends State<WaterTrackerDemoPage> {
  // State
  double _currentLitres = 0.0;
  final double _goalLitres = 3.0;
  final int _totalCups = 12;

  void _onCupTap(int cupIndex) {
    setState(() {
      // Fill all cups up to the tapped cup
      const litresPerCup = 0.25;
      final targetLitres = (cupIndex + 1) * litresPerCup;
      _currentLitres = targetLitres.clamp(0.0, _goalLitres * 1.5);
    });
  }

  void _onReset() {
    setState(() {
      _currentLitres = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF9), // stone-50
      appBar: AppBar(
        title: const Text(
          'Water Tracker Demo',
          style: TextStyle(color: Color(0xFF1C1917)), // stone-900
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1C1917)),
            onPressed: _onReset,
            tooltip: 'Reset',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Water Tracker Card
              WaterTrackerCard(
                currentLitres: _currentLitres,
                goalLitres: _goalLitres,
                totalCups: _totalCups,
                onCupTap: _onCupTap,
              ),
              
              const SizedBox(height: 24),
              
              // Info Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE7E5E4).withOpacity(0.6), // stone-200
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Info',
                        style: TextStyle(
                          color: Color(0xFF1C1917), // stone-900
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        label: 'Current',
                        value: '${_currentLitres.toStringAsFixed(2)} L',
                      ),
                      _InfoRow(
                        label: 'Goal',
                        value: '${_goalLitres.toStringAsFixed(2)} L',
                      ),
                      _InfoRow(
                        label: 'Per Cup',
                        value: '0.25 L',
                      ),
                      _InfoRow(
                        label: 'Progress',
                        value: '${((_currentLitres / _goalLitres) * 100).clamp(0.0, 100.0).toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _onReset,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981), // emerald-500
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF78716C), // stone-500
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1C1917), // stone-900
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

