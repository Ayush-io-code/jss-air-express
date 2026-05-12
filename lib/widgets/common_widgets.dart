// lib/widgets/common_widgets.dart
import 'package:flutter/material.dart';
import '../utils/theme.dart';

// ── Section label ────────────────────────────────────────────────────────────
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: kMeta,
        letterSpacing: 0.6,
      ),
    );
  }
}

// ── Field wrapper ────────────────────────────────────────────────────────────
class FieldWrap extends StatelessWidget {
  final String label;
  final Widget child;
  const FieldWrap({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: kLabel,
                letterSpacing: 0.5)),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

// ── Primary button ────────────────────────────────────────────────────────────
class PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  const PrimaryBtn(
      {super.key, required this.label, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? kNavy,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

// ── Ghost button ──────────────────────────────────────────────────────────────
class GhostBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const GhostBtn({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF555555),
          side: const BorderSide(color: kInputBorder, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          backgroundColor: kBg,
        ),
        child: Text(label),
      ),
    );
  }
}

// ── Mode toggle buttons ───────────────────────────────────────────────────────
class ModeToggle extends StatelessWidget {
  final List<String> modes;
  final String selected;
  final ValueChanged<String> onChanged;
  const ModeToggle(
      {super.key,
      required this.modes,
      required this.selected,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: modes.map((m) {
        final active = m == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(m),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active ? kNavy : kInputBg,
                border: Border.all(
                    color: active ? kNavy : kInputBorder, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                m,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : const Color(0xFF555555),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Totals strip bar ──────────────────────────────────────────────────────────
class TotalsStrip extends StatelessWidget {
  final List<_StripItem> items;
  const TotalsStrip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kNavy,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      child: Row(
        children: items
            .map((item) => Expanded(
                  child: Column(
                    children: [
                      Text(item.label,
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF89AECB),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4)),
                      const SizedBox(height: 2),
                      Text(item.value,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _StripItem {
  final String label;
  final String value;
  const _StripItem(this.label, this.value);
}

List<_StripItem> stripItems(String entries, String gross, String net) => [
      _StripItem('ENTRIES', entries),
      _StripItem('GROSS', gross),
      _StripItem('NET', net),
    ];

// ── Flash message ─────────────────────────────────────────────────────────────
class FlashBar extends StatelessWidget {
  final String message;
  const FlashBar({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Color(0xFF1A6B3A),
            fontWeight: FontWeight.w600,
            fontSize: 14),
      ),
    );
  }
}

// ── Confirm delete dialog ─────────────────────────────────────────────────────
Future<bool> showConfirmDelete(
    BuildContext context, String title, String sub) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Column(
        children: [
          const Text('🗑️', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 4),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kRed)),
        ],
      ),
      content: Text(sub,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: kMeta)),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: kRed, foregroundColor: Colors.white),
              child: const Text('Yes, Delete'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
          ),
        ])
      ],
    ),
  );
  return result ?? false;
}

// ── Empty state ────────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String icon;
  final String text;
  final String? hint;
  const EmptyState(
      {super.key, required this.icon, required this.text, this.hint});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 38)),
            const SizedBox(height: 10),
            Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF555555))),
            if (hint != null) ...[
              const SizedBox(height: 5),
              Text(hint!,
                  style: const TextStyle(fontSize: 13, color: kMeta)),
            ],
          ],
        ),
      ),
    );
  }
}
