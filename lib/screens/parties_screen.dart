// lib/screens/parties_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/party.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  bool _showAdd = false;
  final _nameCtrl = TextEditingController();
  String? _addError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmAdd() async {
    final app = context.read<AppProvider>();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final ok = await app.addParty(name);
    if (!ok) {
      setState(() => _addError = 'A party with this name already exists');
      return;
    }
    setState(() {
      _showAdd = false;
      _nameCtrl.clear();
      _addError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final parties = context.watch<AppProvider>().parties;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parties'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() {
              _showAdd = !_showAdd;
              _addError = null;
              _nameCtrl.clear();
            }),
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            label: const Text('Add',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (_showAdd) _AddPartyCard(
            nameCtrl: _nameCtrl,
            error: _addError,
            onConfirm: _confirmAdd,
            onCancel: () => setState(() {
              _showAdd = false;
              _addError = null;
            }),
            onChanged: (_) => setState(() => _addError = null),
          ),
          if (parties.isEmpty && !_showAdd)
            const EmptyState(
                icon: '🏢',
                text: 'No parties yet',
                hint: 'Tap + Add to create one')
          else
            ...parties.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PartyEditCard(party: p),
                )),
        ],
      ),
    );
  }
}

// ── Add party card ────────────────────────────────────────────────────────────
class _AddPartyCard extends StatelessWidget {
  final TextEditingController nameCtrl;
  final String? error;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final ValueChanged<String> onChanged;

  const _AddPartyCard({
    required this.nameCtrl,
    required this.error,
    required this.onConfirm,
    required this.onCancel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kNavy, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('➕ New Party',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: kNavy,
                  fontSize: 14)),
          const SizedBox(height: 12),
          FieldWrap(
            label: 'Party Name',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  onChanged: onChanged,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g. Company Name',
                    filled: true,
                    fillColor:
                        error != null ? const Color(0xFFFFFBF2) : kInputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: error != null
                              ? const Color(0xFFD97706)
                              : kInputBorder,
                          width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: error != null
                              ? const Color(0xFFD97706)
                              : kInputBorder,
                          width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(error!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: PrimaryBtn(label: 'Add Party', onTap: onConfirm)),
              const SizedBox(width: 8),
              Expanded(child: GhostBtn(label: 'Cancel', onTap: onCancel)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Party edit card ───────────────────────────────────────────────────────────
class _PartyEditCard extends StatefulWidget {
  final Party party;
  const _PartyEditCard({required this.party});

  @override
  State<_PartyEditCard> createState() => _PartyEditCardState();
}

class _PartyEditCardState extends State<_PartyEditCard> {
  bool _editing = false;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addrCtrl;
  late final TextEditingController _gstCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _fuelCtrl;
  late final TextEditingController _cgstCtrl;
  late final TextEditingController _sgstCtrl;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.party.name);
    _addrCtrl = TextEditingController(text: widget.party.address);
    _gstCtrl = TextEditingController(text: widget.party.gstin);
    _phoneCtrl = TextEditingController(text: widget.party.phone);
    _fuelCtrl =
        TextEditingController(text: widget.party.fuelPct.toString());
    _cgstCtrl =
        TextEditingController(text: widget.party.cgstPct.toString());
    _sgstCtrl =
        TextEditingController(text: widget.party.sgstPct.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _gstCtrl.dispose();
    _phoneCtrl.dispose();
    _fuelCtrl.dispose();
    _cgstCtrl.dispose();
    _sgstCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = context.read<AppProvider>();
    final updated = widget.party.copyWith(
      name: _nameCtrl.text,
      address: _addrCtrl.text,
      gstin: _gstCtrl.text,
      phone: _phoneCtrl.text,
      fuelPct: double.tryParse(_fuelCtrl.text) ?? 15,
      cgstPct: double.tryParse(_cgstCtrl.text) ?? 9,
      sgstPct: double.tryParse(_sgstCtrl.text) ?? 9,
    );
    final ok = await app.updateParty(updated);
    if (!ok) {
      setState(() => _saveError = 'A party with this name already exists');
      return;
    }
    setState(() {
      _editing = false;
      _saveError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return _CollapsedCard(
        party: widget.party,
        onEdit: () => setState(() => _editing = true),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kNavy, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('✏️ Editing: ${widget.party.name}',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: kNavy,
                  fontSize: 14)),
          const SizedBox(height: 12),
          FieldWrap(
              label: 'Party Name',
              child: TextField(controller: _nameCtrl)),
          const SizedBox(height: 12),
          FieldWrap(
              label: 'Address',
              child: TextField(
                  controller: _addrCtrl,
                  decoration:
                      const InputDecoration(hintText: 'Optional'))),
          const SizedBox(height: 12),
          FieldWrap(
              label: 'GSTIN',
              child: TextField(
                  controller: _gstCtrl,
                  decoration:
                      const InputDecoration(hintText: 'Optional'))),
          const SizedBox(height: 12),
          FieldWrap(
              label: 'Phone',
              child: TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: 'Optional'),
              )),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TAX & CHARGES',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kNavy,
                        letterSpacing: 0.5)),
                const SizedBox(height: 10),
                FieldWrap(
                    label: 'Fuel Charge % (0 = no charge)',
                    child: TextField(
                      controller: _fuelCtrl,
                      keyboardType: TextInputType.number,
                    )),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: FieldWrap(
                            label: 'CGST %',
                            child: TextField(
                              controller: _cgstCtrl,
                              keyboardType: TextInputType.number,
                            ))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: FieldWrap(
                            label: 'SGST %',
                            child: TextField(
                              controller: _sgstCtrl,
                              keyboardType: TextInputType.number,
                            ))),
                  ],
                ),
                const SizedBox(height: 8),
                Builder(builder: (ctx) {
                  final fuel = double.tryParse(_fuelCtrl.text) ?? 15;
                  final cgst = double.tryParse(_cgstCtrl.text) ?? 9;
                  final sgst = double.tryParse(_sgstCtrl.text) ?? 9;
                  final net = 1000 *
                      (1 + fuel / 100) *
                      (1 + cgst / 100 + sgst / 100);
                  return Text(
                    'Preview: Gross ₹1000 → Net ₹${net.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
                  );
                }),
              ],
            ),
          ),
          if (_saveError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_saveError!,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: PrimaryBtn(label: 'Save Party', onTap: _save)),
              const SizedBox(width: 8),
              Expanded(
                  child: GhostBtn(
                      label: 'Cancel',
                      onTap: () => setState(() {
                            _editing = false;
                            _saveError = null;
                          }))),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollapsedCard extends StatelessWidget {
  final Party party;
  final VoidCallback onEdit;
  const _CollapsedCard({required this.party, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kCardBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(party.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: kNavy)),
                const SizedBox(height: 3),
                Text(
                  'Fuel: ${party.fuelPct}% · CGST: ${party.cgstPct}% · SGST: ${party.sgstPct}%',
                  style: const TextStyle(fontSize: 12, color: kMeta),
                ),
                if (party.gstin.isNotEmpty)
                  Text('GST: ${party.gstin}',
                      style: const TextStyle(
                          fontSize: 12, color: kMeta)),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            child: const Text('Edit',
                style: TextStyle(
                    color: kNavy, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
