import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/money_formatter.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';

/// Génère et partage les exports CSV / PDF des transactions (module 3.5).
class ExportService {
  ExportService(this._categories, this._accounts);

  final CategoryRepository _categories;
  final AccountRepository _accounts;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  List<List<String>> _rows(List<AppTransaction> txs) {
    final rows = <List<String>>[
      ['Date', 'Type', 'Catégorie', 'Compte', 'Note', 'Montant'],
    ];
    for (final t in txs) {
      final cat = t.categoryId == null
          ? ''
          : (_categories.getById(t.categoryId!)?.name ?? '');
      final acc = _accounts.getById(t.accountId)?.name ?? '';
      rows.add([
        _dateFmt.format(t.date),
        t.type == TransactionType.income ? 'Revenu' : 'Dépense',
        cat,
        acc,
        t.note ?? '',
        MoneyFormatter.toInput(t.signedAmount),
      ]);
    }
    return rows;
  }

  Future<void> exportCsv(List<AppTransaction> txs, String label) async {
    // Csv.excel() : séparateur ';' + BOM (compatible Excel et accents FR).
    final csv = Csv.excel().encode(_rows(txs));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/fintrack_$label.csv');
    await file.writeAsString(csv);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Export FinTrack — $label',
      ),
    );
  }

  Future<void> exportPdf(
    List<AppTransaction> txs,
    String label, {
    required int income,
    required int expense,
  }) async {
    final doc = pw.Document();
    final rows = _rows(txs);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, text: 'FinTrack — $label'),
          pw.Text('Revenus : ${MoneyFormatter.format(income)}'),
          pw.Text('Dépenses : ${MoneyFormatter.format(expense)}'),
          pw.Text('Solde : ${MoneyFormatter.format(income - expense)}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: rows.first,
            data: rows.skip(1).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'fintrack_$label.pdf');
  }
}
