import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
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
import '../../social/models/friend_model.dart';
import '../../social/providers/friend_provider.dart';

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
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _tab,
              children: [
                _CameraTab(onTabChange: (i) => setState(() => _tab = i)),
                const _CollectionTab(),
                const _FriendsTab(),
                const _JournalsTab(),
              ],
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _NavPill(
              current: _tab,
              onTap: (i) => setState(() => _tab = i),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Persistent nav pill ───────────────────────────────────────────────────────

class _NavPill extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _NavPill({required this.current, required this.onTap});

  static const _icons = [
    Icons.home_outlined,
    Icons.bookmark_outline,
    Icons.people_outline,
    Icons.book_outlined,
  ];
  static const _pillW = 283.0;
  static const _pillH = 64.0;
  static const _indicatorW = 80.0;
  static const _indicatorH = 58.0;
  static const _slotW = _pillW / 4;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final indicatorLeft = current * _slotW + (_slotW - _indicatorW) / 2;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : 16, top: 8),
      alignment: Alignment.center,
      child: SizedBox(
        width: _pillW,
        height: _pillH,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: Stack(
            children: [
              // Pill background
              Positioned.fill(
                child: Container(color: Colors.white.withOpacity(0.5)),
              ),
              // Active indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                left: indicatorLeft,
                top: (_pillH - _indicatorH) / 2,
                child: Container(
                  width: _indicatorW,
                  height: _indicatorH,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              // Icons row
              Row(
                children: List.generate(4, (i) => Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: _pillH,
                      child: Icon(_icons[i], color: Colors.white, size: 28),
                    ),
                  ),
                )),
              ),
            ],
          ),
        ),
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
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  bool _initialized = false;
  String? _error;
  XFile? _capturedFile;
  Uint8List? _croppedBytes;
  StampShape _shape = StampShape.perforated;
  bool _isCapturing = false;
  bool _showCaptureSuccess = false;
  final _pageController = PageController();

  late final AnimationController _flashCtrl;
  late final AnimationController _flyCtrl;
  late final Animation<double> _flyCurved;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();

    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _flyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _flyCurved = CurvedAnimation(parent: _flyCtrl, curve: Curves.easeInCubic);
    _flyCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() { _showCaptureSuccess = false; _capturedFile = null; _croppedBytes = null; });
        _flyCtrl.reset();
        _flashCtrl.reset();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _pageController.dispose();
    _flashCtrl.dispose();
    _flyCtrl.dispose();
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

  // Crop camera image to stamp aspect ratio (portrait center crop)
  Future<Uint8List> _cropToStampAspect(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;

    final srcW = img.width.toDouble();
    final srcH = img.height.toDouble();

    double cropW, cropH;
    if (srcW / srcH > kStampAspect) {
      cropH = srcH;
      cropW = srcH * kStampAspect;
    } else {
      cropW = srcW;
      cropH = srcW / kStampAspect;
    }

    const outW = 600;
    final outH = (outW / kStampAspect).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH((srcW - cropW) / 2, (srcH - cropH) / 2, cropW, cropH),
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    final outImage = await picture.toImage(outW, outH);
    final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    outImage.dispose();
    return byteData!.buffer.asUint8List();
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
    // TODO: re-enable daily limit before release
    // final user = ref.read(userProvider).value;
    // if (user != null && !user.canStampToday) { _showLimitDialog(); return; }
    // Check daily limit (re-enabled — disable for testing by commenting block below)
    final user = ref.read(userProvider).value;
    if (user != null && !user.canStampToday) {
      _showLimitDialog();
      return;
    }

    setState(() => _isCapturing = true);
    HapticFeedback.mediumImpact();
    try {
      final file = await ctrl.takePicture();
      if (!mounted) return;

      // Crop to stamp aspect ratio (viewfinder area only)
      final rawBytes = await file.readAsBytes();
      final cropped = await _cropToStampAspect(rawBytes);
      if (!mounted) return;

      setState(() { _capturedFile = file; _croppedBytes = cropped; _isCapturing = false; });

      // Flash
      await _flashCtrl.forward();
      if (!mounted) return;
      _flashCtrl.reverse();

      // Show stamp preview (no machine UI)
      setState(() => _showCaptureSuccess = true);

      // Save in background
      _saveStamp();

      // Wait then fly to collection icon
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      _flyCtrl.forward();
    } catch (_) {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _importFromGallery() async {
    final user = ref.read(userProvider).value;
    if (user == null || !user.isPremium) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;

    setState(() => _isCapturing = true);
    try {
      final rawBytes = await picked.readAsBytes();
      final cropped = await _cropToStampAspect(rawBytes);
      if (!mounted) return;

      setState(() { _capturedFile = picked; _croppedBytes = cropped; _isCapturing = false; });
      await _flashCtrl.forward();
      if (!mounted) return;
      _flashCtrl.reverse();
      setState(() => _showCaptureSuccess = true);
      _saveStamp();
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      _flyCtrl.forward();
    } catch (_) {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _saveStamp() async {
    final bytes = _croppedBytes;
    if (bytes == null) return;
    final position = await _getLocation();
    await ref.read(stampCaptureProvider.notifier).captureFromBytes(
      imageBytes: bytes,
      shape: _shape,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
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
    if (_showCaptureSuccess && _capturedFile != null) return _buildCaptureSuccess();
    if (_error != null) return _buildError();
    if (!_initialized || _controller == null) return _buildLoading();
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const ClampingScrollPhysics(),
          children: [_buildCameraPage(), _buildFeedPage()],
        ),
        // White flash overlay
        AnimatedBuilder(
          animation: _flashCtrl,
          builder: (_, __) {
            if (_flashCtrl.value == 0) return const SizedBox.shrink();
            return IgnorePointer(
              child: Opacity(
                opacity: _flashCtrl.value,
                child: const ColoredBox(color: Colors.white),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCaptureSuccess() {
    final size = MediaQuery.of(context).size;
    final deviceBottom = MediaQuery.of(context).padding.bottom;
    final navH = 8.0 + 64.0 + (deviceBottom > 0 ? deviceBottom : 16.0);

    final stampW = size.width * 0.72;
    final stampH = stampW / kStampAspect;

    // Collection icon (index 1) center in nav pill
    const pillW = 283.0;
    final collCenterX = (size.width - pillW) / 2 + pillW / 4 * 1.5;
    final collCenterY = size.height - navH / 2;
    const targetSize = 40.0;

    return AnimatedBuilder(
      animation: _flyCurved,
      builder: (context, _) {
        final t = _flyCurved.value;
        final cw = stampW + (targetSize - stampW) * t;
        final ch = stampH + (targetSize - stampH) * t;
        final cx = (size.width / 2 - stampW / 2) + (collCenterX - targetSize / 2 - (size.width / 2 - stampW / 2)) * t;
        final cy = (size.height / 2 - stampH / 2) + (collCenterY - targetSize / 2 - (size.height / 2 - stampH / 2)) * t;
        final opacity = t > 0.75 ? ((1.0 - t) / 0.25).clamp(0.0, 1.0) : 1.0;

        return ColoredBox(
          color: const Color(0xFF1A1A1A),
          child: Stack(
            children: [
              Positioned(
                left: cx, top: cy, width: cw, height: ch,
                child: Opacity(
                  opacity: opacity,
                  child: ClipPath(
                    clipper: StampClipper(_shape),
                    child: _croppedBytes != null
                        ? Image.memory(_croppedBytes!, fit: BoxFit.cover)
                        : (kIsWeb
                            ? Image.network(_capturedFile!.path, fit: BoxFit.cover)
                            : Image.file(File(_capturedFile!.path), fit: BoxFit.cover)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCameraPage() {
    final ctrl = _controller!;
    final deviceBottom = MediaQuery.of(context).padding.bottom;
    final navH = 8.0 + 64.0 + (deviceBottom > 0 ? deviceBottom : 16.0);
    // Feed label gets its own fixed-height band so it never overlaps camera or nav
    const feedH = 52.0;
    final size = MediaQuery.of(context).size;
    final camTop = size.height * 0.17;
    // Camera is ~82% wide — machine (72%) sits on top with slight bleed on each side
    final camPadH = size.width * 0.09;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        // Black background
        const ColoredBox(color: const Color(0xFF1A1A1A)),

        // Camera preview — padded with rounded corners
        Positioned(
          top: camTop,
          left: camPadH,
          right: camPadH,
          bottom: navH + feedH,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: _buildCameraPreviewFill(ctrl),
          ),
        ),

        // Machine overlay — same bottom boundary as camera rect
        Positioned(
          top: 150, left: 0, right: 0,
          bottom: navH + feedH,
          child: StampMachineOverlay(
            shape: _shape,
            isCapturing: _isCapturing,
            onCapture: _capture,
            onShapeSelected: (s) => setState(() => _shape = s),
          ),
        ),

        // Top bar: [person+] [shape dots] [🍞]
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Gallery import (premium) or person+ (free)
                  Builder(builder: (context) {
                    final isPremium = ref.watch(userProvider).value?.isPremium ?? false;
                    if (isPremium) {
                      return MachineCircleButton(
                        icon: Icons.photo_library_outlined,
                        onTap: _importFromGallery,
                      );
                    }
                    return MachineCircleButton(
                      icon: Icons.person_add_outlined,
                      onTap: () {},
                    );
                  }),
                  Expanded(
                    child: Center(child: MachineSelector(
                      selected: _shape,
                      onSelected: (s) => setState(() => _shape = s),
                    )),
                  ),
                  _EmojiCircleButton(emoji: '🍞', onTap: () => context.push('/profile')),
                ],
              ),
            ),
          ),
        ),

        // Feed hint — dedicated band between camera and nav pill
        Positioned(
          bottom: navH,
          left: 0, right: 0,
          height: feedH,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _goToFeed,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 24),
                SizedBox(width: 4),
                Text('Feed', style: TextStyle(color: Colors.white, fontSize: 20)),
                SizedBox(width: 6),
                CircleAvatar(radius: 4, backgroundColor: Color(0xFFFD5659)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPreviewFill(CameraController ctrl) {
    final previewSize = ctrl.value.previewSize;
    if (previewSize == null) return SizedBox.expand(child: CameraPreview(ctrl));

    return LayoutBuilder(builder: (context, constraints) {
      final screenW = constraints.maxWidth;
      final screenH = constraints.maxHeight;
      // On web previewSize is not rotated; on mobile it is.
      final previewW = kIsWeb ? previewSize.width : previewSize.height;
      final previewH = kIsWeb ? previewSize.height : previewSize.width;
      // Scale up to cover the full screen (BoxFit.cover logic)
      final scale = math.max(screenW / previewW, screenH / previewH);
      return ClipRect(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: SizedBox(
            width: previewW * scale,
            height: previewH * scale,
            child: CameraPreview(ctrl),
          ),
        ),
      );
    });
  }

  static const _mockFeed = [
    ('pchdoy',   '1h ago',  'finished a journal page'),
    ('temy',     '2h ago',  'finished a journal page'),
    ('nattakit', '3h ago',  'finished a journal page'),
    ('minkygm',  '5h ago',  'finished a journal page'),
    ('artbkk',   '8h ago',  'finished a journal page'),
    ('pchdoy',   '1d ago',  'finished a journal page'),
  ];

  Widget _buildFeedPage() {
    final deviceBottom = MediaQuery.of(context).padding.bottom;
    final navH = 8.0 + 64.0 + (deviceBottom > 0 ? deviceBottom : 16.0);

    return ColoredBox(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // Header — takes real space so PageView knows its bounds
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _goToCamera,
                    child: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Feed', style: TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600,
                      )),
                    ),
                  ),
                  const SizedBox(width: 32),
                ],
              ),
            ),
          ),
          // TikTok-style paged cards
          Expanded(
            child: PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: _mockFeed.length,
              itemBuilder: (context, i) {
                final (username, timeAgo, action) = _mockFeed[i];
                return _FeedCardPage(
                  username: username,
                  timeAgo: timeAgo,
                  action: action,
                  navH: navH,
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLoading() => const Scaffold(
    backgroundColor: const Color(0xFF1A1A1A),
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircularProgressIndicator(color: Colors.white),
      SizedBox(height: 16),
      Text('Starting camera…', style: TextStyle(color: Colors.white70)),
    ])),
  );

  Widget _buildError() => Scaffold(
    backgroundColor: const Color(0xFF1A1A1A),
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 64),
      const SizedBox(height: 16),
      Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
    ])),
  );
}


// ─── Feed card — full-screen TikTok-style page ────────────────────────────────

class _FeedCardPage extends StatelessWidget {
  final String username;
  final String timeAgo;
  final String action;
  final double navH;

  const _FeedCardPage({
    required this.username,
    required this.timeAgo,
    required this.action,
    required this.navH,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width - 40;
    final h = w * 1.15;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _JournalCard(width: w, height: h),
                const SizedBox(height: 20),
                // User info — centered, tight below card
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 44, height: 44,
                        color: const Color(0xFF2A2A2A),
                        child: const Icon(Icons.person, color: Colors.white54, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(username, style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                          Text(' | $timeAgo', style: const TextStyle(
                            color: Colors.white54, fontSize: 16)),
                        ]),
                        const SizedBox(height: 2),
                        Text(action, style: const TextStyle(color: Colors.white38, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white24, size: 28),
              ],
            ),
          ),
        ),
        SizedBox(height: navH + 8),
      ],
    );
  }
}

