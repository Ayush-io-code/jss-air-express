// lib/screens/bill_preview_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xl;
import '../providers/app_provider.dart';
import '../models/bill.dart';
import '../models/totals.dart';
import '../models/company_info.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../utils/bill_exporter.dart';
import '../widgets/common_widgets.dart';

// ── Excel amount helper: replaces ₹ with Rs. (excel package can't encode ₹) ──
String _ea(String v) => v.replaceAll('₹', 'Rs.');

class BillPreviewScreen extends StatefulWidget {
  final String billId;
  const BillPreviewScreen({super.key, required this.billId});

  @override
  State<BillPreviewScreen> createState() => _BillPreviewScreenState();
}

class _BillPreviewScreenState extends State<BillPreviewScreen> {
  bool _sharing = false;
  bool _downloading = false;

  // ── Edit bill number / date ─────────────────────────────────────────────────
  Future<void> _editBillMeta(Bill bill) async {
    final noCtrl   = TextEditingController(text: bill.billNo);
    final dateCtrl = TextEditingController(text: bill.billDate);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Bill'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: noCtrl,
              decoration: const InputDecoration(
                labelText: 'Bill Number',
                hintText: 'e.g. 25',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dateCtrl,
              decoration: const InputDecoration(
                labelText: 'Bill Date (YYYY-MM-DD)',
                hintText: 'e.g. 2026-05-26',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.datetime,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final newNo   = noCtrl.text.trim();
    final newDate = dateCtrl.text.trim();
    if (newNo.isEmpty) return;

    final app = context.read<AppProvider>();
    final ok  = await app.updateBillMeta(bill.id, newNo, newDate);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill number already exists for this party.'),
        ),
      );
    }
  }

  // ── PDF share ───────────────────────────────────────────────────────────────
  Future<void> _sharePdf(String partyName, String billNo) async {
    // Ask user: standard multi-page or compact single-page
    final compact = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('PDF Format'),
        content: const Text(
          'How would you like to export this bill?\n\n'
          '• Standard — normal size, may span 2–3 pages if many entries.\n'
          '• Compact — smaller text & spacing, fits everything on 1 page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Standard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Compact (1 page)'),
          ),
        ],
      ),
    );
    if (compact == null) return; // dismissed
    setState(() => _sharing = true);
    try {
      final app = context.read<AppProvider>();
      final bill = app.billById(widget.billId);
      if (bill == null) return;
      final party = app.partyById(bill.partyId);
      final totals = Totals.calc(bill.entries, party);

      final pdfBytes = await _buildPdfBytes(
          bill, partyName, billNo, totals, party, app.company,
          compact: compact);

      final dir = await getTemporaryDirectory();
      final safeName = partyName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final file = File('${dir.path}/JSS_Bill_${billNo}_$safeName.pdf');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'JSS Bill #$billNo — $partyName',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF share failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Builds a PDF using the `pdf` package with a bundled TTF font so that
  /// the ₹ (Rupee) symbol renders correctly on all devices.
  Future<List<int>> _buildPdfBytes(
      bill, String partyName, String billNo, Totals t, party, CompanyInfo co,
      {bool compact = false}) async {
    final doc = pw.Document();

    // ── Load bundled fonts (supports ₹ glyph) ──
    final regularData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final boldData    = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final ttf         = pw.Font.ttf(regularData);
    final ttfBold     = pw.Font.ttf(boldData);

    final navy     = PdfColor.fromHex('#1A3A5C');
    final white    = PdfColors.white;
    final grey     = PdfColor.fromHex('#555555');
    final lightRow = PdfColor.fromHex('#F5F8FC');
    final subColor = PdfColor.fromHex('#BDD5EC');

    // Scale factor for compact mode
    final s = compact ? 0.78 : 1.0;

    final headerStyle   = pw.TextStyle(font: ttfBold,    fontSize: 16 * s, color: white);
    final subStyle      = pw.TextStyle(font: ttf,        fontSize: 7  * s, color: subColor);
    final labelStyle    = pw.TextStyle(font: ttfBold,    fontSize: 8  * s);
    final valueStyle    = pw.TextStyle(font: ttf,        fontSize: 8  * s);
    final tableHdrStyle = pw.TextStyle(font: ttfBold,    fontSize: 7  * s, color: white);
    final cellStyle     = pw.TextStyle(font: ttf,        fontSize: 7  * s);
    final totLabelStyle = pw.TextStyle(font: ttf,        fontSize: 8  * s, color: grey);
    final totValueStyle = pw.TextStyle(font: ttfBold,    fontSize: 8  * s);
    final netStyle      = pw.TextStyle(font: ttfBold,    fontSize: 9  * s, color: navy);
    final wordsStyle    = pw.TextStyle(font: ttf,        fontSize: 7  * s, color: navy,
                              fontStyle: pw.FontStyle.italic);
    final bankHdrStyle  = pw.TextStyle(font: ttfBold,    fontSize: 8  * s, color: navy);
    final bankStyle     = pw.TextStyle(font: ttf,        fontSize: 7  * s);
    final sigStyle      = pw.TextStyle(font: ttfBold,    fontSize: 8  * s);

    final address  = party?.address  ?? '—';
    final gstin    = (party?.gstin  ?? '').isEmpty  ? '—' : party!.gstin;
    final phone    = (party?.phone  ?? '').isEmpty  ? '—' : party!.phone;

    // Pre-compute rounded amounts and words
    final netRounded   = _pdfAmt(fmtINRRounded(t.net));
    final netWords     = amountInWords(t.net);

    // ── Helper that builds the full bill content as a single Column ──
    pw.Widget _buildContent(double scale) {
      // Re-derive scaled styles from the passed scale value
      final hs   = pw.TextStyle(font: ttfBold, fontSize: 16 * scale, color: white);
      final ss   = pw.TextStyle(font: ttf,     fontSize: 7  * scale, color: subColor);
      final ls   = pw.TextStyle(font: ttfBold, fontSize: 8  * scale);
      final vs   = pw.TextStyle(font: ttf,     fontSize: 8  * scale);
      final ths  = pw.TextStyle(font: ttfBold, fontSize: 7  * scale, color: white);
      final cs   = pw.TextStyle(font: ttf,     fontSize: 7  * scale);
      final tls  = pw.TextStyle(font: ttf,     fontSize: 8  * scale, color: grey);
      final tvs  = pw.TextStyle(font: ttfBold, fontSize: 8  * scale);
      final ns   = pw.TextStyle(font: ttfBold, fontSize: 9  * scale, color: navy);
      final bhs  = pw.TextStyle(font: ttfBold, fontSize: 8  * scale, color: navy);
      final bs   = pw.TextStyle(font: ttf,     fontSize: 7  * scale);
      final sigs = pw.TextStyle(font: ttfBold, fontSize: 8  * scale);

      final gap1 = 4 * scale;
      final gap2 = 8 * scale;

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Company header ──
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.all(7 * scale),
            decoration: pw.BoxDecoration(color: navy),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(co.name, style: hs),
                pw.SizedBox(height: 3 * scale),
                pw.Text(co.address, textAlign: pw.TextAlign.center, style: ss),
                pw.SizedBox(height: 2 * scale),
                pw.Text(
                    'Phone: ${co.phone} | Email: ${co.email} | GST: ${co.gst}',
                    textAlign: pw.TextAlign.center,
                    style: ss),
                ...co.extraFields.map((ef) => pw.Text(
                      '${ef.label}: ${ef.value}',
                      textAlign: pw.TextAlign.center,
                      style: ss,
                    )),
              ],
            ),
          ),
          pw.SizedBox(height: gap1),

          // ── Party & Bill info ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfInfoRow('Party',   partyName,                          ls, vs),
                    _pdfInfoRow('Address', address.isEmpty ? '—' : address,    ls, vs),
                    _pdfInfoRow('GSTIN',   gstin,                              ls, vs),
                  ],
                ),
              ),
              pw.SizedBox(width: 20 * scale),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfInfoRow('Bill No', '2026/$billNo',         ls, vs),
                    _pdfInfoRow('Date',    fmtDate(bill.billDate), ls, vs),
                    _pdfInfoRow('Phone',   phone,                  ls, vs),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: gap1),

          // ── Entries table ──
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FixedColumnWidth(46),
              2: const pw.FixedColumnWidth(60),
              3: const pw.FixedColumnWidth(22),
              4: const pw.FixedColumnWidth(22),
              5: const pw.FlexColumnWidth(2),
              6: const pw.FlexColumnWidth(2),
              7: const pw.FixedColumnWidth(44),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: navy),
                children: [
                  '#', 'Date', 'AWB No', 'KG', 'Mode',
                  'Destination', 'Client Name', 'Amt (Rs.)'
                ]
                    .map((h) => pw.Padding(
                          padding: pw.EdgeInsets.symmetric(
                              horizontal: 3 * scale, vertical: 2 * scale),
                          child: pw.Text(h, style: ths),
                        ))
                    .toList(),
              ),
              ...bill.entries.asMap().entries.map((ep) {
                final i = ep.key;
                final e = ep.value;
                final bg = i % 2 == 0 ? white : lightRow;
                final amt = e.price.isEmpty ? '0' : 'Rs.${e.price}';
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    '${i + 1}',
                    fmtDate(e.date),
                    e.awb,
                    e.kg,
                    e.mode,
                    e.destination,
                    e.clientName,
                    amt,
                  ]
                      .map((v) => pw.Padding(
                            padding: pw.EdgeInsets.symmetric(
                                horizontal: 3 * scale, vertical: 1.5 * scale),
                            child: pw.Text(v, style: cs),
                          ))
                      .toList(),
                );
              }),
            ],
          ),
          pw.SizedBox(height: gap1),

          // ── Totals ──
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 210 * scale,
              child: pw.Column(
                children: [
                  _pdfTotRow('Gross Total',
                      _pdfAmt(fmtINRRounded(t.gross)), tls, tvs),
                  if (t.fuelPct > 0)
                    _pdfTotRow(
                        '${(t.fuelPct * 100).toStringAsFixed(0)}% Fuel Charges',
                        _pdfAmt(fmtINRRounded(t.fuel)), tls, tvs),
                  _pdfTotRow('Total Value of Supply',
                      _pdfAmt(fmtINRRounded(t.ts)), tls, tvs),
                  if (t.cgstPct > 0)
                    _pdfTotRow(
                        '${(t.cgstPct * 100).toStringAsFixed(0)}% CGST',
                        _pdfAmt(fmtINRRounded(t.cgst)), tls, tvs),
                  if (t.sgstPct > 0)
                    _pdfTotRow(
                        '${(t.sgstPct * 100).toStringAsFixed(0)}% SGST',
                        _pdfAmt(fmtINRRounded(t.sgst)), tls, tvs),
                  pw.Divider(color: navy, thickness: 1.5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('NET AMOUNT', style: ns),
                      pw.Text(netRounded, style: ns),
                    ],
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: gap1),

          // ── Amount in words ──
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 3 * scale),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('E6F1FB'),
              border: pw.Border.symmetric(
                horizontal: pw.BorderSide(
                  color: PdfColor.fromHex('85B7EB'),
                  width: 0.8,
                ),
              ),
            ),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'AMOUNT IN WORDS:  ',
                    style: pw.TextStyle(
                      font: ttfBold,
                      fontSize: 7.5 * scale,
                      color: PdfColor.fromHex('0C447C'),
                    ),
                  ),
                  pw.TextSpan(
                    text: netWords,
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 7.5 * scale,
                      color: PdfColor.fromHex('185FA5'),
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: gap1),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 3 * scale),

          // ── Bank details + Signature ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BANK DETAILS', style: bhs),
                    pw.SizedBox(height: 2 * scale),
                    pw.Text('Name: ${co.bankName}',     style: bs),
                    pw.Text('A/C No.: ${co.bankAcc}',   style: bs),
                    pw.Text('IFSC: ${co.bankIFSC}',     style: bs),
                    pw.Text('Branch: ${co.bankBranch}', style: bs),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.SizedBox(height: 16 * scale),
                    pw.Text('for, ${co.name}', style: sigs),
                    pw.SizedBox(height: 12 * scale),
                    pw.Text('Authorised Signature', style: sigs),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (compact) {
      // ── Compact: guaranteed single page ──
      // Strategy: directly compute the scale factor so the content fits
      // within A4 margins. We estimate the natural (scale=1.0) content height,
      // then scale = usableH / naturalH (clamped to ≤1.0 so we never upscale).
      //
      // Natural height breakdown at scale=1.0:
      //   Header block:      ~62pt  (padding 7*2 + company name 16 + addr 7 + contact 7 + gaps)
      //   gap1:               4pt
      //   Party/bill rows:   ~42pt  (3 rows × 14pt each)
      //   gap1:               4pt
      //   Table header row:  ~13pt
      //   Per entry row:     ~11pt  (font 7 + padding 1.5*2 + border)
      //   gap1:               4pt
      //   Totals block:      ~70pt  (5 rows × 14pt)
      //   gap1:               4pt
      //   Amount-in-words:   ~18pt
      //   gap1:               4pt
      //   Divider+gap:        5pt
      //   Bank/sig block:    ~50pt
      //   Total fixed:      ~280pt
      const double a4Height       = 841.89;
      const double pageMargin     = 12.0;
      final double usableH        = a4Height - pageMargin * 2;

      const double fixedNaturalH  = 280.0;
      const double rowNaturalH    = 11.0;
      final double naturalH =
          fixedNaturalH + bill.entries.length * rowNaturalH;

      // Compute scale: shrink to fit, never enlarge
      final double scale = (usableH / naturalH).clamp(0.0, 1.0);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(pageMargin),
          build: (pw.Context ctx) => pw.Align(
            alignment: pw.Alignment.topCenter,
            child: _buildContent(scale),
          ),
        ),
      );
    } else {
      // ── Standard: MultiPage at full size ──
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context ctx) => [_buildContent(1.0)],
        ),
      );
    }

    return doc.save();
  }

  /// Converts ₹ → Rs. for PDF text (safe for any TTF font).
  String _pdfAmt(String v) => v.replaceAll('₹', 'Rs.');

  pw.Widget _pdfInfoRow(String label, String value,
      pw.TextStyle lStyle, pw.TextStyle vStyle) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(children: [
        pw.SizedBox(width: 52, child: pw.Text('$label:', style: lStyle)),
        pw.Expanded(child: pw.Text(value, style: vStyle)),
      ]),
    );
  }

  pw.Widget _pdfTotRow(String label, String value,
      pw.TextStyle lStyle, pw.TextStyle vStyle) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: lStyle),
          pw.Text(value, style: vStyle),
        ],
      ),
    );
  }

  // ── Excel download ──────────────────────────────────────────────────────────
  Future<void> _downloadExcel() async {
    final app = context.read<AppProvider>();
    final bill = app.billById(widget.billId);
    if (bill == null) return;
    final party = app.partyById(bill.partyId);
    final totals = Totals.calc(bill.entries, party);
    final co = app.company;

    setState(() => _downloading = true);
    try {
      final excel = xl.Excel.createExcel();
      final sheetName = 'Bill_${bill.billNo}';
      excel.rename('Sheet1', sheetName);
      final sheet = excel[sheetName];

      void addRow(List<String> values,
          {bool bold = false, String? bg, String? fontColor}) {
        final rowIdx = sheet.maxRows;
        for (int c = 0; c < values.length; c++) {
          final cell = sheet.cell(
              xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx));
          cell.value = xl.TextCellValue(values[c]);
          if (bg != null) {
            final resolvedFont = fontColor != null
                ? xl.ExcelColor.fromHexString(fontColor)!
                : (bg == 'FF1A3A5C')
                    ? xl.ExcelColor.fromHexString('FFFFFFFF')!
                    : xl.ExcelColor.fromHexString('FF000000')!;
            cell.cellStyle = xl.CellStyle(
              bold: bold,
              backgroundColorHex: xl.ExcelColor.fromHexString(bg)!,
              fontColorHex: resolvedFont,
              italic: fontColor != null, // italic for the words row
            );
          } else {
            cell.cellStyle = xl.CellStyle(bold: bold);
          }
        }
      }

      addRow([co.name], bold: true);
      addRow([co.address]);
      addRow(['Phone: ${co.phone} | Email: ${co.email} | GST: ${co.gst}']);
      for (final ef in co.extraFields) {
        addRow(['${ef.label}: ${ef.value}']);
      }
      addRow(['']);

      addRow(['Party:', party?.name ?? '—', '', 'Bill No:', '2026/${bill.billNo}']);
      addRow(['Address:', party?.address ?? '—', '', 'Bill Date:', fmtDate(bill.billDate)]);
      addRow(['GSTIN:', party?.gstin ?? '—', '', 'Phone:', party?.phone ?? '—']);
      addRow(['']);

      // ── Header row ──
      addRow([
        'S.No', 'Date', 'AWB No', 'KG', 'Mode',
        'Destination', 'Client Name', 'Amount (Rs.)'
      ], bold: true, bg: 'FF1A3A5C');

      for (int i = 0; i < bill.entries.length; i++) {
        final e = bill.entries[i];
        addRow([
          '${i + 1}',
          fmtDate(e.date),
          e.awb,
          e.kg,
          e.mode,
          e.destination,
          e.clientName,
          e.price.isEmpty ? '0' : e.price,
        ]);
      }

      addRow(['']);

      // ── Totals: rounded, _ea() replaces ₹ with Rs. ──
      addRow(['', '', '', '', '', '', 'Gross Total:', _ea(fmtINRRounded(totals.gross))],
          bold: true);
      if (totals.fuelPct > 0) {
        addRow([
          '', '', '', '', '', '',
          '${(totals.fuelPct * 100).toStringAsFixed(0)}% Fuel Charges:',
          _ea(fmtINRRounded(totals.fuel))
        ]);
      }
      addRow(['', '', '', '', '', '', 'Total Value of Supply:',
          _ea(fmtINRRounded(totals.ts))]);
      if (totals.cgstPct > 0) {
        addRow([
          '', '', '', '', '', '',
          '${(totals.cgstPct * 100).toStringAsFixed(0)}% CGST:',
          _ea(fmtINRRounded(totals.cgst))
        ]);
      }
      if (totals.sgstPct > 0) {
        addRow([
          '', '', '', '', '', '',
          '${(totals.sgstPct * 100).toStringAsFixed(0)}% SGST:',
          _ea(fmtINRRounded(totals.sgst))
        ]);
      }
      addRow(
          ['', '', '', '', '', '', 'NET AMOUNT:', _ea(fmtINRRounded(totals.net))],
          bold: true, bg: 'FFDBEAFE');

      // ── Amount in words — navy blue full-width band ──
      addRow(
          ['AMOUNT IN WORDS:  ${amountInWords(totals.net)}', '', '', '', '', '', '', ''],
          bold: true, bg: 'FFE6F1FB', fontColor: 'FF0C447C');

      sheet.setColumnWidth(0, 6);
      sheet.setColumnWidth(1, 14);
      sheet.setColumnWidth(2, 16);
      sheet.setColumnWidth(3, 8);
      sheet.setColumnWidth(4, 8);
      sheet.setColumnWidth(5, 20);
      sheet.setColumnWidth(6, 22);
      sheet.setColumnWidth(7, 14);

      final bytes = excel.save();
      if (bytes == null) throw Exception('Excel generation failed');

      final dir = await getTemporaryDirectory();
      final safeName =
          (party?.name ?? 'Party').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final file =
          File('${dir.path}/JSS_Bill_${bill.billNo}_$safeName.xlsx');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [
          XFile(file.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        ],
        subject: 'JSS Bill #${bill.billNo} — ${party?.name ?? ''}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final bill = app.billById(widget.billId);
    if (bill == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Preview')),
          body: const Center(child: Text('Bill not found')));
    }
    final party = app.partyById(bill.partyId);
    final totals = Totals.calc(bill.entries, party);
    final co = app.company;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bill #${bill.billNo} Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Bill No / Date',
            onPressed: () => _editBillMeta(bill),
          ),
          if (_sharing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Share as PDF',
              onPressed: () =>
                  _sharePdf(party?.name ?? 'Party', bill.billNo),
            ),
          if (_downloading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'Download Excel',
              onPressed: _downloadExcel,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ── Company header ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kNavy,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(co.name,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2)),
                const SizedBox(height: 4),
                Text(co.address,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFFBDD5EC))),
                const SizedBox(height: 2),
                Text('Phone: ${co.phone} | ${co.email}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFFBDD5EC))),
                Text('GST: ${co.gst}',
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFFBDD5EC))),
                ...co.extraFields.map((ef) => Text(
                      '${ef.label}: ${ef.value}',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFFBDD5EC)),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Party & Bill info ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kCardBorder),
            ),
            child: Column(
              children: [
                _InfoRow('Party', party?.name ?? '—'),
                _InfoRow('Bill No', '2026/${bill.billNo}'),
                _InfoRow('Bill Date', fmtDate(bill.billDate)),
                _InfoRow('Address',
                    party?.address.isEmpty == true ? '—' : party!.address),
                _InfoRow('GSTIN',
                    party?.gstin.isEmpty == true ? '—' : party!.gstin),
                _InfoRow('Phone',
                    party?.phone.isEmpty == true ? '—' : party!.phone),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Entries table ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kCardBorder),
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: kNavy,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(11)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 28, child: Text('#', style: _tableHdr)),
                      Expanded(
                          flex: 2,
                          child: Text('AWB / Dest', style: _tableHdr)),
                      SizedBox(width: 45, child: Text('Mode', style: _tableHdr)),
                      SizedBox(width: 60, child: Text('Amt', style: _tableHdrR)),
                    ],
                  ),
                ),
                if (bill.entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No entries',
                        style: TextStyle(color: kMeta, fontSize: 13)),
                  )
                else
                  ...bill.entries.asMap().entries.map((ep) {
                    final i = ep.key;
                    final e = ep.value;
                    final bg =
                        i % 2 == 0 ? Colors.white : const Color(0xFFF5F8FC);
                    return Container(
                      color: bg,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              width: 28,
                              child: Text('${i + 1}',
                                  style: const TextStyle(
                                      fontSize: 12, color: kMeta))),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.destination.toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    '${e.awb}${e.kg.isNotEmpty ? ' · ${e.kg}kg' : ''}',
                                    style: const TextStyle(
                                        fontSize: 11, color: kMeta)),
                                if (e.clientName.isNotEmpty)
                                  Text(e.clientName,
                                      style: const TextStyle(
                                          fontSize: 11, color: kMeta)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 45,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: kNavyLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(e.mode,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: kNavy,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                                e.price.isEmpty ? '—' : '₹${e.price}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Totals ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kCardBorder),
            ),
            child: Column(
              children: [
                _TotRow('Gross Total', fmtINR2(totals.gross)),
                if (totals.fuelPct > 0)
                  _TotRow(
                      '${(totals.fuelPct * 100).toStringAsFixed(0)}% Fuel Charges',
                      fmtINR2(totals.fuel)),
                _TotRow('Total Value of Supply', fmtINR2(totals.ts)),
                if (totals.cgstPct > 0)
                  _TotRow(
                      '${(totals.cgstPct * 100).toStringAsFixed(0)}% CGST',
                      fmtINR2(totals.cgst)),
                if (totals.sgstPct > 0)
                  _TotRow(
                      '${(totals.sgstPct * 100).toStringAsFixed(0)}% SGST',
                      fmtINR2(totals.sgst)),
                const Divider(color: kNavy, thickness: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('NET AMOUNT',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: kNavy)),
                    Text(fmtINR2(totals.net),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: kNavy)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Bank details ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kCardBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BANK DETAILS',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: kNavy)),
                      const SizedBox(height: 6),
                      Text('Name: ${co.bankName}',
                          style: const TextStyle(fontSize: 12)),
                      Text('A/C No.: ${co.bankAcc}',
                          style: const TextStyle(fontSize: 12)),
                      Text('IFSC: ${co.bankIFSC}',
                          style: const TextStyle(fontSize: 12)),
                      Text('Branch: ${co.bankBranch}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const SizedBox(height: 36),
                      Text('for, ${co.name}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 32),
                      const Text('Authorised Signature',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Action buttons ──
          PrimaryBtn(
            label: '📤 Share Bill as PDF',
            onTap: _sharing
                ? null
                : () => _sharePdf(party?.name ?? 'Party', bill.billNo),
          ),
          const SizedBox(height: 10),
          _ExcelBtn(
            loading: _downloading,
            onTap: _downloading ? null : _downloadExcel,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ── Excel button ──────────────────────────────────────────────────────────────
class _ExcelBtn extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;
  const _ExcelBtn({required this.loading, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: loading
              ? const Color(0xFF1a7a3c).withOpacity(0.6)
              : const Color(0xFF1a7a3c),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
            else
              const Icon(Icons.table_chart, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              loading ? 'Generating Excel…' : '📊 Download Excel',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────
const _tableHdr = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white);
const _tableHdrR = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white);

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Color(0xFF333333))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _TotRow extends StatelessWidget {
  final String label;
  final String value;
  const _TotRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
