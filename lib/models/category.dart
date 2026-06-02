import 'package:flutter/material.dart';

class BookshelfCategory {
  final int id;
  final String name;
  final String color; // '#RRGGBB'
  final int sortOrder;
  final DateTime createdAt;

  const BookshelfCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.sortOrder,
    required this.createdAt,
  });

  Color get colorValue {
    final hex = color.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  factory BookshelfCategory.fromJson(Map<String, dynamic> json) {
    return BookshelfCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      color: json['color'] as String? ?? '#6B7280',
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  BookshelfCategory copyWith({
    String? name,
    String? color,
    int? sortOrder,
  }) {
    return BookshelfCategory(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }

  static const List<Color> presetColors = [
    Color(0xFFEF4444), // red
    Color(0xFFF97316), // orange
    Color(0xFFEAB308), // yellow
    Color(0xFF22C55E), // green
    Color(0xFF06B6D4), // cyan
    Color(0xFF3B82F6), // blue
    Color(0xFF8B5CF6), // violet
    Color(0xFFEC4899), // pink
    Color(0xFF6B7280), // gray
    Color(0xFF78716C), // stone
    Color(0xFF0D9488), // teal
    Color(0xFFD97706), // amber
  ];

  static String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }
}
