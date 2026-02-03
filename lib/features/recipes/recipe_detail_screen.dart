import 'package:flutter/material.dart';
import '../../models/weekly_bundle.dart';

class RecipeDetailScreen extends StatelessWidget {
  final WeeklyRecipe recipe;
  final String currency;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipe.tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: recipe.tags
                    .map((tag) => Chip(label: Text(tag)))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
            _buildInfoRow(context),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Verwendete Angebote'),
            const SizedBox(height: 8),
            _buildOffersUsed(context),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Zutaten'),
            const SizedBox(height: 8),
            _buildIngredients(context),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Zubereitung'),
            const SizedBox(height: 8),
            _buildSteps(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context) {
    return Row(
      children: [
        if (recipe.servings > 0) ...[
          Icon(Icons.people_outline, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text('${recipe.servings} Portionen', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 16),
        ],
        if (recipe.prepMinutes > 0) ...[
          Icon(Icons.timer_outlined, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text('${recipe.prepMinutes} Min Vorbereitung', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 16),
        ],
        if (recipe.cookMinutes > 0) ...[
          Icon(Icons.restaurant_outlined, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text('${recipe.cookMinutes} Min Zubereitung', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildOffersUsed(BuildContext context) {
    if (recipe.offersUsed.isEmpty) {
      return Text(
        'Keine Angebote verwendet',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
      );
    }

    return Column(
      children: recipe.offersUsed.map((offer) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (offer.brand != null)
                            Text(
                              offer.brand!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          Text(
                            offer.exactName,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          Text(
                            offer.unit,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${offer.priceEur.toStringAsFixed(2)} $currency',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        if (offer.uvpEur != null || offer.priceBeforeEur != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            offer.uvpEur != null
                                ? 'UVP: ${offer.uvpEur!.toStringAsFixed(2)} $currency'
                                : 'Vorher: ${offer.priceBeforeEur!.toStringAsFixed(2)} $currency',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                  decoration: TextDecoration.lineThrough,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIngredients(BuildContext context) {
    return Column(
      children: recipe.ingredients.asMap().entries.map((entry) {
        final ingredient = entry.value;
        final index = entry.key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: ingredient.fromOffer
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: ingredient.fromOffer
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Colors.grey[700],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ingredient.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: ingredient.fromOffer
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                          ),
                        ),
                        if (ingredient.fromOffer)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Angebot',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    if (ingredient.quantity != null || ingredient.unit != null || ingredient.note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [
                            if (ingredient.quantity != null && ingredient.unit != null)
                              '${ingredient.quantity!.toStringAsFixed(0)} ${ingredient.unit}',
                            if (ingredient.note != null) ingredient.note,
                          ].where((e) => e != null).join(' • '),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSteps(BuildContext context) {
    return Column(
      children: recipe.steps.asMap().entries.map((entry) {
        final step = entry.value;
        final index = entry.key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

