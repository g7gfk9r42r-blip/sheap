/// Shopping List Screen - Modern & Consistent with GrocifyTheme
/// Nur Zutaten über Rezepte hinzufügen, kein manuelles Hinzufügen
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/services/shopping_list_service.dart';
import '../../core/theme/grocify_theme.dart';
import '../../utils/shopping_list_categorizer.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _shoppingListService = ShoppingListService.instance;

  @override
  void initState() {
    super.initState();
    _shoppingListService.addListener(_onShoppingListChanged);
  }

  @override
  void dispose() {
    _shoppingListService.removeListener(_onShoppingListChanged);
    super.dispose();
  }

  void _onShoppingListChanged() {
    if (mounted) setState(() {});
  }

  void _toggleItem(int index) {
    _shoppingListService.toggleItem(index);
    HapticFeedback.lightImpact();
  }

  void _deleteItem(int index) {
    _shoppingListService.removeItem(index);
    HapticFeedback.mediumImpact();
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle Zutaten löschen?'),
        content:
            const Text('Möchtest du wirklich alle Zutaten aus der Einkaufsliste entfernen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              _shoppingListService.clear();
              Navigator.of(context).pop();
              HapticFeedback.mediumImpact();
            },
            child: Text(
              'Löschen',
              style: TextStyle(color: GrocifyTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showItemDetail(int index, ShoppingListItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ItemDetailScreen(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: _shoppingListService.items.isEmpty
                ? _EmptyState()
                : _SortedShoppingList(
                    items: _shoppingListService.items,
                    onItemTap: (index) => _toggleItem(index),
                    onItemDelete: (index) => _deleteItem(index),
                    onItemDetail: (index, item) => _showItemDetail(index, item),
                    onClearAll: _clearAll,
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SORTED SHOPPING LIST (with stable header in same scroll context -> no jumping)
// ============================================================================

class _SortedShoppingList extends StatelessWidget {
  final List<ShoppingListItem> items;
  final Function(int) onItemTap;
  final Function(int) onItemDelete;
  final Function(int, ShoppingListItem) onItemDetail;
  final VoidCallback onClearAll;

  const _SortedShoppingList({
    required this.items,
    required this.onItemTap,
    required this.onItemDelete,
    required this.onItemDetail,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    // Gruppiere Items nach Market (Primär: item.market, Fallback: item.offer?.retailer)
    final marketsInOrder = <String>[];
    final itemsByMarket = <String, List<MapEntry<int, ShoppingListItem>>>{};

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final market = (item.market != null && item.market!.isNotEmpty)
          ? item.market!
          : (item.offer?.retailer ?? 'Sonstiges');

      if (!marketsInOrder.contains(market)) {
        marketsInOrder.add(market);
      }
      itemsByMarket.putIfAbsent(market, () => []).add(MapEntry(i, item));
    }

    // Sortiere Items innerhalb jedes Markets
    void sortItems(List<MapEntry<int, ShoppingListItem>> itemList) {
      itemList.sort((a, b) {
        final categoryA =
            a.value.category ?? ShoppingListCategorizer.categorizeIngredient(a.value.name);
        final categoryB =
            b.value.category ?? ShoppingListCategorizer.categorizeIngredient(b.value.name);

        final orderA = ShoppingListCategorizer.getCategoryOrder(categoryA);
        final orderB = ShoppingListCategorizer.getCategoryOrder(categoryB);

        if (orderA != orderB) return orderA.compareTo(orderB);

        // Within same category: unchecked first
        if (a.value.checked != b.value.checked) {
          return a.value.checked ? 1 : -1;
        }

        return 0;
      });
    }

    // Sortiere alle Market-Gruppen
    for (final market in itemsByMarket.keys) {
      sortItems(itemsByMarket[market]!);
    }

    // Erstelle die finale Liste mit Headern
    final List<Widget> listItems = [];

    // Füge Items gruppiert nach Market hinzu (Reihenfolge: first appearance in list)
    for (final market in marketsInOrder) {
      final marketItems = itemsByMarket[market]!;
      if (marketItems.isEmpty) continue;

          listItems.add(
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.store_rounded,
                    size: 16,
                    color: GrocifyTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
              Expanded(
                child: Text(
                  market,
                    style: TextStyle(
                      fontSize: 14,
                    fontWeight: FontWeight.w800,
                      color: GrocifyTheme.textPrimary,
                      letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: GrocifyTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: GrocifyTheme.border, width: 1),
                ),
                child: Text(
                  '${marketItems.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: GrocifyTheme.textSecondary,
                    height: 1.0,
                  ),
                    ),
                  ),
                ],
              ),
            ),
          );

      for (final entry in marketItems) {
        listItems.add(
          _ShoppingItem(
            item: entry.value,
            onTap: () => onItemTap(entry.key),
            onDelete: () => onItemDelete(entry.key),
            onDetail: () => onItemDetail(entry.key, entry.value),
          ),
        );
      }
    }

    final itemCount = items.length;

    // WICHTIG: Header und Liste in einem Scroll-Kontext => kein “Springen”
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        // Header mit Counter und Clear Button
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Einkaufsliste',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: GrocifyTheme.textPrimary,
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$itemCount ${itemCount == 1 ? 'Zutat' : 'Zutaten'}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: GrocifyTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (itemCount > 0)
                TextButton.icon(
                  onPressed: onClearAll,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: GrocifyTheme.error,
                  ),
                  label: Text(
                    'Alle löschen',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: GrocifyTheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),

        ...listItems,
        const SizedBox(height: 24),
      ],
    );
  }
}

