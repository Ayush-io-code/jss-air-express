// lib/utils/bill_exporter.dart
import '../models/bill.dart';
import '../models/party.dart';
import '../models/totals.dart';
import '../models/company_info.dart';
import 'helpers.dart';

String buildBillHtml(Party party, Bill bill, Totals t, CompanyInfo co) {
  final entries = bill.entries;

  String rows = '';
  for (int i = 0; i < entries.length; i++) {
    final e = entries[i];
    rows += '''
<tr>
  <td class="c">${i + 1}</td>
  <td>${fmtDate(e.date)}</td>
  <td>${e.awb}</td>
  <td class="c">${e.kg}</td>
  <td class="c">${e.mode}</td>
  <td>${e.destination}</td>
  <td>${e.clientName}</td>
  <td class="r">${e.price.isEmpty ? '₹0' : fmtINRRounded(double.tryParse(e.price) ?? 0)}</td>
</tr>''';
  }

  String taxRows = '';
  if (t.fuelPct > 0) {
    taxRows +=
        '<div class="trow"><span class="tl">${(t.fuelPct * 100).toStringAsFixed(0)}% Fuel Charges</span><span class="tv">${fmtINRRounded(t.fuel)}</span></div>';
  }
  taxRows +=
      '<div class="trow"><span class="tl">Total Value of Supply</span><span class="tv">${fmtINRRounded(t.ts)}</span></div>';
  if (t.cgstPct > 0) {
    taxRows +=
        '<div class="trow"><span class="tl">${(t.cgstPct * 100).toStringAsFixed(0)}% CGST</span><span class="tv">${fmtINRRounded(t.cgst)}</span></div>';
  }
  if (t.sgstPct > 0) {
    taxRows +=
        '<div class="trow"><span class="tl">${(t.sgstPct * 100).toStringAsFixed(0)}% SGST</span><span class="tv">${fmtINRRounded(t.sgst)}</span></div>';
  }

  final netRounded = fmtINRRounded(t.net);
  final netWords   = amountInWords(t.net);

  return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>JSS Bill #${bill.billNo}</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:Arial,sans-serif;font-size:8.5pt;padding:8mm;color:#111;background:#fff}
.hd{text-align:center;margin-bottom:5px}
.hd h1{font-size:16pt;font-weight:900;letter-spacing:2px;color:#1a3a5c}
.hd p{font-size:7pt;color:#555;margin:2px 0}
.bar{height:3px;background:#1a3a5c;margin:5px 0}
.bar2{height:1px;background:#ccc;margin:5px 0}
.meta{display:grid;grid-template-columns:1fr 1fr;gap:3px 16px;font-size:7.5pt;margin:5px 0}
.mr{display:flex;gap:4px}.ml{font-weight:700;color:#333;white-space:nowrap}
table{width:100%;border-collapse:collapse;margin:4px 0;font-size:7.5pt}
th{background:#1a3a5c;color:#fff;padding:4px 3px;font-weight:700;font-size:7pt}
th.r,td.r{text-align:right}th.c,td.c{text-align:center}
td{padding:3.5px 3px;border-bottom:1px solid #eee}
tr:nth-child(even) td{background:#f5f8fc}
.totals{margin-left:auto;width:250px;font-size:8pt;margin-top:5px}
.trow{display:flex;justify-content:space-between;padding:2px 0}
.tl{color:#555}.tv{font-weight:600}
.tnet{border-top:2px solid #1a3a5c;margin-top:4px;padding-top:4px}
.tnet .tl,.tnet .tv{font-weight:800;font-size:10pt;color:#1a3a5c}
.amtbox{background:#1a3a5c;border-radius:4px;padding:7px 12px;margin:8px 0}
.amtbox-label{color:#BDD5EC;font-size:6.5pt;font-weight:700;letter-spacing:1px;text-transform:uppercase;margin-bottom:2px}
.amtbox-words{color:#fff;font-size:8.5pt;font-style:italic}
.foot{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:8px;font-size:7.5pt}
.bank p{margin:1.5px 0}.bank b{display:block;margin-bottom:3px}
.sig{text-align:right;padding-top:32px;font-weight:700}
@page{size:A4 portrait;margin:0}
@media print{body{padding:8mm}*{-webkit-print-color-adjust:exact;print-color-adjust:exact}}
</style>
</head>
<body>
<div class="hd">
  <h1>${co.name}</h1>
  <p>${co.address}</p>
  <p>Phone: ${co.phone} | Gmail: ${co.email} | GST No.: ${co.gst}</p>
</div>
<div class="bar"></div>
<div class="meta">
  <div class="mr"><span class="ml">Party:</span><span>${party.name}</span></div>
  <div class="mr"><span class="ml">Bill No:</span><span>2026/${bill.billNo}</span></div>
  <div class="mr"><span class="ml">Address:</span><span>${party.address.isEmpty ? '—' : party.address}</span></div>
  <div class="mr"><span class="ml">Bill Date:</span><span>${fmtDate(bill.billDate)}</span></div>
  <div class="mr"><span class="ml">GSTIN:</span><span>${party.gstin.isEmpty ? '—' : party.gstin}</span></div>
  <div class="mr"><span class="ml">S.Tax Cat.:</span><span>Courier</span></div>
  <div class="mr"><span class="ml">Ph:</span><span>${party.phone.isEmpty ? '—' : party.phone}</span></div>
  <div class="mr"><span class="ml">Service:</span><span>Courier</span></div>
</div>
<div class="bar"></div>
<table>
<thead>
  <tr>
    <th class="c">S.No</th><th>Date</th><th>AWB No</th>
    <th class="c">KG</th><th class="c">Mode</th>
    <th>Destination</th><th>Client Name</th><th class="r">Amt</th>
  </tr>
</thead>
<tbody>$rows</tbody>
</table>
<div class="bar2"></div>
<div class="totals">
  <div class="trow"><span class="tl">Gross Total</span><span class="tv">${fmtINRRounded(t.gross)}</span></div>
  $taxRows
  <div class="trow tnet"><span class="tl">NET AMOUNT</span><span class="tv">$netRounded</span></div>
</div>
<div class="amtbox">
  <div class="amtbox-label">Amount in Words</div>
  <div class="amtbox-words">$netWords</div>
</div>
<div class="bar2"></div>
<div class="foot">
  <div class="bank">
    <b>BANK DETAILS</b>
    <p>Name: ${co.bankName}</p>
    <p>A/C No.: ${co.bankAcc}</p>
    <p>IFSC: ${co.bankIFSC}</p>
    <p>Branch: ${co.bankBranch}</p>
  </div>
  <div class="sig">for, ${co.name}<br><br><br>Authorised Signature</div>
</div>
</body>
</html>''';
}
