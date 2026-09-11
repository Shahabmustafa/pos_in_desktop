import '../../../bank/data/model/bank_head_model.dart';
import '../datasource/company_payment_datasource.dart';
import '../model/company_payable_ref.dart';
import '../model/company_payment_model.dart';

/// Repository for the Company Payment feature. Presentation layer depends on
/// this, not the datasource directly.
class CompanyPaymentRepository {
  CompanyPaymentRepository([CompanyPaymentDataSource? dataSource])
      : _dataSource = dataSource ?? const CompanyPaymentDataSource();

  final CompanyPaymentDataSource _dataSource;

  Future<void> ensureSchema() => _dataSource.ensureSchema();

  Future<List<CompanyPaymentModel>> getAll() => _dataSource.fetchAll();

  Future<List<CompanyPayableRef>> companies() => _dataSource.fetchCompanies();

  Future<List<BankHeadModel>> banks() => _dataSource.fetchBanks();

  /// Inserts a new payment (when `model.id == null`) or updates an existing one.
  Future<CompanyPaymentModel> save(CompanyPaymentModel model) =>
      model.id == null ? _dataSource.insert(model) : _dataSource.update(model);

  Future<void> delete(int id) => _dataSource.delete(id);
}
