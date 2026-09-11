import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:postgres/postgres.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/database/database_connection.dart';
import '../../bank/data/datasource/bank_datasource.dart';
import '../../cash_register/data/datasource/cash_register_datasource.dart';
import '../../company/data/datasource/company_datasource.dart';
import '../../company_payment/data/datasource/company_payment_datasource.dart';
import '../../customer/data/datasource/customer_datasource.dart';
import '../../customer_payment/data/datasource/customer_payment_datasource.dart';
import '../../expense/data/datasource/expense_datasource.dart';
import '../../login/data/datasource/login_datasource.dart';
import '../../product_catalog/data/datasource/product_catalog_datasource.dart';
import '../../purchase/data/datasource/purchase_datasource.dart';
import '../../purchase_return/data/datasource/purchase_return_datasource.dart';
import '../../receipt_settings/data/datasource/receipt_settings_datasource.dart';
import '../../sale_exchange/data/datasource/sale_exchange_datasource.dart';
import '../../sale_invoice/data/datasource/held_sale_invoice_datasource.dart';
import '../../sale_invoice/data/datasource/sale_invoice_datasource.dart';
import '../../sale_return/data/datasource/sale_return_datasource.dart';
import '../../stock_inventory/data/datasource/stock_inventory_datasource.dart';
import '../../voucher/data/datasource/voucher_datasource.dart';

/// Raised for any backup / restore problem, with a message safe to show.
class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Outcome of a backup or restore run.
class BackupOutcome {
  const BackupOutcome({required this.tables, required this.rows});
  final int tables;
  final int rows;

  String get summary => '$rows row(s) across $tables table(s)';
}

/// Mirrors the whole local PostgreSQL database into a single Supabase table
/// (`pos_backup`) as JSON — one row per local record — and restores a fresh
/// machine from it.
class BackupService {
  BackupService({required this.supabaseUrl, required this.supabaseKey});

  final String supabaseUrl;
  final String supabaseKey;

  Connection get _local => Database.instance.connection;

  static const String cloudTable = 'pos_backup';

  /// Every table that is backed up, in a foreign-key-safe order (parents first)
  /// so a restore can insert straight down the list. `backup_settings` is
  /// deliberately excluded — the Supabase key must not leave the machine.
  static const List<String> tables = [
    'company',
    'customer',
    'product_category',
    'inventory_type',
    'users',
    'bank_head',
    'expense_head',
    'cash_account',
    'voucher',
    'receipt_settings',
    'stock_item',
    'sale_invoice',
    'purchase_invoice',
    'sale_return',
    'purchase_return',
    'held_sale_invoice',
    'sale_exchange',
    'sale_invoice_item',
    'purchase_invoice_item',
    'sale_return_item',
    'purchase_return_item',
    'sale_exchange_item',
    'bank_entry',
    'cash_entry',
    'expense_entry',
    'customer_payment',
    'company_payment',
  ];

  /// Tables kept when the local database is cleared — login and the shop
  /// header, so the till still works and looks right afterwards.
  static const Set<String> _keepOnClear = {'users', 'receipt_settings'};

  SupabaseClient _client() {
    final url = supabaseUrl.trim();
    final key = supabaseKey.trim();
    if (url.isEmpty || key.isEmpty) {
      throw BackupException('Set the Supabase URL and key first.');
    }
    if (!url.startsWith('http')) {
      throw BackupException('Supabase URL should look like ''https://<project>.supabase.co');
    }
    return SupabaseClient(url, key);
  }

  /// Creates every feature's tables locally if they are missing. Errors are
  /// swallowed per feature so one missing dependency cannot block the rest.
  Future<void> ensureLocalSchemas() async {
    Future<void> tryEnsure(Future<void> Function() f) async {
      try {
        await f();
      } catch (_) {/* keep going */}
    }

    await tryEnsure(const CompanyDataSource().ensureSchema);
    await tryEnsure(const CustomerDataSource().ensureSchema);
    await tryEnsure(const CustomerDataSource().ensureWalkInCustomer);
    await tryEnsure(const ProductCatalogDataSource().ensureSchema);
    await tryEnsure(const StockInventoryDataSource().ensureSchema);
    await tryEnsure(const BankDataSource().ensureSchema);
    await tryEnsure(const ExpenseDataSource().ensureSchema);
    await tryEnsure(const CashRegisterDataSource().ensureSchema);
    await tryEnsure(const VoucherDataSource().ensureSchema);
    await tryEnsure(const CustomerPaymentDataSource().ensureSchema);
    await tryEnsure(const CompanyPaymentDataSource().ensureSchema);
    await tryEnsure(const ReceiptSettingsDataSource().ensureSchema);
    await tryEnsure(LoginDataSource().ensureSchema);
    await tryEnsure(const SaleInvoiceDataSource().ensureSchema);
    await tryEnsure(const HeldSaleInvoiceDataSource().ensureSchema);
    await tryEnsure(const PurchaseDataSource().ensureSchema);
    await tryEnsure(const SaleReturnDataSource().ensureSchema);
    await tryEnsure(const PurchaseReturnDataSource().ensureSchema);
    await tryEnsure(const SaleExchangeDataSource().ensureSchema);
  }

