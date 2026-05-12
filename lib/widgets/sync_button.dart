// lib/widgets/sync_button.dart
//
// A single widget that handles the entire sign-in / sync / sign-out flow.
// Drop it into your HomeScreen AppBar actions list:
//
//   actions: [
//     const SyncButton(),
//     TextButton(...),  // existing Bills button
//     TextButton(...),  // existing Parties button
//   ],

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/drive_sync_service.dart';
import '../utils/theme.dart';

class SyncButton extends StatelessWidget {
  const SyncButton({super.key});

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final status = app.syncStatus;
    final signedIn = DriveSyncService.instance.isSignedIn;

    return IconButton(
      tooltip: signedIn
          ? _tooltipText(status, app.lastSync)
          : 'Tap to sign in with Google for sync',
      icon: _icon(status, signedIn),
      onPressed: () => _handleTap(context, app, signedIn),
    );
  }

  Widget _icon(SyncStatus status, bool signedIn) {
    if (!signedIn) {
      return const Icon(Icons.cloud_off_outlined, color: Colors.white70);
    }
    switch (status) {
      case SyncStatus.syncing:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
        );
      case SyncStatus.error:
        return const Icon(Icons.sync_problem_outlined, color: Colors.orange);
      case SyncStatus.done:
        return const Icon(Icons.cloud_done_outlined, color: Colors.greenAccent);
      case SyncStatus.idle:
        return const Icon(Icons.sync_outlined, color: Colors.white);
    }
  }

  String _tooltipText(SyncStatus status, DateTime? lastSync) {
    if (status == SyncStatus.syncing) return 'Syncing…';
    if (lastSync == null) return 'Tap to sync';
    final diff = DateTime.now().difference(lastSync);
    if (diff.inSeconds < 60) return 'Synced just now';
    if (diff.inMinutes < 60) return 'Synced ${diff.inMinutes}m ago';
    return 'Synced ${diff.inHours}h ago';
  }

  Future<void> _handleTap(
      BuildContext context, AppProvider app, bool signedIn) async {
    if (!signedIn) {
      // Show sign-in bottom sheet
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _SignInSheet(app: app),
      );
      return;
    }

    // Already signed in — show sync options menu
    final RenderBox btn =
        context.findRenderObject()! as RenderBox;
    final pos = btn.localToGlobal(Offset.zero);

    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          pos.dx, pos.dy + btn.size.height, pos.dx + 200, 0),
      items: [
        PopupMenuItem(
          onTap: () => app.manualSync(),
          child: const Row(
            children: [
              Icon(Icons.sync, size: 18),
              SizedBox(width: 10),
              Text('Pull latest from Drive'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () async {
            await DriveSyncService.instance.signOut();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed out from Google')),
              );
            }
          },
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: Colors.red.shade400),
              const SizedBox(width: 10),
              Text('Sign out',
                  style: TextStyle(color: Colors.red.shade400)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Sign-in bottom sheet ──────────────────────────────────────────────────────

class _SignInSheet extends StatefulWidget {
  final AppProvider app;
  const _SignInSheet({required this.app});

  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    final ok = await DriveSyncService.instance.signIn();
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      // Immediately pull & merge after first sign-in
      await widget.app.manualSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Signed in as ${DriveSyncService.instance.userEmail}. Data synced!'),
          ),
        );
      }
    } else {
      setState(() {
        _loading = false;
        _error   = 'Sign-in cancelled or failed. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Icon(Icons.cloud_sync_outlined, size: 48, color: kNavy),
          const SizedBox(height: 12),
          const Text(
            'Enable Drive Sync',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: kNavy),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign in with the shared JSS Gmail account.\nAll three phones will stay in sync automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280),
                height: 1.5),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: kNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.login, size: 20),
              label: Text(_loading ? 'Signing in…' : 'Sign in with Google'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip for now',
                style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
        ],
      ),
    );
  }
}
