/// An inventory type, e.g. "Finished Goods", "Raw Material", "Packaging".
class InventoryTypeModel {
  const InventoryTypeModel({
    this.id,
    required this.name,
    this.description = '',
    this.isActive = true,
  });

  /// `null` for a not-yet-saved inventory type.
  final int? id;
  final String name;
  final String description;
  final bool isActive;

  factory InventoryTypeModel.fromMap(Map<String, dynamic> map) {
    return InventoryTypeModel(
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

  InventoryTypeModel copyWith({
    int? id,
    String? name,
    String? description,
    bool? isActive,
  }) {
    return InventoryTypeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }
}
