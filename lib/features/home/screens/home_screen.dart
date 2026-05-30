import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/stamp_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../camera/widgets/stamp_machine.dart';
import '../../camera/widgets/stamp_shape_clipper.dart';
import '../../stamps/providers/stamp_provider.dart';
import '../../stamps/screens/collection_screen.dart';
import '../../journals/screens/journal_list_screen.dart';

// ─── Shell ─────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          _CameraTab(onTabChange: (i) => setState(() => _tab = i)),
          const _CollectionTab(),
          const _FriendsTab(),
          const _JournalsTab(),
        ],
      ),
      bottomNavigationBar: _NavPill(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

// ─── Persistent nav pill ───────────────────────────────────────────────────────

class _NavPill extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _NavPill({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : 12, top: 8),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PillItem(icon: Icons.home_outlined, active: current == 0, onTap: () => onTap(0)),
            _PillItem(icon: Icons.bookmark_outline, active: current == 1, onTap: () => onTap(1)),
            _PillItem(icon: Icons.people_outline, active: current == 2, onTap: () => onTap(2)),
            _PillItem(icon: Icons.book_outlined, active: current == 3, onTap: () => onTap(3)),
          ],
        ),
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _PillItem({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 40,
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.88) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(icon, color: active ? Colors.black : Colors.white, size: 22),
      ),
    );
  }
}

// ─── Tab 0: Camera ─────────────────────────────────────────────────────────────

class _CameraTab extends ConsumerStatefulWidget {
  final ValueChanged<int> onTabChange;
  const _CameraTab({required this.onTabChange});

  @override
  ConsumerState<_CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends ConsumerState<_CameraTab>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _initialized = false;
  String? _error;
  XFile? _capturedFile;
  StampShape _shape = StampShape.perforated; // machine x1 default
  bool _isCapturing = false;
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
      if (mounted) setState(() => _initialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera available');
        return;
      }
      final ctrl = CameraController(
        cameras[0], ResolutionPreset.high,
        enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      _controller = ctrl;
      if (mounted) setState(() => _initialized = true);
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = e.description ?? 'Camera unavailable');
    }
  }

  Future<Position?> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return null;
      }
      if (perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _capture() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _isCapturing) return;
    final user = ref.read(userProvider).value;
    if (user != null && !user.canStampToday) {
      _showLimitDialog();
      return;
    }
    setState(() => _isCapturing = true);
    HapticFeedback.mediumImpact();
    try {
      final file = await ctrl.takePicture();
      if (mounted) setState(() => _capturedFile = file);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _confirmCapture() async {
    final file = _capturedFile;
    if (file == null) return;
    HapticFeedback.heavyImpact();
    final position = await _getLocation();
    final stamp = await ref.read(stampCaptureProvider.notifier).capture(
      imageFile: File(file.path),
      shape: _shape,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
    if (!mounted) return;
    if (stamp != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Stamp added to collection!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
    }
    setState(() => _capturedFile = null);
  }

  void _retake() {
    ref.read(stampCaptureProvider.notifier).reset();
    setState(() => _capturedFile = null);
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Daily limit reached'),
        content: const Text('Free accounts can capture 3 stamps per day.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _goToFeed() => _pageController.nextPage(
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);

  void _goToCamera() => _pageController.previousPage(
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);

  @override
  Widget build(BuildContext context) {
    if (_capturedFile != null) return _buildPreview();
    if (_error != null) return _buildError();
    if (!_initialized || _controller == null) return _buildLoading();
    return PageView(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      physics: const ClampingScrollPhysics(),
      children: [_buildCameraPage(), _buildFeedPage()],
    );
  }

  Widget _buildCameraPage() {
    final ctrl = _controller!;
    final size = MediaQuery.of(context).size;
    final previewRatio = ctrl.value.aspectRatio;
    final screenRatio = size.width / size.height;
    final scale = previewRatio < screenRatio
        ? size.width / (size.height * previewRatio)
        : 1.0;
    final navH = MediaQuery.of(context).padding.bottom + 72.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          Transform.scale(scale: scale, child: Center(child: CameraPreview(ctrl))),

          // Machine overlay
          Positioned(
            top: 0, left: 0, right: 0,
            bottom: navH,
            child: StampMachineOverlay(
              shape: _shape,
              isCapturing: _isCapturing,
              onCapture: _capture,
              onShapeSelected: (s) => setState(() => _shape = s),
            ),
          ),

          // Top bar: [person+] [shape dots] [person]
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  MachineCircleButton(icon: Icons.person_add_outlined, onTap: () {}),
                  Expanded(
                    child: Center(child: MachineSelector(
                      selected: _shape,
                      onSelected: (s) => setState(() => _shape = s),
                    )),
                  ),
                  MachineCircleButton(
                    icon: Icons.person_outline,
                    onTap: () => context.push('/profile'),
                  ),
                ],
              ),
            ),
          ),

          // Feed hint
          Positioned(
            bottom: navH + 4,
            left: 0, right: 0,
            child: GestureDetector(
              onTap: _goToFeed,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_arrow_down, color: Colors.white38, size: 16),
                  SizedBox(width: 4),
                  Text('Feed', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 0.5)),
                  SizedBox(width: 6),
                  CircleAvatar(radius: 3, backgroundColor: AppColors.error),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedPage() {
    final user = ref.watch(userProvider).value;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(children: [
        SafeArea(child: GestureDetector(
          onTap: _goToCamera,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.stampBorder, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 4),
              const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 18),
            ]),
          ),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
          child: Row(children: [
            Image.asset('assets/4.png', height: 100),
            const Spacer(),
            IconButton(icon: const Icon(Icons.person_add_outlined), onPressed: () {}),
            IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
          ]),
        ),
        Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Image.asset('assets/2.png', width: 72, opacity: const AlwaysStoppedAnimation(0.25)),
          const SizedBox(height: 20),
          Text('Hey @${user?.username ?? ''}!',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.inkBlack)),
          const SizedBox(height: 8),
          const Text('Add friends to see their stamps here.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ]))),
      ]),
    );
  }

  Widget _buildPreview() {
    final isUploading = ref.watch(stampCaptureProvider).isLoading;
    final file = _capturedFile!;
    final size = MediaQuery.of(context).size;
    final stampW = size.width * 0.72;
    final stampH = stampW / kStampAspect;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        SizedBox.expand(child: Image.file(File(file.path), fit: BoxFit.cover,
          color: Colors.black.withOpacity(0.5), colorBlendMode: BlendMode.darken)),
        Center(child: SizedBox(width: stampW, height: stampH,
          child: ClipPath(clipper: StampClipper(_shape),
            child: Image.file(File(file.path), fit: BoxFit.cover)))),
        SafeArea(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: isUploading ? null : _retake),
            const Spacer(),
            Text(_shape.label, style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const Spacer(),
            const SizedBox(width: 48),
          ]),
        )),
        Positioned(bottom: 0, left: 0, right: 0,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: isUploading
                ? const Center(child: Column(children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text('Saving stamp…', style: TextStyle(color: Colors.white70)),
                  ]))
                : Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text('Retake', style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: _retake)),
                    const SizedBox(width: 16),
                    Expanded(child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Keep'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: _confirmCapture)),
                  ]),
          ))),
      ]),
    );
  }

  Widget _buildLoading() => const Scaffold(
    backgroundColor: Colors.black,
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircularProgressIndicator(color: Colors.white),
      SizedBox(height: 16),
      Text('Starting camera…', style: TextStyle(color: Colors.white70)),
    ])),
  );

  Widget _buildError() => Scaffold(
    backgroundColor: Colors.black,
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 64),
      const SizedBox(height: 16),
      Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
    ])),
  );
}