  Future<Set<String>> _existingTables() async {
    final rows = await _local.execute(
      "SELECT tablename FROM pg_tables WHERE schemaname = 'public'",
    );
    return {for (final r in rows) r[0] as String};
  }

  // ── Backup ─────────────────────────────────────────────────────────
  /// Pushes every local row into Supabase, then removes cloud rows that no
  /// longer exist locally.
  Future<BackupOutcome> backup() async {
    await ensureLocalSchemas();
    final client = _client();
    final runAt = DateTime.now().toUtc();
    final runAtIso = runAt.toIso8601String();
    var tableCount = 0;
    var rowCount = 0;

    try {
      final present = await _existingTables();
      for (final table in tables) {
        if (!present.contains(table)) continue;
        final rows = await _local.execute('SELECT * FROM $table');
        final payload = <Map<String, dynamic>>[];
        for (final row in rows) {
          final map = row.toColumnMap();
          final id = (map['id'] as num?)?.toInt();
          if (id == null) continue;
          payload.add({
            'table_name': table,
            'row_id': id,
            'data': _encodeRow(map),
            'backed_up_at': runAtIso,
          });
        }
        for (final chunk in _chunks(payload, 400)) {
          await client
              .from(cloudTable)
              .upsert(chunk, onConflict: 'table_name,row_id');
        }
        tableCount++;
        rowCount += payload.length;
      }

      // Anything not touched this run was deleted locally → drop it.
      await client.from(cloudTable).delete().lt('backed_up_at', runAtIso);

      return BackupOutcome(tables: tableCount, rows: rowCount);
    } on PostgrestException catch (e) {
      throw BackupException(_supabaseError(e));
    } finally {
      await client.dispose();
    }
  }

  // ── Restore ────────────────────────────────────────────────────────
  Future<bool> isLocalEmpty() async {
    await ensureLocalSchemas();
    final r = await _local.execute('''
      SELECT
        (SELECT count(*) FROM stock_item) +
        (SELECT count(*) FROM sale_invoice) +
        (SELECT count(*) FROM purchase_invoice) AS n
    ''');
    return ((r.first.toColumnMap()['n'] as num?) ?? 0) == 0;
  }

  /// Pulls the whole backup from Supabase into the local database. Only runs on
  /// an empty local database so it can never overwrite live data.
  Future<BackupOutcome> restore() async {
    await ensureLocalSchemas();
    if (!await isLocalEmpty()) {
      throw BackupException(
        'The local database already has data. Restore only runs on a fresh, '
        'empty database.',
      );
    }

    final client = _client();
    try {
      final byTable = <String, List<Map<String, dynamic>>>{};
      const page = 1000;
      var from = 0;
      while (true) {
        final res = await client
            .from(cloudTable)
            .select('table_name, row_id, data')
            .order('table_name')
            .order('row_id')
            .range(from, from + page - 1);
        if (res.isEmpty) break;
        for (final row in res) {
          (byTable[row['table_name'] as String] ??= [])
              .add((row['data'] as Map).cast<String, dynamic>());
        }
        if (res.length < page) break;
        from += page;
      }

      if (byTable.isEmpty) {
        throw BackupException('No backup was found in Supabase.');
      }

      var tableCount = 0;
      var rowCount = 0;
      final present = await _existingTables();
      final targets = tables
          .where((t) => byTable.containsKey(t) && present.contains(t))
          .toList();
      if (targets.isEmpty) {
        throw BackupException('The backup has no tables this app recognises.');
      }

      await _local.runTx((s) async {
        await s.execute(
          'TRUNCATE ${targets.join(', ')} RESTART IDENTITY CASCADE',
        );
        for (final table in targets) {
          final rows = byTable[table]!;
          if (rows.isEmpty) continue;
          await s.execute(
            Sql.named(
              'INSERT INTO $table '
              'SELECT * FROM jsonb_populate_recordset(NULL::$table, @j::jsonb)',
            ),
            parameters: {'j': jsonEncode(rows)},
          );
          // Move each SERIAL sequence past the ids we just forced in.
          await s.execute(
            "SELECT setval(pg_get_serial_sequence('$table', 'id'), "
            "GREATEST((SELECT COALESCE(MAX(id), 1) FROM $table), 1))",
          );
          tableCount++;
          rowCount += rows.length;
        }
      });

      return BackupOutcome(tables: tableCount, rows: rowCount);
    } on PostgrestException catch (e) {
      throw BackupException(_supabaseError(e));
    } finally {
      await client.dispose();
    }
  }

