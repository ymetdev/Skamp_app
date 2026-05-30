import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class UsernameSetupScreen extends ConsumerStatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  ConsumerState<UsernameSetupScreen> createState() =>
      _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends ConsumerState<UsernameSetupScreen> {
  final _controller = TextEditingController();
  String? _errorText;
  bool _isChecking = false;
  bool _isAvailable = false;

  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_.]{3,20}$');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkUsername(String value) async {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _errorText = null;
        _isAvailable = false;
      });
      return;
    }

    if (!_usernameRegex.hasMatch(trimmed)) {
      setState(() {
        _errorText = '3–20 chars, letters, numbers, _ and . only';
        _isAvailable = false;
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _errorText = null;
      _isAvailable = false;
    });

    final available =
        await ref.read(usernameNotifierProvider.notifier).checkAvailable(trimmed);

    setState(() {
      _isChecking = false;
      _isAvailable = available;
      _errorText = available ? null : 'Username already taken';
    });
  }

  Future<void> _confirm() async {
    final user = ref.read(authStateProvider).value;
    if (user == null || !_isAvailable) return;

    await ref.read(usernameNotifierProvider.notifier).setUsername(
          user.uid,
          _controller.text.trim(),
          user.email ?? '',
          displayName: user.displayName,
          photoURL: user.photoURL,
        );
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(usernameNotifierProvider);

    ref.listen(usernameNotifierProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to set username. Try again.'),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(usernameNotifierProvider.notifier).reset();
      }
    });

    final isLoading = setupState is AsyncLoading;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 64),
              const Text(
                'Pick a username',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkBlack),
              ),
              const SizedBox(height: 8),
              const Text(
                'Friends will find you by this name.\nYou can\'t change it later.',
                style:
                    TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: 20,
                onChanged: _checkUsername,
                decoration: InputDecoration(
                  labelText: 'username',
                  prefixText: '@',
                  counterText: '',
                  errorText: _errorText,
                  suffixIcon: _buildSuffixIcon(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '3–20 characters · letters, numbers, _ and .',
                style:
                    TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: (isLoading || !_isAvailable) ? null : _confirm,
                child: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.cream),
                      )
                    : const Text('CONFIRM'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (_isChecking) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_controller.text.trim().isEmpty) return null;
    if (_isAvailable) {
      return const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32));
    }
    if (_errorText != null) {
      return const Icon(Icons.cancel_outlined, color: AppColors.error);
    }
    return null;
  }
}
