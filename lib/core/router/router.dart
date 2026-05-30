import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/invite_code_screen.dart';
import '../../features/auth/screens/username_setup_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/camera/screens/camera_screen.dart';
import '../../features/stamps/screens/collection_screen.dart';
import '../../features/journals/screens/journal_list_screen.dart';
import '../../features/journals/screens/journal_detail_screen.dart';
import '../../features/journals/screens/journal_page_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../providers/app_config_provider.dart';

// true หลังจาก splash แสดงครบ minimum duration แล้ว
class _SplashReadyNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setReady() => state = true;
}

final splashReadyProvider = NotifierProvider<_SplashReadyNotifier, bool>(
  _SplashReadyNotifier.new,
);

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(userProvider, (_, __) => notifyListeners());
    _ref.listen(appConfigProvider, (_, __) => notifyListeners());
    _ref.listen(splashReadyProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/loading',
    refreshListenable: notifier,
    redirect: (context, state) {
      final splashReady = ref.read(splashReadyProvider);
      final authState = ref.read(authStateProvider);
      final userState = ref.read(userProvider);
      final configState = ref.read(appConfigProvider);

      final loc = state.matchedLocation;

      // รอ splash ครบ minimum duration ก่อน
      if (!splashReady) return loc == '/loading' ? null : '/loading';

      final isLoggedIn = authState.value != null;
      final user = userState.value;
      final inviteOnly = configState.value?.inviteOnly ?? true;

      // ยังไม่ login → login
      if (!isLoggedIn) return loc == '/login' ? null : '/login';

      // login แล้วแต่ user profile ยังโหลดไม่เสร็จ — แสดง loading screen
      if (userState.isLoading) {
        return loc == '/loading' ? null : '/loading';
      }

      // login แล้ว แต่ inviteOnly=true และยังไม่ได้รับ invite
      if (inviteOnly && !(user?.isInvited ?? false)) {
        return loc == '/invite' ? null : '/invite';
      }

      // login + invited แต่ยังไม่มี username
      if (user != null && user.username.isEmpty) {
        return loc == '/username-setup' ? null : '/username-setup';
      }

      // ผ่านทุกด่าน — ถ้ายังอยู่หน้า auth/loading redirect ไป home
      if (loc == '/login' || loc == '/invite' || loc == '/username-setup' || loc == '/loading') {
        return '/home';
      }

      return null;
    },
    routes: [
      // Loading splash
      GoRoute(
        path: '/loading',
        builder: (_, __) => const _LoadingSplash(),
      ),

      // Auth flow
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/invite', builder: (_, __) => const InviteCodeScreen()),
      GoRoute(
          path: '/username-setup',
          builder: (_, __) => const UsernameSetupScreen()),

      // Main app shell
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
        routes: [
          // Sub-routes accessible from any tab
        ],
      ),

      // Camera — capture from non-home contexts
      GoRoute(path: '/camera', builder: (_, __) => const CameraScreen()),

      // Section screens pushed from top bar buttons
      GoRoute(path: '/stamps', builder: (_, __) => const CollectionScreen()),
      GoRoute(path: '/journals', builder: (_, __) => const JournalListScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),

      // Journal detail + page editing
      GoRoute(
        path: '/journal/:journalId',
        builder: (_, state) => JournalDetailScreen(
          journalId: state.pathParameters['journalId']!,
        ),
      ),
      GoRoute(
        path: '/journal/:journalId/page/:pageId',
        builder: (_, state) => JournalPageScreen(
          journalId: state.pathParameters['journalId']!,
          pageId: state.pathParameters['pageId']!,
        ),
      ),
    ],
  );
});

// ─── Animated loading splash ───────────────────────────────────────────────────

class _LoadingSplash extends ConsumerStatefulWidget {
  const _LoadingSplash();

  @override
  ConsumerState<_LoadingSplash> createState() => _LoadingSplashState();
}

class _LoadingSplashState extends ConsumerState<_LoadingSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceCtrl;
  late final Animation<double> _offsetY;
  late final Animation<double> _shadowOpacity;

  @override
  void initState() {
    super.initState();

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _offsetY = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -22.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -22.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -7.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -7.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.0),
        weight: 22,
      ),
    ]).animate(_bounceCtrl);

    _shadowOpacity = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.20, end: 0.05)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.05, end: 0.20)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.20, end: 0.10)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.10, end: 0.20)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.20),
        weight: 22,
      ),
    ]).animate(_bounceCtrl);

    // Unlock routing after minimum splash duration
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) ref.read(splashReadyProvider.notifier).setReady();
    });
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFAEAD),
      body: Center(
        child: AnimatedBuilder(
          animation: _bounceCtrl,
          builder: (_, __) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: Offset(0, _offsetY.value),
                  child: Image.asset('assets/icon_stamp.png', width: 140),
                ),
                Container(
                  width: 80,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(_shadowOpacity.value),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Image.asset(
                  'assets/wordmark_anim.gif',
                  width: 180,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
