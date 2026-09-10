import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/foundation.dart';

import '../../../sale_exchange/data/model/sale_exchange_model.dart';
import '../../data/model/reports_model.dart';
import '../../data/repository/reports_repository.dart';

/// Which Profit & Loss figure the drill-down panel is showing.
enum PlDrill { none, sales, returns, expenses }

/// State/logic holder for the Reports feature. Holds the selected [type] and
/// date [range], the data for whichever report is showing, and the row that is
/// open in the right-hand detail panel.
class ReportsProvider extends ChangeNotifier {
  ReportsProvider([ReportsRepository? repository])
      : _repository = repository ?? ReportsRepository() {
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  final ReportsRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  ReportType _type = ReportType.sale;
  ReportType get type => _type;

  late DateTimeRange _range;
  DateTimeRange get range => _range;

  // Per-report data.
  List<SaleReportInvoice> _saleRows = const [];
  List<SaleReportInvoice> get saleRows => _saleRows;

  List<SaleReturnReportInvoice> _saleReturnRows = const [];
  List<SaleReturnReportInvoice> get saleReturnRows => _saleReturnRows;

  List<SaleExchangeRecord> _saleExchangeRows = const [];
  List<SaleExchangeRecord> get saleExchangeRows => _saleExchangeRows;

  ProfitLossReport _profitLoss = ProfitLossReport.empty;
  ProfitLossReport get profitLoss => _profitLoss;

  List<CategoryReportRow> _categoryRows = const [];
  List<CategoryReportRow> get categoryRows => _categoryRows;

  List<StockReportRow> _stockRows = const [];
  List<StockReportRow> get stockRows => _stockRows;

  List<ExpenseReportRow> _expenseRows = const [];
  List<ExpenseReportRow> get expenseRows => _expenseRows;

  PurchaseReportData _purchaseData = PurchaseReportData.empty;
  PurchaseReportData get purchaseData => _purchaseData;

  // Detail-panel selection (one per report; only the active report's matters).
  SaleReportInvoice? _selectedSale;
  SaleReportInvoice? get selectedSale => _selectedSale;

  SaleReturnReportInvoice? _selectedSaleReturn;
  SaleReturnReportInvoice? get selectedSaleReturn => _selectedSaleReturn;

  SaleExchangeRecord? _selectedSaleExchange;
  SaleExchangeRecord? get selectedSaleExchange => _selectedSaleExchange;

  CategoryReportRow? _selectedCategory;
  CategoryReportRow? get selectedCategory => _selectedCategory;

  StockReportRow? _selectedStock;
  StockReportRow? get selectedStock => _selectedStock;

  PurchaseReportInvoice? _selectedPurchase;
  PurchaseReportInvoice? get selectedPurchase => _selectedPurchase;

  PlDrill _plDrill = PlDrill.none;
  PlDrill get plDrill => _plDrill;

  void selectSale(SaleReportInvoice? v) => _select(() => _selectedSale = v);
  void selectSaleReturn(SaleReturnReportInvoice? v) =>
      _select(() => _selectedSaleReturn = v);
  void selectSaleExchange(SaleExchangeRecord? v) =>
      _select(() => _selectedSaleExchange = v);
  void selectCategory(CategoryReportRow? v) =>
      _select(() => _selectedCategory = v);
  void selectStock(StockReportRow? v) => _select(() => _selectedStock = v);
  void selectPurchase(PurchaseReportInvoice? v) =>
      _select(() => _selectedPurchase = v);
  void setPlDrill(PlDrill v) => _select(() => _plDrill = v);

  void _select(VoidCallback change) {
    _clearSelection();
    change();
    notifyListeners();
  }

  void clearSelection() {
    _clearSelection();
    notifyListeners();
  }

  void _clearSelection() {
    _selectedSale = null;
    _selectedSaleReturn = null;
    _selectedSaleExchange = null;
    _selectedCategory = null;
    _selectedStock = null;
    _selectedPurchase = null;
    _plDrill = PlDrill.none;
  }

  Future<void> setType(ReportType t) async {
    if (t == _type) return;
    _type = t;
    await load();
  }

  Future<void> setRange(DateTimeRange r) async {
    _range = r;
    await load();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    _clearSelection();
    notifyListeners();
    final from = _range.start;
    final to = _range.end;
    try {
      switch (_type) {
        case ReportType.sale:
          _saleRows = await _repository.saleReport(from, to);
        case ReportType.saleReturn:
          _saleReturnRows = await _repository.saleReturnReport(from, to);
        case ReportType.saleExchange:
          _saleExchangeRows = await _repository.saleExchangeReport(from, to);
        case ReportType.profitLoss:
          _profitLoss = await _repository.profitLoss(from, to);
        case ReportType.category:
          _categoryRows = await _repository.categoryReport(from, to);
        case ReportType.stock:
          _stockRows = await _repository.stockReport(from, to);
        case ReportType.expense:
          _expenseRows = await _repository.expenseReport(from, to);
        case ReportType.purchase:
          _purchaseData = await _repository.purchaseReport(from, to);
      }
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String _friendly(Object e) {
    final t = e.toString();
    if (t.contains('Database not connected')) {
      return 'Not connected to the database. Check the connection and retry.';
    }
    if (t.contains('42501')) return 'Permission denied reading the database.';
    return 'Could not build this report. Check the database connection.';
  }
}
