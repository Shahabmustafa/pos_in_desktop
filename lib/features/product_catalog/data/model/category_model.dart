/// A product category, e.g. "Beverages", "Snacks", "Dairy".
class CategoryModel {
  const CategoryModel({
    this.id,
    required this.name,
    this.description = '',
    this.isActive = true,
  });

  /// `null` for a not-yet-saved category.
  final int? id;
  final String name;
  final String description;
  final bool isActive;

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      isActive: (map['is_active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'is_active': isActive,
      };

  CategoryModel copyWith({
    int? id,
    String? name,
    String? description,
    bool? isActive,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }
}
