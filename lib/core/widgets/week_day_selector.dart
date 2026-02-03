/// Week Day Selector Widget
/// Reusable component for selecting a day within the current offer week
/// Replaces month-based DatePicker with a clean week view
import 'package:flutter/material.dart';
import '../theme/grocify_theme.dart';
import '../../utils/week.dart';
import '../../data/services/meal_plan_service.dart';

/// Shows a horizontal row of 7 days (Mon-Sun) for the current week
/// Returns the selected DateTime (date only, time is 00:00)
class WeekDaySelector extends StatelessWidget {
  final DateTime? initialDate;
  final Function(DateTime) onDateSelected;
  final DateTime? weekStart; // Optional: specific week start, otherwise uses current week

  const WeekDaySelector({
    super.key,
    this.initialDate,
    required this.onDateSelected,
    this.weekStart,
  });

  /// Get the Monday of the current week (or specified week)
  DateTime _getWeekStart() {
    if (weekStart != null) {
      final date = weekStart!;
      return date.subtract(Duration(days: date.weekday - 1));
    }
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final weekStartDate = _getWeekStart();
    final weekDays = List.generate(7, (index) => weekStartDate.add(Duration(days: index)));
    final selectedDate = initialDate ?? DateTime.now();
    final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: GrocifyTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Woche ${isoWeekKey(weekStartDate)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: GrocifyTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Day chips
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: 7,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final day = weekDays[index];
                final dayOnly = DateTime(day.year, day.month, day.day);
                final isSelected = dayOnly == selectedDateOnly;
                final isToday = dayOnly == DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

                final weekdayNames = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

                return GestureDetector(
                  onTap: () => onDateSelected(dayOnly),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: 56,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? GrocifyTheme.primary
                          : isToday
                              ? GrocifyTheme.primary.withOpacity(0.1)
                              : GrocifyTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? GrocifyTheme.primary
                            : isToday
                                ? GrocifyTheme.primary.withOpacity(0.3)
                                : GrocifyTheme.border.withOpacity(0.5),
                        width: isSelected ? 0 : (isToday ? 2 : 1),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: GrocifyTheme.primary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          weekdayNames[index],
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isSelected
                                ? Colors.white
                                : GrocifyTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isSelected
                                ? Colors.white
                                : GrocifyTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom Sheet for Week Day Selection
/// Shows week selector + meal type selector
Future<Map<String, dynamic>?> showWeekDayMealTypeSelector({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? weekStart,
}) async {
  DateTime? selectedDate = initialDate ?? DateTime.now();
  MealType? selectedMealType;

  final result = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return Container(
          decoration: BoxDecoration(
            color: GrocifyTheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: GrocifyTheme.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  // Title
                  Text(
                    'Tag & Mahlzeit auswählen',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: GrocifyTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Week selector
                  WeekDaySelector(
                    initialDate: selectedDate,
                    weekStart: weekStart,
                    onDateSelected: (date) {
                      setState(() {
                        selectedDate = date;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Meal type selector
                  Text(
                    'Mahlzeit',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: GrocifyTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...MealType.values.map((type) {
                    final isSelected = selectedMealType == type;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedMealType = type;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? type.color.withOpacity(0.12)
                                : GrocifyTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? type.color
                                  : GrocifyTheme.border.withOpacity(0.5),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: type.color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  type.icon,
                                  color: type.color,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  type.label,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: GrocifyTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: type.color,
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Abbrechen',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: GrocifyTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: selectedMealType != null && selectedDate != null
                              ? () {
                                  Navigator.pop(context, {
                                    'date': selectedDate,
                                    'mealType': selectedMealType,
                                  });
                                }
                              : null,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: GrocifyTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Hinzufügen',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  return result;
}

