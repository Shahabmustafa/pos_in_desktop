import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../model/receipt_settings_model.dart';

const _columns = 'business_name, business_address, business_phone, footer_text, '
    'logo, show_logo, show_invoice_no, show_date, show_party, show_notes, '
    'show_item_discount, show_discount_total, show_tax_total, show_paid_balance, '
    'show_item_count, show_footer';

/// Talks to PostgreSQL for the Receipt Settings feature. One row, `id = 1`.
class ReceiptSettingsDataSource {
  const ReceiptSettingsDataSource();

  Connection get _conn => Database.instance.connection;

  /// Creates `receipt_settings` if missing and guarantees the single row. A
  /// permission error (42501) is ignored so the app still works when the table
  /// was created by lib/features/receipt_settings/data/sql/receipt_settings.sql.
  Future<void> ensureSchema() async {
    try {
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS receipt_settings (
          id                  SMALLINT     PRIMARY KEY DEFAULT 1,
          business_name       TEXT         NOT NULL DEFAULT 'POS',
          business_address    TEXT         NOT NULL DEFAULT '',
          business_phone      TEXT         NOT NULL DEFAULT '',
          footer_text         TEXT         NOT NULL DEFAULT 'Thank you for shopping!',
          logo                BYTEA,
          show_logo           BOOLEAN      NOT NULL DEFAULT TRUE,
          show_invoice_no     BOOLEAN      NOT NULL DEFAULT TRUE,
          show_date           BOOLEAN      NOT NULL DEFAULT TRUE,
          show_party          BOOLEAN      NOT NULL DEFAULT TRUE,
          show_notes          BOOLEAN      NOT NULL DEFAULT FALSE,
          show_item_discount  BOOLEAN      NOT NULL DEFAULT TRUE,
          show_discount_total BOOLEAN      NOT NULL DEFAULT TRUE,
          show_tax_total      BOOLEAN      NOT NULL DEFAULT TRUE,
          show_paid_balance   BOOLEAN      NOT NULL DEFAULT TRUE,
          show_item_count     BOOLEAN      NOT NULL DEFAULT TRUE,
          show_footer         BOOLEAN      NOT NULL DEFAULT TRUE,
          updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
          CONSTRAINT receipt_settings_one_row CHECK (id = 1)
        )
      ''');
      // Add columns that shipped after the first release (existing installs).
      await _conn.execute(
        'ALTER TABLE receipt_settings ADD COLUMN IF NOT EXISTS logo BYTEA',
      );
      await _conn.execute(
        'ALTER TABLE receipt_settings ADD COLUMN IF NOT EXISTS show_logo '
        'BOOLEAN NOT NULL DEFAULT TRUE',
      );
      await _conn.execute(
        'INSERT INTO receipt_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING',
      );
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  Future<ReceiptSettingsModel> fetch() async {
    final rows = await _conn.execute(
      'SELECT $_columns FROM receipt_settings WHERE id = 1',
    );
    if (rows.isEmpty) return const ReceiptSettingsModel();
    return ReceiptSettingsModel.fromMap(rows.first.toColumnMap());
  }

  Future<ReceiptSettingsModel> save(ReceiptSettingsModel s) async {
    final rows = await _conn.execute(
      Sql.named('''
        UPDATE receipt_settings SET
          business_name = @business_name,
          business_address = @business_address,
          business_phone = @business_phone,
          footer_text = @footer_text,
          logo = @logo,
          show_logo = @show_logo,
          show_invoice_no = @show_invoice_no,
          show_date = @show_date,
          show_party = @show_party,
          show_notes = @show_notes,
          show_item_discount = @show_item_discount,
          show_discount_total = @show_discount_total,
          show_tax_total = @show_tax_total,
          show_paid_balance = @show_paid_balance,
          show_item_count = @show_item_count,
          show_footer = @show_footer,
          updated_at = now()
        WHERE id = 1
        RETURNING $_columns
      '''),
      parameters: {
        ...s.toMap(),
        // Give the driver an explicit type so a null logo still binds.
        'logo': TypedValue(Type.byteArray, s.logo),
      },
    );
    return ReceiptSettingsModel.fromMap(rows.first.toColumnMap());
  }
}
