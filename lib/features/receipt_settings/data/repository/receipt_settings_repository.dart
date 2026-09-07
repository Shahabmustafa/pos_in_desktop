import '../datasource/receipt_settings_datasource.dart';
import '../model/receipt_settings_model.dart';

/// Repository for the Receipt Settings feature. Presentation depends on this.
class ReceiptSettingsRepository {
  ReceiptSettingsRepository([ReceiptSettingsDataSource? dataSource])
      : _dataSource = dataSource ?? const ReceiptSettingsDataSource();

  final ReceiptSettingsDataSource _dataSource;

  Future<void> ensureSchema() => _dataSource.ensureSchema();

  Future<ReceiptSettingsModel> get() => _dataSource.fetch();

  Future<ReceiptSettingsModel> save(ReceiptSettingsModel model) =>
      _dataSource.save(model);
}

/// Loads the receipt settings into [ReceiptSettingsModel.current] once at
/// startup so receipts print with the configured header even if the user never
/// opens the settings screen. Any failure is swallowed — receipts then fall
/// back to the const defaults.
Future<void> preloadReceiptSettings() async {
  try {
    const ds = ReceiptSettingsDataSource();
    await ds.ensureSchema();
    ReceiptSettingsModel.current = await ds.fetch();
  } catch (_) {
    // Offline / table missing — receipts use ReceiptSettingsModel defaults.
  }
}
