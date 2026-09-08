import '../datasource/voucher_datasource.dart';
import '../model/voucher_model.dart';

/// Repository for the Voucher feature. Presentation layer depends on this.
class VoucherRepository {
  VoucherRepository([VoucherDataSource? dataSource])
      : _dataSource = dataSource ?? const VoucherDataSource();

  final VoucherDataSource _dataSource;

  Future<void> ensureSchema() => _dataSource.ensureSchema();

  Future<List<VoucherModel>> getAll({VoucherType? type}) =>
      _dataSource.fetchAll(type: type);

  /// Inserts a new voucher (when `model.id == null`) or updates an existing one.
  Future<VoucherModel> save(VoucherModel model) =>
      model.id == null ? _dataSource.insert(model) : _dataSource.update(model);

  Future<void> delete(int id) => _dataSource.delete(id);
}
