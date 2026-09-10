import '../../../sale_exchange/data/model/sale_exchange_model.dart';
import '../datasource/reports_datasource.dart';
import '../model/reports_model.dart';

/// Repository for the Reports feature. Presentation layer depends on this.
class ReportsRepository {
  ReportsRepository([ReportsDataSource? dataSource])
      : _dataSource = dataSource ?? const ReportsDataSource();

  final ReportsDataSource _dataSource;

  Future<List<SaleReportInvoice>> saleReport(DateTime from, DateTime to) =>
      _dataSource.saleReport(from, to);

  Future<List<SaleReturnReportInvoice>> saleReturnReport(
          DateTime from, DateTime to) =>
      _dataSource.saleReturnReport(from, to);

  Future<List<SaleExchangeRecord>> saleExchangeReport(
          DateTime from, DateTime to) =>
      _dataSource.saleExchangeReport(from, to);

  Future<ProfitLossReport> profitLoss(DateTime from, DateTime to) =>
      _dataSource.profitLoss(from, to);

  Future<List<CategoryReportRow>> categoryReport(DateTime from, DateTime to) =>
      _dataSource.categoryReport(from, to);

  Future<List<ExpenseReportRow>> expenseReport(DateTime from, DateTime to) =>
      _dataSource.expenseReport(from, to);

  Future<PurchaseReportData> purchaseReport(DateTime from, DateTime to) =>
      _dataSource.purchaseReport(from, to);

  Future<List<StockReportRow>> stockReport(DateTime from, DateTime to) =>
      _dataSource.stockReport(from, to);
}
