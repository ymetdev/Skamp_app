import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class InviteCodeScreen extends ConsumerStatefulWidget {
  const InviteCodeScreen({super.key});

  @override
  ConsumerState<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends ConsumerState<InviteCodeScreen> {
  final _controller = TextEditingController();
  String? _errorText;
  bool _isChecking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isChecking = true;
      _errorText = null;
    });

    // ตรวจสอบ code ก่อน
    final error = await ref.read(inviteNotifierProvider.notifier).verify(code);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isChecking = false;
        _errorText = error;
      });
      return;
    }

    // Code valid — redeem
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    await ref.read(inviteNotifierProvider.notifier).redeem(user.uid, code);

    // router จะ navigate ออกทันที หลัง isInvited = true
    // เช็ค mounted ก่อน setState เพื่อป้องกัน dispose error
    if (mounted) setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    final inviteState = ref.watch(inviteNotifierProvider);

    ref.listen(inviteNotifierProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Try again.'),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(inviteNotifierProvider.notifier).reset();
        setState(() => _isChecking = false);
      }
    });

    final isLoading = inviteState is AsyncLoading || _isChecking;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 64),
              Image.asset('assets/2.png', width: 56),
              const SizedBox(height: 24),
              const Text(
                'You\'re invited.',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkBlack,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'skamp! is currently invite-only.\nEnter your invite code to continue.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  letterSpacing: 4,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: 'Invite code',
                  errorText: _errorText,
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _errorText = null);
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() => _errorText = null),
                onSubmitted: (_) => isLoading ? null : _submit(),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.cream),
                      )
                    : const Text('CONTINUE'),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () =>
                      ref.read(authNotifierProvider.notifier).signOut(),
                  child: const Text(
                    'Sign out',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
