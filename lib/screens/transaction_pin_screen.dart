import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_loader.dart';

class TransactionPinScreen extends ConsumerStatefulWidget {
  const TransactionPinScreen({super.key});

  @override
  ConsumerState<TransactionPinScreen> createState() => _TransactionPinScreenState();
}

class _TransactionPinScreenState extends ConsumerState<TransactionPinScreen> {
  String _pin = '';
  bool _isLoading = false;
  bool _isAutoPromptDone = false;

  @override
  void initState() {
    super.initState();
    // Auto-trigger biometrics if enabled for transactions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isEnabled = ref.read(authProvider).user?.userSettings?.pinFingerprint ?? false;
      if (mounted && !_isAutoPromptDone && isEnabled) {
        _authenticateBiometric();
        _isAutoPromptDone = true;
      }
    });
  }

  Future<void> _authenticateBiometric() async {
    if (_isLoading) return;
    
    final auth = LocalAuthentication();
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        if (mounted && _isAutoPromptDone) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometrics not available on this device')),
          );
        }
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to authorize this transaction',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );

      if (mounted && didAuthenticate) {
        final storedPin = await ref.read(authProvider.notifier).getStoredPin();
        if (storedPin != null) {
          Navigator.pop(context, storedPin); 
        } else {
          // PIN missing locally (e.g. fresh login). 
          // We don't pop, we just let them enter it manually.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter your PIN manually this time to enable biometrics.')),
          );
        }
      }
    } catch (e) {
      print("❌ Biometric Error: $e");
    }
  }

  void _onNumberPress(String number) {
    if (_isLoading) return;
    
    if (_pin.length < 4) {
      setState(() => _pin += number);
      if (_pin.length == 4) {
        _validatePin();
      }
    }
  }

  void _onDelete() {
    if (_isLoading) return;
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Future<void> _validatePin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    // Save PIN locally for future biometric authorization
    final biometricEnabled = ref.read(authProvider).user?.userSettings?.pinFingerprint ?? false;
    if (biometricEnabled) {
      await ref.read(authProvider.notifier).saveStoredPin(_pin);
    }

    // Give a slight delay for better UX
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context, _pin); // Return the entered PIN
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final biometricEnabled = authState.user?.userSettings?.pinFingerprint ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Lock Icon Header
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFFF1F5F9),
                  child: Icon(Icons.lock_person_rounded, size: 40, color: Color(0xFF011B60)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Enter PIN',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Authorize this transaction',
                  style: TextStyle(fontSize: 16, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 48),
                
                // 4-Digit PIN Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < _pin.length ? const Color(0xFF011B60) : const Color(0xFFE2E8F0),
                      ),
                    );
                  }),
                ),
                
                const SizedBox(height: 48),
                
                if (_isLoading)
                  const CircularProgressIndicator(color: Color(0xFF011B60)),
  
                const SizedBox(height: 20),
                
                // Numeric Keypad (Reusing LockScreen design)
                _buildKeypad(biometricEnabled),
                
                const SizedBox(height: 40),
              ],
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
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
          ? Icon(icon, size: 28, color: const Color(0xFF011B60))
          : Text(
              label!,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
      ),
    );
  }
}
