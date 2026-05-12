// lib/models/totals.dart
import 'entry.dart';
import 'party.dart';

class Totals {
  final double gross;
  final double fuel;
  final double ts;
  final double cgst;
  final double sgst;
  final double net;
  final double fuelPct;
  final double cgstPct;
  final double sgstPct;

  const Totals({
    required this.gross,
    required this.fuel,
    required this.ts,
    required this.cgst,
    required this.sgst,
    required this.net,
    required this.fuelPct,
    required this.cgstPct,
    required this.sgstPct,
  });

  static Totals calc(List<Entry> entries, Party? party) {
    final fuelPct = (party?.fuelPct ?? 15) / 100;
    final cgstPct = (party?.cgstPct ?? 9) / 100;
    final sgstPct = (party?.sgstPct ?? 9) / 100;

    final gross = entries.fold<double>(
        0, (s, e) => s + (double.tryParse(e.price) ?? 0));
    final fuel = gross * fuelPct;
    final ts = gross + fuel;
    final cgst = ts * cgstPct;
    final sgst = ts * sgstPct;
    final net = ts + cgst + sgst;

    return Totals(
      gross: gross,
      fuel: fuel,
      ts: ts,
      cgst: cgst,
      sgst: sgst,
      net: net,
      fuelPct: fuelPct,
      cgstPct: cgstPct,
      sgstPct: sgstPct,
    );
  }
}
