/// Premium Supermarket Selection Screen
/// Vertical swipeable cards for supermarket selection
import 'package:flutter/material.dart';
import '../../core/theme/grocify_theme.dart';
import '../../core/widgets/premium/supermarket_card.dart';

class SupermarketSelectionScreen extends StatefulWidget {
  const SupermarketSelectionScreen({super.key});

  @override
  State<SupermarketSelectionScreen> createState() =>
      _SupermarketSelectionScreenState();
}

class _SupermarketSelectionScreenState
    extends State<SupermarketSelectionScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _supermarkets = const [
    {
      'name': 'REWE',
      'logo': '🛒',
      'recipeCount': 42,
      'savings': 12.50,
      'color': Color(0xFF6366F1),
    },
    {
      'name': 'LIDL',
      'logo': '🛍️',
      'recipeCount': 38,
      'savings': 15.20,
      'color': Color(0xFF10B981),
    },
    {
      'name': 'EDEKA',
      'logo': '🏪',
      'recipeCount': 35,
      'savings': 11.80,
      'color': Color(0xFFFFB800),
    },
    {
      'name': 'ALDI',
      'logo': '🏬',
      'recipeCount': 28,
      'savings': 9.90,
      'color': Color(0xFFEF4444),
    },
    {
      'name': 'NETTO',
      'logo': '🛒',
      'recipeCount': 22,
      'savings': 8.50,
      'color': Color(0xFF8B5CF6),
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      appBar: AppBar(title: const Text('Supermarkt wählen')),
      body: Column(
        children: [
          const SizedBox(height: GrocifyTheme.spaceXXL),
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: GrocifyTheme.screenPadding,
            ),
            child: Text(
              'Wähle deinen Supermarkt',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: GrocifyTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: GrocifyTheme.spaceMD),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: GrocifyTheme.screenPadding,
            ),
            child: Text(
              'Swipe durch die verfügbaren Märkte',
              style: TextStyle(fontSize: 15, color: GrocifyTheme.textSecondary),
            ),
          ),
          const SizedBox(height: GrocifyTheme.spaceXXL),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: _supermarkets.length,
              itemBuilder: (context, index) {
                final market = _supermarkets[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: GrocifyTheme.spaceLG,
                  ),
                  child: SupermarketCard(
                    name: market['name'] as String,
                    logo: market['logo'] as String,
                    recipeCount: market['recipeCount'] as int,
                    savings: market['savings'] as double,
                    gradientColor: market['color'] as Color,
                    onTap: () {
                      // Navigate to supermarket recipes
                      Navigator.pop(context, market['name']);
                    },
                  ),
                );
              },
            ),
          ),
          // Page indicators
          Padding(
            padding: const EdgeInsets.all(GrocifyTheme.spaceXXL),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _supermarkets.length,
                (index) => AnimatedContainer(
                  duration: GrocifyTheme.animationFast,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? GrocifyTheme.primary
                        : GrocifyTheme.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
