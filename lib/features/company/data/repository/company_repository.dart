import '../datasource/company_datasource.dart';
import '../model/company_model.dart';

/// Repository for the Company feature. Presentation layer depends on this.
class CompanyRepository {
  CompanyRepository([CompanyDataSource? dataSource])
      : _dataSource = dataSource ?? const CompanyDataSource();

  final CompanyDataSource _dataSource;

  Future<void> ensureSchema() => _dataSource.ensureSchema();

  Future<List<CompanyModel>> getAll() => _dataSource.fetchAll();

  /// Inserts a new company (when `model.id == null`) or updates an existing one.
  Future<CompanyModel> save(CompanyModel model) =>
      model.id == null ? _dataSource.insert(model) : _dataSource.update(model);

  Future<void> delete(int id) => _dataSource.delete(id);
}
