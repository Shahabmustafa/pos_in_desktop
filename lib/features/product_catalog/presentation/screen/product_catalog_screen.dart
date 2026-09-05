import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../shared/feature_ui.dart';
import '../../../login/data/permissions.dart';
import '../../../login/presentation/access_scope.dart';
import '../../data/model/category_model.dart';
import '../../data/model/inventory_type_model.dart';
import '../provider/product_catalog_provider.dart';
import '../widget/catalog_entry_form_dialog.dart';

/// Product Catalog module: manage product categories and inventory types,
/// each backed by its own table.
class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({super.key, this.provider});

  static const String routeName = '/product_catalog';

  final ProductCatalogProvider? provider;

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  late final ProductCatalogProvider _provider =
      widget.provider ?? ProductCatalogProvider();

  @override
  void initState() {
    super.initState();
    _provider.load();
  }

  @override
  void dispose() {
    if (widget.provider == null) _provider.dispose();
    super.dispose();
  }

  Future<void> _categoryForm([CategoryModel? existing]) async {
    final draft = await showDialog<CatalogEntryDraft>(
      context: context,
      builder: (_) => CatalogEntryFormDialog(
        entityLabel: 'Category',
        isEdit: existing?.id != null,
        name: existing?.name,
        description: existing?.description,
        isActive: existing?.isActive ?? true,
      ),
    );
    if (draft == null) return;
    final model = (existing ?? const CategoryModel(name: '')).copyWith(
      name: draft.name,
      description: draft.description,
      isActive: draft.isActive,
    );
    final ok = await _provider.saveCategory(model);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category "${model.name}" saved')),
      );
    }
  }

  Future<void> _typeForm([InventoryTypeModel? existing]) async {
    final draft = await showDialog<CatalogEntryDraft>(
      context: context,
      builder: (_) => CatalogEntryFormDialog(
        entityLabel: 'Inventory Type',
        isEdit: existing?.id != null,
        name: existing?.name,
        description: existing?.description,
        isActive: existing?.isActive ?? true,
      ),
    );
    if (draft == null) return;
    final model = (existing ?? const InventoryTypeModel(name: '')).copyWith(
      name: draft.name,
      description: draft.description,
      isActive: draft.isActive,
    );
    final ok = await _provider.saveInventoryType(model);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Inventory type "${model.name}" saved')),
      );
    }
  }

  Future<void> _confirmDelete(String label, String name, Future<void> Function() onDelete) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete $label?'),
        content: Text('"$name" will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (yes == true) await onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final access = AccessScope.of(context);
    final canAdd = access.can('product_catalog', PermAction.add);
    final canEdit = access.can('product_catalog', PermAction.edit);
    final canDelete = access.can('product_catalog', PermAction.delete);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories & Types'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Categories'),
              Tab(text: 'Inventory Types'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const AppIcon(AppIcons.refresh),
              onPressed: _provider.load,
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: ListenableBuilder(
          listenable: _provider,
          builder: (context, _) {
            if (_provider.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_provider.error != null) {
              return ErrorState(
                  message: _provider.error!, onRetry: _provider.load);
            }
            return TabBarView(
              children: [
                _CategoriesTab(
                  provider: _provider,
                  onAdd: canAdd ? () => _categoryForm() : null,
                  onEdit: canEdit ? _categoryForm : null,
                  onDelete: canDelete
                      ? (c) => _confirmDelete('category', c.name,
                          () => _provider.deleteCategory(c.id!))
                      : null,
                ),
                _TypesTab(
                  provider: _provider,
                  onAdd: canAdd ? () => _typeForm() : null,
                  onEdit: canEdit ? _typeForm : null,
                  onDelete: canDelete
                      ? (t) => _confirmDelete('inventory type', t.name,
                          () => _provider.deleteInventoryType(t.id!))
                      : null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab({
    required this.provider,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductCatalogProvider provider;
  final VoidCallback? onAdd;
  final ValueChanged<CategoryModel>? onEdit;
  final ValueChanged<CategoryModel>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: StatCardRow(
            cards: [
              StatCard(
                title: 'Categories',
                subtitle: '${provider.categories.length}',
              ),
              StatCard(
                title: 'Active',
                subtitle: '${provider.activeCategoryCount}',
                tint: const Color(0xFF2E7D32),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: SectionCard(
              title: 'Categories',
              subtitle: 'Product categories',
              fillHeight: true,
              trailing: onAdd == null
                  ? null
                  : FilledButton.icon(
                      onPressed: onAdd,
                      icon: const AppIcon(AppIcons.add),
                      label: const Text('Add Category'),
                    ),
              child: provider.categories.isEmpty
                  ? EmptyState(
                      icon: AppIcons.category_outlined,
                      title: 'No categories yet',
                      actionLabel: onAdd == null ? null : 'Add Category',
                      onAction: onAdd,
                    )
                  : ScrollableTable(
                      flexColumn: 1, // Description
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Description')),
                        DataColumn(label: Text('Active')),
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (final c in provider.categories)
                          DataRow(
                            onSelectChanged:
                                onEdit == null ? null : (_) => onEdit!(c),
                            cells: [
                              DataCell(Text(c.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(Text(c.description)),
                              DataCell(ActiveDot(active: c.isActive)),
                              DataCell(RowActions(
                                onEdit:
                                    onEdit == null ? null : () => onEdit!(c),
                                onDelete: onDelete == null
                                    ? null
                                    : () => onDelete!(c),
                              )),
                            ],
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _TypesTab extends StatelessWidget {
  const _TypesTab({
    required this.provider,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductCatalogProvider provider;
  final VoidCallback? onAdd;
  final ValueChanged<InventoryTypeModel>? onEdit;
  final ValueChanged<InventoryTypeModel>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: StatCardRow(
            cards: [
              StatCard(
                title: 'Inventory Types',
                subtitle: '${provider.inventoryTypes.length}',
              ),
              StatCard(
                title: 'Active',
                subtitle: '${provider.activeTypeCount}',
                tint: const Color(0xFF2E7D32),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: SectionCard(
              title: 'Inventory Types',
              subtitle: 'Stock classification',
              fillHeight: true,
              trailing: onAdd == null
                  ? null
                  : FilledButton.icon(
                      onPressed: onAdd,
                      icon: const AppIcon(AppIcons.add),
                      label: const Text('Add Inventory Type'),
                    ),
              child: provider.inventoryTypes.isEmpty
                  ? EmptyState(
                      icon: AppIcons.inventory_2_outlined,
                      title: 'No inventory types yet',
                      actionLabel: onAdd == null ? null : 'Add Inventory Type',
                      onAction: onAdd,
                    )
                  : ScrollableTable(
                      flexColumn: 1, // Description
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Description')),
                        DataColumn(label: Text('Active')),
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (final t in provider.inventoryTypes)
                          DataRow(
                            onSelectChanged:
                                onEdit == null ? null : (_) => onEdit!(t),
                            cells: [
                              DataCell(Text(t.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(Text(t.description)),
                              DataCell(ActiveDot(active: t.isActive)),
                              DataCell(RowActions(
                                onEdit:
                                    onEdit == null ? null : () => onEdit!(t),
                                onDelete: onDelete == null
                                    ? null
                                    : () => onDelete!(t),
                              )),
                            ],
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
