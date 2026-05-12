// lib/screens/company_info_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/company_info.dart';
import '../providers/app_provider.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';

class CompanyInfoScreen extends StatefulWidget {
  const CompanyInfoScreen({super.key});

  @override
  State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // Core fields
  late TextEditingController _name;
  late TextEditingController _address;
  late TextEditingController _phone;
  late TextEditingController _email;
  late TextEditingController _gst;

  // Bank fields
  late TextEditingController _bankName;
  late TextEditingController _bankAcc;
  late TextEditingController _bankIFSC;
  late TextEditingController _bankBranch;

  // Extra fields (label + value pairs)
  final List<_ExtraRow> _extraRows = [];

  @override
  void initState() {
    super.initState();
    final c = context.read<AppProvider>().company;
    _name       = TextEditingController(text: c.name);
    _address    = TextEditingController(text: c.address);
    _phone      = TextEditingController(text: c.phone);
    _email      = TextEditingController(text: c.email);
    _gst        = TextEditingController(text: c.gst);
    _bankName   = TextEditingController(text: c.bankName);
    _bankAcc    = TextEditingController(text: c.bankAcc);
    _bankIFSC   = TextEditingController(text: c.bankIFSC);
    _bankBranch = TextEditingController(text: c.bankBranch);

    for (final ef in c.extraFields) {
      _extraRows.add(_ExtraRow(
        label: TextEditingController(text: ef.label),
        value: TextEditingController(text: ef.value),
      ));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _gst.dispose();
    _bankName.dispose();
    _bankAcc.dispose();
    _bankIFSC.dispose();
    _bankBranch.dispose();
    for (final r in _extraRows) {
      r.label.dispose();
      r.value.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final extras = _extraRows
          .where((r) => r.label.text.trim().isNotEmpty)
          .map((r) => ExtraField(
                label: r.label.text.trim(),
                value: r.value.text.trim(),
              ))
          .toList();

      final updated = CompanyInfo(
        name:       _name.text.trim(),
        address:    _address.text.trim(),
        phone:      _phone.text.trim(),
        email:      _email.text.trim(),
        gst:        _gst.text.trim(),
        bankName:   _bankName.text.trim(),
        bankAcc:    _bankAcc.text.trim(),
        bankIFSC:   _bankIFSC.text.trim(),
        bankBranch: _bankBranch.text.trim(),
        extraFields: extras,
      );

      await context.read<AppProvider>().updateCompany(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company info saved ✓'),
            backgroundColor: kGreen,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addExtraField() {
    setState(() {
      _extraRows.add(_ExtraRow(
        label: TextEditingController(),
        value: TextEditingController(),
      ));
    });
  }

  void _removeExtraField(int index) {
    setState(() {
      final row = _extraRows.removeAt(index);
      row.label.dispose();
      row.value.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Info'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _saving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : TextButton(
                    onPressed: _save,
                    child: const Text('Save',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const SectionLabel('Business Details'),
            const SizedBox(height: 10),
            _field(_name, 'Company Name', required: true,
                hint: 'JSS AIR EXPRESS'),
            const SizedBox(height: 10),
            _field(_address, 'Address', maxLines: 3, hint: 'Full address'),
            const SizedBox(height: 10),
            _field(_phone, 'Phone Number(s)', hint: 'e.g. 7975609737, 8884261970'),
            const SizedBox(height: 10),
            _field(_email, 'Email', hint: 'e.g. jssairexpress@gmail.com'),
            const SizedBox(height: 10),
            _field(_gst, 'GST Number', hint: 'e.g. 29CTCPD9755Q1ZS'),

            const SizedBox(height: 20),
            const SectionLabel('Bank Details'),
            const SizedBox(height: 10),
            _field(_bankName, 'Account Name'),
            const SizedBox(height: 10),
            _field(_bankAcc, 'Account Number'),
            const SizedBox(height: 10),
            _field(_bankIFSC, 'IFSC Code'),
            const SizedBox(height: 10),
            _field(_bankBranch, 'Branch Name'),

            const SizedBox(height: 20),
            const SectionLabel('Extra Fields'),
            const SizedBox(height: 6),
            const Text(
              'Add any additional details you want printed on every bill.',
              style: TextStyle(fontSize: 12, color: kMeta),
            ),
            const SizedBox(height: 10),

            ..._extraRows.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: _field(row.label, 'Label', hint: 'e.g. Website'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 6,
                      child: _field(row.value, 'Value', hint: 'e.g. www.jss.in'),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _removeExtraField(i),
                      icon: const Icon(Icons.remove_circle_outline,
                          color: kRed, size: 22),
                      padding: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),

            TextButton.icon(
              onPressed: _addExtraField,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add Extra Field'),
              style: TextButton.styleFrom(foregroundColor: kNavy),
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Save Changes'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    int maxLines = 1,
    String? hint,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}

class _ExtraRow {
  final TextEditingController label;
  final TextEditingController value;
  _ExtraRow({required this.label, required this.value});
}
