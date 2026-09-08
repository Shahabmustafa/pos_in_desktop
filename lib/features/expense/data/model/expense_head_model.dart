/// A category of expense, e.g. "Rent", "Utilities", "Salaries".
class ExpenseHeadModel {
  const ExpenseHeadModel({
    this.id,
    required this.name,
    this.description = '',
    this.isActive = true,
  });

  final int? id;
  final String name;
  final String description;
  final bool isActive;

  factory ExpenseHeadModel.fromMap(Map<String, dynamic> map) {
    return ExpenseHeadModel(
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

  ExpenseHeadModel copyWith({
    int? id,
    String? name,
    String? description,
    bool? isActive,
  }) {
    return ExpenseHeadModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }
}
