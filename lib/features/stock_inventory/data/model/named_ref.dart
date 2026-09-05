/// A lightweight `{id, name}` reference to a row in a master table
/// (company, product_category, inventory_type). Used by the product form's
/// pickers so a stock item can store the foreign-key id.
class NamedRef {
  const NamedRef({required this.id, required this.name});

  final int id;
  final String name;

  factory NamedRef.fromMap(Map<String, dynamic> map) => NamedRef(
        id: map['id'] as int,
        name: (map['name'] as String?) ?? '',
      );

  /// Equality by [id] so a value coming back from a dropdown matches the
  /// instance in the items list.
  @override
  bool operator ==(Object other) => other is NamedRef && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}
