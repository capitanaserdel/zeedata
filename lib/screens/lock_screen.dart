import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _password = '';
  bool _isLoading = false;
  bool _isAutoPromptDone = false;

  @override
  void initState() {
    super.initState();
    // Auto-trigger biometrics once on screen load if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      final isEnabled = user?.userSettings?.passwordFingerprint ?? false;
      print("🔐 LOCK SCREEN: Login Biometric Enabled: $isEnabled");
      
      if (mounted && !_isAutoPromptDone && isEnabled) {
        _authenticateBiometric();
        _isAutoPromptDone = true;
      }
    });
  }

  @override
  void dispose() {
    // No explicit timers to cancel, but we'll be careful with setState below
    super.dispose();
  }

  Future<void> _authenticateBiometric() async {
    if (_isLoading) return;
    
    // We don't set _isLoading here to allow PIN entry if biometric is slow/cancels
    final success = await ref.read(authProvider.notifier).unlockWithBiometrics();
    
    if (!mounted) return;

    if (success) {
      // Navigation is handled by the state change in main.dart (authState.isLocked)
      // but we can add a small haptic or success indicator here if needed
    }
  }

  void _onNumberPress(String number) {
    if (_isLoading) return;
    
    if (_password.length < 6) {
      setState(() => _password += number);
      if (_password.length == 6) {
        _validatePassword();
      }
    }
  }

  void _onDelete() {
    if (_isLoading) return;
    
    if (_password.isNotEmpty) {
      setState(() => _password = _password.substring(0, _password.length - 1));
    }
  }

  Future<void> _validatePassword() async {
    if (_isLoading) return;
    if (!mounted) return;

    print("🔑 LOCK SCREEN: PASSWORD VALIDATION STARTED → [$_password]");
    setState(() => _isLoading = true);

    try {
      final success = await ref.read(authProvider.notifier).unlockWithPassword(_password);
      
      if (!mounted) return;

      if (!success) {
        final error = ref.read(authProvider).error ?? 'Invalid password';
        print("❌ LOCK SCREEN: VALIDATION FAILED → $error");
        setState(() {
          _password = '';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        print("🎉 LOCK SCREEN: VALIDATION SUCCESSFUL");
        setState(() => _isLoading = true);
      }
    } catch (e) {
      print("💥 LOCK SCREEN: CRITICAL ERROR → $e");
      if (!mounted) return;
      setState(() {
        _password = '';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final biometricEnabled = user?.userSettings?.passwordFingerprint ?? false;
    print("🎨 LOCK SCREEN: Rendering with loginBiometricEnabled = $biometricEnabled");

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Header Section
              const CircleAvatar(
                radius: 40,
                backgroundColor: Color(0xFFF5F7FA),
                child: Icon(Icons.lock_outline, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome Back,',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                user?.fullname ?? 'User',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 40),
              
              // 6-Digit Password Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _password.length ? AppColors.primary : Colors.grey[300],
                      border: Border.all(
                        color: index < _password.length ? AppColors.primary : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                  );
                }),
              ),


              const Spacer(),
              
              // Numeric Keypad
              Opacity(
                opacity: _isLoading ? 0.5 : 1.0,
                child: AbsorbPointer(
                  absorbing: _isLoading,
                  child: _buildKeypad(biometricEnabled),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Switch Account Button
              TextButton(
                onPressed: _isLoading ? null : () => ref.read(authProvider.notifier).switchAccount(),
                child: Text(
                  'Switch Account',
                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(bool biometricEnabled) {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3']),
        _buildKeypadRow(['4', '5', '6']),
        _buildKeypadRow(['7', '8', '9']),
        _buildKeypadRow([biometricEnabled ? 'biometric' : null, '0', 'delete']),
      ],
    );
  }

  Widget _buildKeypadRow(List<String?> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((key) {
          if (key == null) return const SizedBox(width: 80);
          if (key == 'delete') {
            return _buildKeypadButton(
              icon: Icons.backspace_outlined,
              onTap: _onDelete,
            );
          }
          if (key == 'biometric') {
            return _buildKeypadButton(
              icon: Icons.fingerprint_rounded,
              onTap: _authenticateBiometric,
            );
          }
          return _buildKeypadButton(
            label: key,
            onTap: () => _onNumberPress(key),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKeypadButton({String? label, IconData? icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: icon != null 
          ? Icon(icon, size: 28, color: AppColors.primary)
          : Text(
              label!,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: AppColors.primary),
            ),
      ),
    );
  }
}