  // ── Export to CSV + clear ──────────────────────────────────────────
  /// Writes every table to `<dirPath>/pos_export_<timestamp>/<table>.csv` and
  /// returns the folder path plus the counts.
  Future<({String folder, int tables, int rows})> exportCsv(
      String dirPath) async {
    await ensureLocalSchemas();
    final now = DateTime.now();
    String p2(int v) => v.toString().padLeft(2, '0');
    final folder = Directory(
      '$dirPath/pos_export_${now.year}${p2(now.month)}${p2(now.day)}'
      '_${p2(now.hour)}${p2(now.minute)}${p2(now.second)}',
    );
    await folder.create(recursive: true);

    final present = await _existingTables();
    var fileCount = 0;
    var rowCount = 0;
    for (final table in tables) {
      if (!present.contains(table)) continue;
      final colRows = await _local.execute(
        Sql.named(
          "SELECT column_name FROM information_schema.columns "
          "WHERE table_schema = 'public' AND table_name = @t "
          "ORDER BY ordinal_position",
        ),
        parameters: {'t': table},
      );
      final cols = [for (final r in colRows) r[0] as String];
      if (cols.isEmpty) continue;

      final rows = await _local.execute('SELECT * FROM $table');
      final buf = StringBuffer()
        ..writeln(cols.map(_csvField).join(','));
      for (final row in rows) {
        final map = row.toColumnMap();
        buf.writeln(cols.map((c) => _csvField(_csvValue(map[c]))).join(','));
      }
      await File('${folder.path}/$table.csv')
          .writeAsString(buf.toString(), flush: true);
      fileCount++;
      rowCount += rows.length;
    }
    return (folder: folder.path, tables: fileCount, rows: rowCount);
  }

  /// Permanently deletes every row from the business tables (keeping login and
  /// the shop header). Returns how many rows were removed.
  Future<int> clearLocal() async {
    await ensureLocalSchemas();
    final present = await _existingTables();
    final targets = tables
        .where((t) => !_keepOnClear.contains(t) && present.contains(t))
        .toList();
    if (targets.isEmpty) return 0;

    final counts = await _local.execute(
      'SELECT ${targets.map((t) => '(SELECT count(*) FROM $t)').join(' + ')} '
      'AS n',
    );
    final removed = ((counts.first.toColumnMap()['n'] as num?) ?? 0).toInt();

    await _local.execute(
      'TRUNCATE ${targets.join(', ')} RESTART IDENTITY CASCADE',
    );
    // Re-seed the rows the app expects to exist.
    await ensureLocalSchemas();
    return removed;
  }

  static String _csvValue(Object? v) => switch (v) {
        null => '',
        DateTime t => t.toIso8601String(),
        Uint8List b => base64Encode(b),
        List<int> b => base64Encode(b),
        _ => v.toString(),
      };

  static String _csvField(String v) {
    final needsQuote =
        v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r');
    final escaped = v.replaceAll('"', '""');
    return needsQuote ? '"$escaped"' : escaped;
  }

  // ── helpers ────────────────────────────────────────────────────────
  /// Converts a PostgreSQL row into JSON-safe values that
  /// `jsonb_populate_recordset` can read straight back into the same columns.
  static Map<String, dynamic> _encodeRow(Map<String, dynamic> row) {
    final out = <String, dynamic>{};
    row.forEach((key, value) {
      out[key] = switch (value) {
        null => null,
        bool b => b,
        int i => i,
        double d => d,
        DateTime t => t.toIso8601String(),
        Uint8List bytes => '\\x${_hex(bytes)}',
        List<int> bytes => '\\x${_hex(Uint8List.fromList(bytes))}',
        String s => s,
        _ => value.toString(),
      };
    });
    return out;
  }

  static String _hex(Uint8List b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  static Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }

  static String _supabaseError(PostgrestException e) {
    final m = e.message;
    if (m.contains('does not exist') || e.code == '42P01') {
      return 'The "pos_backup" table is missing in Supabase. Run '
          'lib/features/backup/data/sql/supabase_backup.sql there first.';
    }
    if (e.code == '401' || e.code == '403' || m.contains('JWT')) {
      return 'Supabase rejected the key. Check the URL and paste the '
          'service_role key.';
    }
    return 'Supabase error: $m';
  }
}
