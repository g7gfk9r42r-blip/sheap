import 'package:flutter/foundation.dart';

/// ExtraIngredient Model - Zutaten die NICHT aus Angeboten stammen
/// z.B. Salz, Pfeffer, Öl, Gewürze, etc.
@immutable
class ExtraIngredient {
  final String name;
  final String amount; // z.B. "1 Stück", "nach Bedarf", "200g"
  final String? unit; // Optional: Einheit, falls separat

  const ExtraIngredient({
    required this.name,
    required this.amount,
    this.unit,
  });

  factory ExtraIngredient.fromJson(Map<String, dynamic> json) {
    return ExtraIngredient(
      name: json['name']?.toString() ?? '',
      amount: json['amount']?.toString() ?? json['quantity']?.toString() ?? '',
      unit: json['unit']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      if (unit != null) 'unit': unit,
    };
  }

  @override
  String toString() {
    if (unit != null && unit!.isNotEmpty) {
      return '$name ($amount $unit)';
    }
    return '$name ($amount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExtraIngredient &&
        other.name == name &&
        other.amount == amount &&
        other.unit == unit;
  }

  @override
  int get hashCode => Object.hash(name, amount, unit);
}