// ─── Journal page card (white, dotted border, scattered stamps) ───────────────

class _JournalCard extends StatelessWidget {
  final double width;
  final double height;
  const _JournalCard({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _DottedBorderPainter(),
          child: Container(
            color: Colors.white,
            child: Stack(
              children: [
                // Stamp 1 — large, top-left, tilted left (bottom layer)
                Positioned(
                  left: -width * 0.02, top: height * 0.03,
                  child: Transform.rotate(angle: -0.07,
                    child: _miniStamp(width * 0.62, height * 0.47,
                      const Color(0xFFC8A96E), '🇹🇭', '๖\nบาท')),
                ),
                // Stamp 2 — top-right, overlapping stamp 1
                Positioned(
                  right: -width * 0.01, top: height * 0.06,
                  child: Transform.rotate(angle: 0.14,
                    child: _miniStamp(width * 0.57, height * 0.43,
                      const Color(0xFF8BC4A8), '🇹🇭', '๖\nบาท')),
                ),
                // Stamp 3 — bottom-right, overlapping stamp 2
                Positioned(
                  right: -width * 0.01, bottom: height * 0.02,
                  child: Transform.rotate(angle: -0.05,
                    child: _miniStamp(width * 0.57, height * 0.42,
                      const Color(0xFF7B9EC0), '🇹🇭', '๖\nบาท')),
                ),
                // Rubber stamp THAILAND — over stamp 1, top-left
                Positioned(
                  left: width * 0.03, top: height * 0.20,
                  child: _rubberStamp('THAILAND', const Color(0xFF7B68EE), width * 0.33),
                ),
                // Rubber stamp BUS — bottom-left, over stamp 1
                Positioned(
                  left: width * 0.04, bottom: height * 0.04,
                  child: _rubberStamp('BUS', const Color(0xFFE07050), width * 0.30),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniStamp(double w, double h, Color color, String flag, String value) {
    return ClipPath(
      clipper: const StampClipper(StampShape.perforated),
      child: SizedBox(
        width: w, height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFFF5EED8)),
            Positioned(
              top: w * 0.06, left: w * 0.06,
              right: w * 0.06, bottom: w * 0.06,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(color: color),
              ),
            ),
            Positioned(top: 6, right: 6,
              child: Text(value, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w900, height: 1.1,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 3)]))),
            Positioned(bottom: 6, left: 6,
              child: Text(flag, style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }

  Widget _rubberStamp(String label, Color color, double size) {
    final icon = label == 'BUS' ? Icons.directions_bus_outlined : Icons.account_balance_outlined;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.80), width: 2.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: color.withOpacity(0.85),
            fontSize: size * 0.13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          Icon(icon, color: color.withOpacity(0.70), size: size * 0.30),
          Text(label, style: TextStyle(color: color.withOpacity(0.85),
            fontSize: size * 0.13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ],
      ),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  const _DottedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    const r = 1.8;
    const gap = 9.0;
    const margin = 9.0;

    for (double x = margin; x < size.width - margin + 1; x += gap) {
      canvas.drawCircle(Offset(x, margin), r, paint);
      canvas.drawCircle(Offset(x, size.height - margin), r, paint);
    }
    for (double y = margin + gap; y < size.height - margin; y += gap) {
      canvas.drawCircle(Offset(margin, y), r, paint);
      canvas.drawCircle(Offset(size.width - margin, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedBorderPainter _) => false;
}

// ─── Emoji circle button (for bread profile icon etc.) ────────────────────────

class _EmojiCircleButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;
  const _EmojiCircleButton({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0x80FFFFFF),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) => const CollectionScreen();
}

// ─── Tab 2: Friends ────────────────────────────────────────────────────────────

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final navH = 8.0 + 64.0 + (bottom > 0 ? bottom : 16.0);
    final friendsAsync = ref.watch(myFriendsProvider);
    final user = ref.watch(userProvider).value;
    final maxFriends = (user?.isPremium ?? false) ? 999 : 20;

    return ColoredBox(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Add friend button
                  GestureDetector(
                    onTap: () => _showAddFriendDialog(context, ref, maxFriends,
                        friendsAsync.value?.length ?? 0),
                    child: Container(
                      width: 48, height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0x80FFFFFF), shape: BoxShape.circle),
                      child: const Icon(Icons.person_add_outlined,
                          color: Colors.white, size: 24),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Friends', style: TextStyle(
                        color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.w700)),
                    ),
                  ),
                  _EmojiCircleButton(emoji: '🍞', onTap: () {}),
                ],
              ),
            ),
          ),
          Expanded(
            child: friendsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white54)),
              error: (_, __) => const Center(
                  child: Text('Could not load friends',
                      style: TextStyle(color: Colors.white38))),
              data: (friends) {
                if (friends.isEmpty) {
                  return const Center(
                    child: Text('No friends yet\nAdd someone by username',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 15)),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.only(top: 8, bottom: navH + 8),
                  itemCount: friends.length,
                  itemBuilder: (context, i) =>
                      _FriendRow(friend: friends[i], ref: ref),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFriendDialog(
      BuildContext context, WidgetRef ref, int maxFriends, int current) {
    if (current >= maxFriends) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Friend limit reached'),
          content: Text('Free accounts can have up to $maxFriends friends.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _AddFriendDialog(),
    );
  }
}

class _FriendRow extends StatelessWidget {
  final FriendProfile friend;
  final WidgetRef ref;
  const _FriendRow({required this.friend, required this.ref});

  @override
  Widget build(BuildContext context) {
    final initials = friend.username.isNotEmpty
        ? friend.username[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          friend.photoURL != null
              ? CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(friend.photoURL!),
                )
              : CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF2A2A2A),
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.displayName ?? friend.username,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600),
                ),
                if (friend.displayName != null)
                  Text('@${friend.username}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 13)),
              ],
            ),
          ),
          // Remove button
          GestureDetector(
            onTap: () => _confirmRemove(context),
            child: const Icon(Icons.more_horiz, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove @${friend.username}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(friendNotifierProvider.notifier).remove(friend.uid);
    }
  }
}

class _AddFriendDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends ConsumerState<_AddFriendDialog> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final username = _ctrl.text.trim();
    if (username.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    final error = await ref.read(friendNotifierProvider.notifier)
        .addByUsername(username);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() { _loading = false; _error = error; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Friend', style: TextStyle(fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixText: '@',
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _loading ? null : _add,
          child: _loading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Add'),
        ),
      ],
    );
  }
}

// ─── Tab 3: Journals ───────────────────────────────────────────────────────────

class _JournalsTab extends StatelessWidget {
  const _JournalsTab();

  @override
  Widget build(BuildContext context) => const JournalListScreen();
}
