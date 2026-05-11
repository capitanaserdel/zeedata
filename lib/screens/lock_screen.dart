import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_loader.dart';
import 'forgot_password_screen.dart';

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
    
    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).unlockWithBiometrics();
    
    if (!mounted) return;

    if (!success) {
      final error = ref.read(authProvider).error ?? 'Biometric authentication failed';
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    // If success, state change in main.dart handles navigation
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

    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 700;
    
    final double buttonSize = (size.width * 0.2).clamp(60.0, 80.0);
    final double verticalPadding = isSmallScreen ? 4.0 : 8.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Spacer(flex: isSmallScreen ? 1 : 2),
                  // Header Section
                  CircleAvatar(
                    radius: isSmallScreen ? 30 : 40,
                    backgroundColor: const Color(0xFFF5F7FA),
                    child: Icon(Icons.lock_outline, size: isSmallScreen ? 30 : 40, color: AppColors.primary),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 24),
                  Text(
                    'Welcome Back,',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: isSmallScreen ? 16 : 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.fullname.split(' ').first ?? 'User',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: isSmallScreen ? 20 : 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  Spacer(flex: isSmallScreen ? 1 : 2),
                  
                  // 6-Digit Password Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 6 : 10),
                        width: isSmallScreen ? 12 : 14,
                        height: isSmallScreen ? 12 : 14,
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

                  Spacer(flex: isSmallScreen ? 2 : 3),
                  
                  // Numeric Keypad
                  Opacity(
                    opacity: _isLoading ? 0.5 : 1.0,
                    child: AbsorbPointer(
                      absorbing: _isLoading,
                      child: _buildKeypad(biometricEnabled, buttonSize, verticalPadding),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                        );
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Color(0xFF011B60),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 24),
                  
                  // Switch Account Button
                  TextButton(
                    onPressed: _isLoading ? null : () => ref.read(authProvider.notifier).switchAccount(),
                    child: Text(
                      'Switch Account',
                      style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 10 : 20),
                ],
              ),
            ),
          ),
          if (_isLoading) const CustomLoader(message: 'Logging you in...'),
        ],
      ),
    );
  }

  Widget _buildKeypad(bool biometricEnabled, double buttonSize, double verticalPadding) {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3'], buttonSize, verticalPadding),
        _buildKeypadRow(['4', '5', '6'], buttonSize, verticalPadding),
        _buildKeypadRow(['7', '8', '9'], buttonSize, verticalPadding),
        _buildKeypadRow([biometricEnabled ? 'biometric' : null, '0', 'delete'], buttonSize, verticalPadding),
      ],
    );
  }

  Widget _buildKeypadRow(List<String?> keys, double buttonSize, double verticalPadding) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((key) {
          if (key == null) return SizedBox(width: buttonSize);
          if (key == 'delete') {
            return _buildKeypadButton(
              icon: Icons.backspace_outlined,
              buttonSize: buttonSize,
              onTap: _onDelete,
            );
          }
          if (key == 'biometric') {
            return _buildKeypadButton(
              icon: Icons.fingerprint_rounded,
              buttonSize: buttonSize,
              onTap: _authenticateBiometric,
            );
          }
          return _buildKeypadButton(
            label: key,
            buttonSize: buttonSize,
            onTap: () => _onNumberPress(key),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKeypadButton({String? label, IconData? icon, required double buttonSize, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(buttonSize / 2),
      child: Container(
        width: buttonSize,
        height: buttonSize,
        alignment: Alignment.center,
        child: icon != null 
          ? Icon(icon, size: buttonSize * 0.35, color: AppColors.primary)
          : Text(
              label!,
              style: TextStyle(fontSize: buttonSize * 0.35, fontWeight: FontWeight.w500, color: AppColors.primary),
            ),
      ),
    );
  }
}
