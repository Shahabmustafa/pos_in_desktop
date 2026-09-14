import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../../../purchase/data/datasource/purchase_datasource.dart';
import '../../../purchase/data/model/purchase_model.dart';
import '../model/purchase_return_item_model.dart';
import '../model/purchase_return_model.dart';

const _headCols =
    'id, invoice_no, return_date, company_id, company_name, reference, remarks';
const _itemCols =
    'id, purchase_return_id, product_id, product_name, barcode, quantity, '
    'unit_price, sale_price, discount, tax, line_total';

/// One purchase-invoice line the user chose to send back, with the quantity.
typedef PurchaseReturnSelection = ({PurchaseItemModel item, double qty});

/// Talks to PostgreSQL for the Purchase Return feature.
///
/// A return is always made *against an existing purchase invoice*. Returning
/// every line in full deletes the invoice; returning less shrinks it. Either
/// way a `purchase_return` header + lines are written for the record — the
/// stock movement comes from the invoice delete / update, so the
/// `purchase_return` rows carry no side effects.
class PurchaseReturnDataSource {
  const PurchaseReturnDataSource();

  Connection get _conn => Database.instance.connection;

  /// Creates the `purchase_return` and `purchase_return_item` tables if missing.
  /// A permission error (42501) is ignored so the app still works when the
  /// tables were created by
  /// lib/features/purchase_return/data/sql/purchase_return.sql.
  Future<void> ensureSchema() async {
    await const PurchaseDataSource().ensureSchema();
    try {
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS purchase_return (
          id             SERIAL PRIMARY KEY,
          invoice_no     TEXT          NOT NULL DEFAULT '',
          return_date    DATE          NOT NULL DEFAULT CURRENT_DATE,
          company_id     INTEGER       REFERENCES company(id),
          company_name   TEXT          NOT NULL DEFAULT '',
          reference      TEXT          NOT NULL DEFAULT '',
          remarks        TEXT          NOT NULL DEFAULT '',
          subtotal       NUMERIC(14,2) NOT NULL DEFAULT 0,
          discount_total NUMERIC(14,2) NOT NULL DEFAULT 0,
          tax_total      NUMERIC(14,2) NOT NULL DEFAULT 0,
          grand_total    NUMERIC(14,2) NOT NULL DEFAULT 0,
          created_at     TIMESTAMPTZ   NOT NULL DEFAULT now()
        )
      ''');
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS purchase_return_item (
          id                 SERIAL PRIMARY KEY,
          purchase_return_id INTEGER       NOT NULL
                             REFERENCES purchase_return(id) ON DELETE CASCADE,
          product_id         INTEGER       REFERENCES stock_item(id),
          product_name       TEXT          NOT NULL DEFAULT '',
          barcode            TEXT          NOT NULL DEFAULT '',
          quantity           NUMERIC(14,2) NOT NULL DEFAULT 0,
          unit_price         NUMERIC(14,2) NOT NULL DEFAULT 0,
          sale_price         NUMERIC(14,2) NOT NULL DEFAULT 0,
          discount           NUMERIC(6,2)  NOT NULL DEFAULT 0,
          tax                NUMERIC(6,2)  NOT NULL DEFAULT 0,
          line_total         NUMERIC(14,2) NOT NULL DEFAULT 0
        )
      ''');
      await _conn.execute(
        'ALTER TABLE purchase_return_item '
        'ADD COLUMN IF NOT EXISTS sale_price NUMERIC(14,2) NOT NULL DEFAULT 0',
      );
      await _conn.execute(
        'CREATE INDEX IF NOT EXISTS idx_pr_item_return '
        'ON purchase_return_item(purchase_return_id)',
      );
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  /// Every purchase invoice, newest first, with its lines — the list the
  /// Purchase Return screen shows.
  Future<List<PurchaseModel>> fetchPurchaseInvoices() =>
      const PurchaseDataSource().fetchAll();

  /// Every return, newest first, each with its line items. Kept for Reports.
  Future<List<PurchaseReturnModel>> fetchAll() async {
    final heads = await _conn.execute(
      'SELECT $_headCols FROM purchase_return '
      'ORDER BY return_date DESC, id DESC',
    );
    if (heads.isEmpty) return const [];

    final itemRows = await _conn.execute(
      'SELECT $_itemCols FROM purchase_return_item ORDER BY id',
    );
    final itemsByReturn = <int, List<PurchaseReturnItemModel>>{};
    for (final row in itemRows) {
      final m = row.toColumnMap();
      (itemsByReturn[m['purchase_return_id'] as int] ??= [])
          .add(PurchaseReturnItemModel.fromMap(m));
    }

    return heads.map((row) {
      final m = row.toColumnMap();
      return PurchaseReturnModel.fromMap(
        m,
        items: itemsByReturn[m['id'] as int] ?? const [],
      );
    }).toList();
  }

  /// Sends the picked [selections] back off purchase invoice [invoice].
  ///
  /// * Every line returned in full → the whole `purchase_invoice` is deleted.
  /// * Otherwise → the returned quantities are subtracted from the invoice
  ///   lines (a line hitting zero is removed) and the header totals recomputed.
  ///
  /// In both cases the returned goods leave `stock_item.quantity` and a
  /// `purchase_return` header + lines are written for the record.
  Future<void> returnFromInvoice({
    required PurchaseModel invoice,
    required List<PurchaseReturnSelection> selections,
  }) {
    final invoiceId = invoice.id;
    if (invoiceId == null || selections.isEmpty) return Future.value();

    return _conn.runTx((tx) async {
      // 1. Goods go back to the supplier → remove from stock.
      for (final sel in selections) {
        await _addStock(tx, sel.item.productId, -sel.qty);
      }

      if (_isFullReturn(invoice, selections)) {
        // Reverse the whole invoice's effect on the company's balance.
        await _adjustCompanyBalance(
          tx,
          invoice.companyId,
          -(invoice.grandTotal - invoice.amountPaid),
        );
        await tx.execute(
          Sql.named('DELETE FROM purchase_invoice_item '
              'WHERE purchase_invoice_id = @id'),
          parameters: {'id': invoiceId},
        );
        await tx.execute(
          Sql.named('DELETE FROM purchase_invoice WHERE id = @id'),
          parameters: {'id': invoiceId},
        );
      } else {
        await _shrinkInvoice(tx, invoice, selections);
      }

      await _insertReturnRecord(
        tx,
        PurchaseReturnModel(
          returnDate: DateTime.now(),
          companyId: invoice.companyId,
          companyName: invoice.companyName,
          reference: _invoiceLabel(invoice),
          remarks: 'Return against ${_invoiceLabel(invoice)}',
          items: [
            for (final sel in selections)
              PurchaseReturnItemModel(
                productId: sel.item.productId,
                productName: sel.item.productName,
                barcode: sel.item.barcode,
                quantity: sel.qty,
                unitPrice: sel.item.purchasePrice,
                salePrice: sel.item.salePrice,
                discount: sel.item.discount,
                tax: sel.item.tax,
              ),
          ],
        ),
      );
    });
  }

  bool _isFullReturn(
      PurchaseModel invoice, List<PurchaseReturnSelection> selections) {
    if (selections.length != invoice.items.length) return false;
    final qtyById = {for (final sel in selections) sel.item.id: sel.qty};
    for (final it in invoice.items) {
      final ret = qtyById[it.id];
      if (ret == null || (it.quantity - ret).abs() > 1e-6) return false;
    }
    return true;
  }

  Future<void> _shrinkInvoice(
    TxSession tx,
    PurchaseModel invoice,
    List<PurchaseReturnSelection> selections,
  ) async {
    final retById = {for (final sel in selections) sel.item.id: sel.qty};
    final kept = <PurchaseItemModel>[];

    for (final it in invoice.items) {
      final ret = retById[it.id] ?? 0;
      final keptQty = it.quantity - ret;
      if (keptQty <= 1e-6) {
        if (ret > 0) {
          await tx.execute(
            Sql.named('DELETE FROM purchase_invoice_item WHERE id = @id'),
            parameters: {'id': it.id},
          );
        }
        continue;
      }
      final keptItem = it.copyWith(quantity: keptQty);
      kept.add(keptItem);
      if (ret > 0) {
        await tx.execute(
          Sql.named('UPDATE purchase_invoice_item '
              'SET quantity = @q, line_total = @lt WHERE id = @id'),
          parameters: {'q': keptQty, 'lt': keptItem.lineTotal, 'id': it.id},
        );
      }
    }

    final shrunk = invoice.copyWith(items: kept);
    await tx.execute(
      Sql.named('''
        UPDATE purchase_invoice SET
          subtotal = @subtotal, discount_total = @discount_total,
          tax_total = @tax_total, grand_total = @grand_total
        WHERE id = @id
      '''),
      parameters: {
        'id': invoice.id,
        'subtotal': shrunk.subtotal,
        'discount_total': shrunk.discountTotal,
        'tax_total': shrunk.taxTotal,
        'grand_total': shrunk.grandTotal,
      },
    );

    // Mirror a normal invoice edit: with the amount already paid unchanged,
    // the company's balance moves by the change in the invoice total.
    await _adjustCompanyBalance(
      tx,
      invoice.companyId,
      shrunk.grandTotal - invoice.grandTotal,
    );
  }

  /// Inserts a `purchase_return` header (with a server-assigned `PR-xxxxxx`
  /// number) and its lines. Does NOT touch stock.
  Future<void> _insertReturnRecord(TxSession tx, PurchaseReturnModel p) async {
    final head = await tx.execute(
      Sql.named('''
        INSERT INTO purchase_return
          (return_date, company_id, company_name, reference, remarks,
           subtotal, discount_total, tax_total, grand_total)
        VALUES
          (@return_date, @company_id, @company_name, @reference, @remarks,
           @subtotal, @discount_total, @tax_total, @grand_total)
        RETURNING id
      '''),
      parameters: {
        'return_date': p.returnDate,
        'company_id': p.companyId,
        'company_name': p.companyName,
        'reference': p.reference,
        'remarks': p.remarks,
        'subtotal': p.subtotal,
        'discount_total': p.discountTotal,
        'tax_total': p.taxTotal,
        'grand_total': p.grandTotal,
      },
    );
    final id = head.first.toColumnMap()['id'] as int;
    await tx.execute(
      Sql.named("UPDATE purchase_return "
          "SET invoice_no = 'PR-' || lpad(@id::text, 6, '0') WHERE id = @id"),
      parameters: {'id': id},
    );
    for (final item in p.items) {
      await tx.execute(
        Sql.named('''
          INSERT INTO purchase_return_item
            (purchase_return_id, product_id, product_name, barcode, quantity,
             unit_price, sale_price, discount, tax, line_total)
          VALUES
            (@purchase_return_id, @product_id, @product_name, @barcode, @quantity,
             @unit_price, @sale_price, @discount, @tax, @line_total)
        '''),
        parameters: item.toMap()
          ..remove('id')
          ..['purchase_return_id'] = id,
      );
    }
  }

  static String _invoiceLabel(PurchaseModel i) =>
      i.invoiceNo.trim().isNotEmpty ? i.invoiceNo.trim() : 'invoice #${i.id}';

  /// Adds [delta] (may be negative) to `company.opening_balance`.
  Future<void> _adjustCompanyBalance(
      TxSession tx, int? companyId, double delta) async {
    if (companyId == null || delta == 0) return;
    await tx.execute(
      Sql.named('UPDATE company SET opening_balance = opening_balance + @d '
          'WHERE id = @id'),
      parameters: {'d': delta, 'id': companyId},
    );
  }

  /// Adds [delta] (may be negative) to `stock_item.quantity` for [productId].
  Future<void> _addStock(TxSession tx, int? productId, double delta) async {
    if (productId == null || delta == 0) return;
    await tx.execute(
      Sql.named('UPDATE stock_item SET quantity = quantity + @d WHERE id = @id'),
      parameters: {'d': delta, 'id': productId},
    );
  }

  Future<void> delete(int id) => _conn.runTx((tx) async {
        await tx.execute(
          Sql.named('DELETE FROM purchase_return WHERE id = @id'),
          parameters: {'id': id},
        );
      });
}