// ============================================================================
// SHOPPING ITEM
// ============================================================================

class _ShoppingItem extends StatefulWidget {
  final ShoppingListItem item;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onDetail;

  const _ShoppingItem({
    required this.item,
    required this.onTap,
    this.onDelete,
    this.onDetail,
  });

  @override
  State<_ShoppingItem> createState() => _ShoppingItemState();
}

class _ShoppingItemState extends State<_ShoppingItem> {
  @override
  Widget build(BuildContext context) {
    final isBase = widget.item.isBaseIngredient == true;
    final isFromOffer = widget.item.fromOffer == true;
    final isNotInOffer = widget.item.isWithoutOffer == true;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (widget.onDetail != null) {
            widget.onDetail!();
          } else {
            widget.onTap();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: widget.onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.item.checked ? GrocifyTheme.primary : Colors.transparent,
                    border: Border.all(
                      color: widget.item.checked ? GrocifyTheme.primary : GrocifyTheme.border,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: widget.item.checked
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),

              // Text + Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name + Marke
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                      widget.item.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: widget.item.checked
                            ? GrocifyTheme.textSecondary
                            : GrocifyTheme.textPrimary,
                        decoration: widget.item.checked ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                        ),
                        // Marke (falls vorhanden)
                        if (!widget.item.checked && widget.item.brand != null && widget.item.brand!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: GrocifyTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.item.brand!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: GrocifyTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Details (Menge + Unit)
                    if (!widget.item.checked) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (widget.item.amount != null)
                      Text(
                        widget.item.amount!,
                        style: TextStyle(
                          fontSize: 13,
                          color: GrocifyTheme.textSecondary,
                        ),
                            )
                          else if (widget.item.quantity != null && widget.item.unit != null)
                            Text(
                              '${widget.item.quantity} ${widget.item.unit}',
                              style: TextStyle(
                                fontSize: 13,
                                color: GrocifyTheme.textSecondary,
                              ),
                            )
                          else if (widget.item.unit != null)
                            Text(
                              widget.item.unit!,
                              style: TextStyle(
                                fontSize: 13,
                                color: GrocifyTheme.textSecondary,
                              ),
                            ),
                          // Preis (falls vorhanden)
                          if (widget.item.price != null && widget.item.price! > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• ${widget.item.price!.toStringAsFixed(2)} €',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: GrocifyTheme.success,
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          if (isBase || isFromOffer || isNotInOffer)
                            _StatusPill(
                              label: isBase
                                  ? 'Basis'
                                  : (isNotInOffer ? 'Kein Angebot' : 'Angebot'),
                              color: isBase
                                  ? GrocifyTheme.textSecondary
                                  : (isNotInOffer ? GrocifyTheme.warning : GrocifyTheme.success),
                            ),
                        ],
                      ),
                      if (widget.item.note != null && widget.item.note!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.item.note!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: GrocifyTheme.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              // Delete Button
              if (widget.onDelete != null)
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 22,
                      color: GrocifyTheme.textTertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.20), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.0,
        ),
      ),
    );
  }
}

