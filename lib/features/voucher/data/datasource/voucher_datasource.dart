import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../model/voucher_model.dart';

const _cols =
    'id, voucher_no, voucher_date, type, party, amount, payment_mode, reference, narration';

/// Talks to PostgreSQL for the Voucher feature.
class VoucherDataSource {
  const VoucherDataSource();

  Connection get _conn => Database.instance.connection;

  /// Creates the `voucher` table if missing. A permission error (42501) is
  /// ignored so the app still works when the table was created by
  /// lib/features/voucher/data/sql/voucher.sql.
  Future<void> ensureSchema() async {
    try {
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS voucher (
          id           SERIAL PRIMARY KEY,
          voucher_no   TEXT          NOT NULL DEFAULT '',
          voucher_date DATE          NOT NULL DEFAULT CURRENT_DATE,
          type         TEXT          NOT NULL DEFAULT 'payment',
          party        TEXT          NOT NULL DEFAULT '',
          amount       NUMERIC(14,2) NOT NULL DEFAULT 0,
          payment_mode TEXT          NOT NULL DEFAULT 'cash',
          reference    TEXT          NOT NULL DEFAULT '',
          narration    TEXT          NOT NULL DEFAULT '',
          created_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
        )
      ''');
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  Future<List<VoucherModel>> fetchAll({VoucherType? type}) async {
    final where = type == null ? '' : 'WHERE type = @type';
    final r = await _conn.execute(
      Sql.named('''
        SELECT $_cols FROM voucher
        $where
        ORDER BY voucher_date DESC, id DESC
      '''),
      parameters: type == null ? const {} : {'type': type.db},
    );
    return r.map((row) => VoucherModel.fromMap(row.toColumnMap())).toList();
  }

  Future<VoucherModel> insert(VoucherModel v) async {
    final r = await _conn.execute(
      Sql.named('''
        INSERT INTO voucher
          (voucher_no, voucher_date, type, party, amount, payment_mode, reference, narration)
        VALUES
          (@voucher_no, @voucher_date, @type, @party, @amount, @payment_mode, @reference, @narration)
        RETURNING $_cols
      '''),
      parameters: v.toMap()..remove('id'),
    );
    return VoucherModel.fromMap(r.first.toColumnMap());
  }

  Future<VoucherModel> update(VoucherModel v) async {
    final r = await _conn.execute(
      Sql.named('''
        UPDATE voucher SET
          voucher_no = @voucher_no, voucher_date = @voucher_date, type = @type,
          party = @party, amount = @amount, payment_mode = @payment_mode,
          reference = @reference, narration = @narration
        WHERE id = @id
        RETURNING $_cols
      '''),
      parameters: v.toMap(),
    );
    return VoucherModel.fromMap(r.first.toColumnMap());
  }

  Future<void> delete(int id) => _conn.execute(
        Sql.named('DELETE FROM voucher WHERE id = @id'),
        parameters: {'id': id},
      );
}
