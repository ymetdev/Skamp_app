import 'dart:io';
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
import '../../stamps/providers/stamp_provider.dart';
import '../widgets/stamp_shape_clipper.dart';
import '../widgets/stamp_machine.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _initialized = false;
  String? _error;
  XFile? _capturedFile;
  StampShape _shape = StampShape.rounded;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (!kIsWeb) _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
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
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      _controller = ctrl;
      if (mounted) setState(() => _initialized = true);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _error = e.description ?? 'Camera unavailable');
      }
    }
  }

  Future<Position?> _getLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;
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

    // Check daily limit
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stamp added to collection!'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } else {
      final err = ref.read(stampCaptureProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $err')),
      );
      setState(() => _capturedFile = null);
    }
  }

  void _retake() {
    ref.read(stampCaptureProvider.notifier).reset();
    setState(() => _capturedFile = null);
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Daily limit reached"),
        content: const Text(
            "Free accounts can capture 3 stamps per day.\nUpgrade to Premium for unlimited stamps."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _buildWebPlaceholder();
    if (_error != null) return _buildError();
    if (!_initialized) return _buildLoading();
    if (_capturedFile != null) return _buildPreview();
    return _buildViewfinder();
  }

  // ── Viewfinder ─────────────────────────────────────────────────────────────

  Widget _buildViewfinder() {
    final ctrl = _controller!;
    final size = MediaQuery.of(context).size;

    final previewRatio = ctrl.value.aspectRatio;
    final screenRatio = size.width / size.height;
    final scale =
        previewRatio < screenRatio ? size.width / (size.height * previewRatio) : 1.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview (full screen)
          Transform.scale(
            scale: scale,
            child: Center(child: CameraPreview(ctrl)),
          ),

          // Machine overlay
          Positioned.fill(
            child: StampMachineOverlay(
              shape: _shape,
              isCapturing: _isCapturing,
              onCapture: _capture,
              onShapeSelected: (s) => setState(() => _shape = s),
            ),
          ),

          // Top controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  MachineCircleButton(icon: Icons.person_add_outlined, onTap: () {}),
                  _DailyCounter(),
                  MachineCircleButton(icon: Icons.person_outline, onTap: () => context.push('/profile')),
                ],
              ),
            ),
          ),

          // Bottom nav pill
          Positioned(
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            left: 0, right: 0,
            child: Center(
              child: CameraBottomNav(items: [
                CameraNavItem(icon: Icons.camera_alt, active: true, onTap: () {}),
                CameraNavItem(icon: Icons.grid_view_outlined, onTap: () => context.push('/home', extra: 1)),
                CameraNavItem(icon: Icons.people_outline, onTap: () => context.push('/home', extra: 0)),
                CameraNavItem(icon: Icons.book_outlined, onTap: () => context.push('/home', extra: 2)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Preview (after capture) ────────────────────────────────────────────────

  Widget _buildPreview() {
    final isUploading = ref.watch(stampCaptureProvider).isLoading;
    final file = _capturedFile!;
    final size = MediaQuery.of(context).size;
    final stampW = size.width * 0.72;
    final stampH = stampW / kStampAspect;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-frame background (blurred)
          SizedBox.expand(
            child: Image.file(
              File(file.path),
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.5),
              colorBlendMode: BlendMode.darken,
            ),
          ),

          // Stamp preview — clipped to shape
          Center(
            child: SizedBox(
              width: stampW,
              height: stampH,
              child: ClipPath(
                clipper: StampClipper(_shape),
                child: Image.file(File(file.path), fit: BoxFit.cover),
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: isUploading ? null : _retake,
                  ),
                  const Spacer(),
                  Text(
                    _shape.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          // Confirm / Retake
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: isUploading
                    ? const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text('Saving stamp…',
                                style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.refresh,
                                  color: Colors.white),
                              label: const Text('Retake',
                                  style: TextStyle(color: Colors.white)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white54),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _retake,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text('Keep'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _confirmCapture,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── States ─────────────────────────────────────────────────────────────────

  Widget _buildLoading() => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Starting camera…',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );

  Widget _buildError() => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_outlined,
                  color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Go back',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );

  Widget _buildWebPlaceholder() => Scaffold(
        backgroundColor: AppColors.inkBlack,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone_iphone, color: Colors.white54, size: 72),
              const SizedBox(height: 24),
              const Text(
                'Camera requires the mobile app',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Open skamp! on iOS or Android to capture stamps.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54)),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
}

// ─── Daily counter badge ───────────────────────────────────────────────────────

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
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white38),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            color: remaining > 0 ? Colors.white : Colors.red[300],
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '$remaining / 3',
            style: TextStyle(
              color: remaining > 0 ? Colors.white : Colors.red[300],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Capture button ────────────────────────────────────────────────────────────

class _CaptureButton extends StatelessWidget {
  final bool isCapturing;
  final VoidCallback onTap;

  const _CaptureButton({required this.isCapturing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: isCapturing ? 68 : 72,
        height: isCapturing ? 68 : 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCapturing ? Colors.white.withOpacity(0.7) : Colors.white,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: isCapturing
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