// ============================================================================
// ITEM DETAIL SCREEN
// ============================================================================

class _ItemDetailScreen extends StatelessWidget {
  final ShoppingListItem item;

  const _ItemDetailScreen({required this.item});

  @override
  Widget build(BuildContext context) {
    final offer = item.offer;
    final hasPriceInfo = item.price != null || item.priceBefore != null || offer != null;

    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      appBar: AppBar(
        backgroundColor: GrocifyTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          color: GrocifyTheme.textPrimary,
        ),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: GrocifyTheme.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Zutat Name + Marke
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                item.name,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: GrocifyTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
                    ),
                  ),
                  // Marke (falls vorhanden)
                  if (item.brand != null && item.brand!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: GrocifyTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: GrocifyTheme.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        item.brand!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: GrocifyTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Menge und Einheit
              if (item.amount != null || item.quantity != null || item.unit != null) ...[
                const SizedBox(height: 8),
                Text(
                  item.amount ??
                      (item.quantity != null && item.unit != null
                          ? '${item.quantity} ${item.unit}'
                          : item.unit ?? ''),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: GrocifyTheme.textSecondary,
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Preis-Informationen
              if (hasPriceInfo) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: GrocifyTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: GrocifyTheme.border,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preis',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: GrocifyTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Aktueller Preis
                      if (item.price != null && item.price! > 0) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                              '${item.price!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: GrocifyTheme.primary,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '€',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: GrocifyTheme.primary,
                              ),
                            ),
                          ),
                            if (item.unit != null && item.unit!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '/ ${item.unit}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: GrocifyTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ] else if (offer != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${offer.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: GrocifyTheme.primary,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '€',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: GrocifyTheme.primary,
                                ),
                              ),
                            ),
                            if (offer.unit != null && offer.unit!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '/ ${offer.unit}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: GrocifyTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      ],

                      // Preis vorher (falls vorhanden)
                      if (item.priceBefore != null &&
                          item.priceBefore! > (item.price ?? 0.0)) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '${item.priceBefore!.toStringAsFixed(2)} €',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: GrocifyTheme.textSecondary,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: GrocifyTheme.success.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '-${((item.priceBefore! - (item.price ?? 0.0)) / item.priceBefore! * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: GrocifyTheme.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Marke
                      if (item.brand != null && item.brand!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              Icons.branding_watermark_rounded,
                              size: 18,
                              color: GrocifyTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.brand!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: GrocifyTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Produktname/Title
                      if ((offer?.title.isNotEmpty ?? false) ||
                          (item.note != null && item.note!.isNotEmpty)) ...[
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: GrocifyTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                offer?.title ?? item.note ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: GrocifyTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: GrocifyTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: GrocifyTheme.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Keine Preisinformation verfügbar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: GrocifyTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: GrocifyTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 48,
                color: GrocifyTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Deine Einkaufsliste ist leer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: GrocifyTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Füge Rezepte hinzu, um automatisch\neine Einkaufsliste zu erstellen',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: GrocifyTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}