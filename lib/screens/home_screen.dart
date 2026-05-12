// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../models/party.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';
import 'bill_list_screen.dart';
import 'parties_screen.dart';
import 'all_bills_screen.dart';
import 'company_info_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _openParty(Party party) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BillListScreen(partyId: party.id)),
    );
  }

  void _showDevCard() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DeveloperCard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final parties = app.parties;
    final bills = app.bills;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CompanyInfoScreen()),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('JSS Air Express'),
              SizedBox(width: 4),
              Icon(Icons.edit, size: 14, color: Colors.white70),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllBillsScreen())),
            child: const Text('Bills',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PartiesScreen())),
            child: const Text('Parties',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: app.loaded
          ? Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    const SectionLabel('Select Party'),
                    const SizedBox(height: 10),
                    if (parties.isEmpty)
                      const EmptyState(
                          icon: '📦',
                          text: 'No parties yet',
                          hint: 'Tap Parties to add one')
                    else
                      ...parties.map((party) {
                        final pb = bills.where((b) => b.partyId == party.id).toList();
                        final tot =
                            pb.fold<int>(0, (s, b) => s + b.entries.length);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PartyCard(
                            party: party,
                            billCount: pb.length,
                            entryCount: tot,
                            onTap: () => _openParty(party),
                          ),
                        );
                      }),
                    // Space so content doesn't hide behind dev badge
                    const SizedBox(height: 80),
                  ],
                ),

                // ── Developer badge — bottom-right, home screen only ──
                Positioned(
                  bottom: 20,
                  right: 16,
                  child: _DevBadge(onTap: _showDevCard),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: kNavy),
            ),
    );
  }
}

// ── Developer badge button ────────────────────────────────────────────────────
class _DevBadge extends StatelessWidget {
  final VoidCallback onTap;
  const _DevBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: kNavy,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('👨‍💻', style: TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Dev',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Developer info bottom sheet ───────────────────────────────────────────────
class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Avatar + name
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kNavy, Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kNavy.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text('AP',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 12),

          const Text('Ayush Pareek',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: kNavy)),
          const SizedBox(height: 4),
          const Text('App Developer',
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500)),

          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 8),

          // Contact links
          _DevLink(
            icon: Icons.code,
            label: 'GitHub',
            value: 'SlimShady101',
            color: const Color(0xFF24292E),
            onTap: () => _launchUrl(
                context, 'https://github.com/SlimShady101'),
          ),
          _DevLink(
            icon: Icons.work_outline,
            label: 'LinkedIn',
            value: 'Ayush Pareek',
            color: const Color(0xFF0077B5),
            onTap: () => _launchUrl(
                context,
                'https://www.linkedin.com/in/ayush-pareek-14ba2821b'),
          ),
          _DevLink(
            icon: Icons.mail_outline,
            label: 'Email',
            value: 'ayushpareek908@gmail.com',
            color: const Color(0xFFEA4335),
            onTap: () => _launchUrl(
                context, 'mailto:ayushpareek908@gmail.com'),
          ),

          const SizedBox(height: 12),

          // Built with love footer
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              'Built with ❤️ for JSS Air Express',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  void _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $url')),
        );
      }
    }
  }
}

class _DevLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _DevLink({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ── Party card ────────────────────────────────────────────────────────────────
class _PartyCard extends StatelessWidget {
  final Party party;
  final int billCount;
  final int entryCount;
  final VoidCallback onTap;

  const _PartyCard({
    required this.party,
    required this.billCount,
    required this.entryCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            border: Border.all(color: kCardBorder, width: 1.5),
            borderRadius: BorderRadius.circular(12),
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
                    billCount > 0
                        ? Text(
                            '$billCount bill${billCount > 1 ? 's' : ''} · $entryCount entr${entryCount == 1 ? 'y' : 'ies'}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: kGreen,
                                fontWeight: FontWeight.w600))
                        : const Text('No bills yet',
                            style: TextStyle(
                                fontSize: 12, color: kMeta)),
                  ],
                ),
              ),
              const Text('›',
                  style: TextStyle(fontSize: 22, color: Color(0xFFBBBBBB))),
            ],
          ),
        ),
      ),
    );
  }
}