// ─── Daily counter ─────────────────────────────────────────────────────────────

class _DailyCounter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).value;
    if (user == null || user.isPremium) return const SizedBox.shrink();
    final now = DateTime.now();
    final isToday = user.lastStampDate != null &&
        user.lastStampDate!.year == now.year &&
        user.lastStampDate!.month == now.month &&
        user.lastStampDate!.day == now.day;
    final used = isToday ? user.dailyStampCount : 0;
    final remaining = (3 - used).clamp(0, 3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white38)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.photo_camera_outlined,
          color: remaining > 0 ? Colors.white : Colors.red[300], size: 14),
        const SizedBox(width: 4),
        Text('$remaining / 3', style: TextStyle(
          color: remaining > 0 ? Colors.white : Colors.red[300],
          fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─── Tab 1: Collection ─────────────────────────────────────────────────────────

class _CollectionTab extends StatelessWidget {
  const _CollectionTab();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
        ),
      ),
      child: const CollectionScreen(),
    );
  }
}

// ─── Tab 2: Friends ────────────────────────────────────────────────────────────

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Friends', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400)),
          ),
          Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.people_outline, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            const Text('No friends yet', style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Add friends by username', style: TextStyle(color: Colors.white24, fontSize: 13)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_add_outlined, color: Colors.white),
              label: const Text('Add Friend', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white38)),
              onPressed: () {},
            ),
          ]))),
        ]),
      ),
    );
  }
}

// ─── Tab 3: Journals ───────────────────────────────────────────────────────────

class _JournalsTab extends StatelessWidget {
  const _JournalsTab();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
        ),
        cardColor: const Color(0xFF1A1A1A),
        colorScheme: const ColorScheme.dark(),
      ),
      child: const JournalListScreen(),
    );
  }
}
