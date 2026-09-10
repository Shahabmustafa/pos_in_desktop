import '../datasource/dashboard_datasource.dart';
import '../model/dashboard_model.dart';

/// Repository for the Dashboard feature. Presentation layer depends on this.
class DashboardRepository {
  DashboardRepository([DashboardDataSource? dataSource])
      : _dataSource = dataSource ?? const DashboardDataSource();

  final DashboardDataSource _dataSource;

  Future<DashboardSummary> getSummary() => _dataSource.fetchSummary();
}
