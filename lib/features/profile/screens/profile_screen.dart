import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/social/providers/friend_provider.dart';

// Avatar with network image + graceful fallback
class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String fallbackLabel;
  final double radius;

  const _Avatar({
    required this.photoUrl,
    required this.fallbackLabel,
    this.radius = 52,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF3A3A3A),
        child: ClipOval(
          child: Image.network(
            photoUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF3A3A3A),
      child: _fallback(),
    );
  }

  Widget _fallback() {
    return Text(
      fallbackLabel.isNotEmpty ? fallbackLabel[0].toUpperCase() : '?',
      style: TextStyle(
        color: Colors.white,
        fontSize: radius * 0.7,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).value;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(child: CircularProgressIndicator(color: Colors.white54)),
      );
    }

    final friendCount = ref.watch(myFriendsProvider).value?.length ?? 0;
    final bottom = MediaQuery.of(context).padding.bottom;
    // Firestore photoURL may be null for older accounts — fall back to Firebase Auth
    final authPhotoUrl = ref.watch(authStateProvider).value?.photoURL;
    final photoUrl = user.photoURL ?? authPhotoUrl;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Profile',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 32),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 24),
                children: [
                  const SizedBox(height: 12),

                  // ── Avatar + name ───────────────────────────────────────────
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _Avatar(
                          photoUrl: photoUrl,
                          fallbackLabel: user.username,
                          radius: 52,
                        ),
                        // Edit button
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF1A1A1A), width: 2),
                            ),
                            child: const Icon(Icons.edit_outlined,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Display name
                  Center(
                    child: Text(
                      user.displayName ?? user.username,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text('@${user.username}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 15)),
                  ),

                  const SizedBox(height: 20),

                  // ── Premium banner ──────────────────────────────────────────
                  if (!user.isPremium)
                    _PremiumBanner()
                  else
                    _PremiumActiveBadge(),

                  const SizedBox(height: 12),

                  // ── Friends row ─────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people_outline,
                                    color: Colors.white, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  '$friendCount Friend${friendCount == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Add friend button
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          // TODO: open add friend dialog
                        },
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2A2A2A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_add_outlined,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── General section ─────────────────────────────────────────
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 12),
                    child: Text('General',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                  ),

                  _GeneralItem(
                    icon: Icons.error_outline_rounded,
                    label: 'Report a Problem',
                    onTap: () {},
                  ),
                  const SizedBox(height: 2),
                  _GeneralItem(
                    icon: Icons.favorite_outline_rounded,
                    label: 'Terms of Service',
                    onTap: () {},
                  ),
                  const SizedBox(height: 2),
                  _GeneralItem(
                    icon: Icons.verified_user_outlined,
                    label: 'Privacy Policy',
                    onTap: () {},
                  ),
                  const SizedBox(height: 2),
                  _GeneralItem(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete Account',
                    dimmed: true,
                    onTap: () => _confirmDeleteAccount(context, ref),
                  ),

                  // ── Dev panel ───────────────────────────────────────────────
                  if (kDebugMode) ...[
                    const SizedBox(height: 28),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text('DEV',
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5)),
                    ),
                    _DevPanel(uid: user.uid, isPremium: user.isPremium),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'This is permanent and cannot be undone. All your stamps and journals will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      // TODO: implement full account deletion via Cloud Function
    }
  }
}

// ── Premium banner (free users) ───────────────────────────────────────────────

class _PremiumBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF3A3A3A),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('✦', style: TextStyle(color: Colors.white, fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Get skamp! plus',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text('Show the world who you are\nwith skamp! plus',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Premium active badge (premium users) ──────────────────────────────────────

class _PremiumActiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF3A3A3A),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('★', style: TextStyle(color: Color(0xFFFFD700), fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('skamp! plus',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text('Active — thank you for your support!',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── General list item ─────────────────────────────────────────────────────────

class _GeneralItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dimmed;

  const _GeneralItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = dimmed ? Colors.white38 : Colors.white;
    return GestureDetector(
      onTap: dimmed ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Dev panel (debug builds only) ─────────────────────────────────────────────

class _DevPanel extends ConsumerStatefulWidget {
  final String uid;
  final bool isPremium;
  const _DevPanel({required this.uid, required this.isPremium});

  @override
  ConsumerState<_DevPanel> createState() => _DevPanelState();
}

class _DevPanelState extends ConsumerState<_DevPanel> {
  bool _loading = false;

  Future<void> _togglePremium() async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update({'isPremium': !widget.isPremium});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Failed: $e\nAdd UID to config/devAccess.uids in Firestore Console'),
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetDailyCount() async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update({'dailyStampCount': 0, 'lastStampDate': null});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Daily count reset')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              widget.isPremium ? Icons.star_rounded : Icons.star_outline_rounded,
              color: const Color(0xFFFFD700),
            ),
            title: Text(
              widget.isPremium ? 'Revoke Premium' : 'Grant Premium',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Needs UID in config/devAccess.uids',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
            trailing: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white54))
                : Switch(
                    value: widget.isPremium,
                    onChanged: (_) => _togglePremium(),
                    activeColor: const Color(0xFFFFD700),
                  ),
          ),
          const Divider(color: Colors.white12, height: 1),
          ListTile(
            leading:
                const Icon(Icons.refresh_rounded, color: Colors.white54),
            title: const Text('Reset Daily Stamp Count',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            onTap: _loading ? null : _resetDailyCount,
          ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              'UID: ${ref.watch(userProvider).value?.uid ?? '...'}',
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
