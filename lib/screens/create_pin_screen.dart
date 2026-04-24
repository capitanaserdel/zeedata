import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_loader.dart';

class CreatePinScreen extends ConsumerStatefulWidget {
  const CreatePinScreen({super.key});

  @override
  ConsumerState<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends ConsumerState<CreatePinScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;

  void _onNumberPress(String number) {
    if (!_isConfirming) {
      if (_pin.length < 4) {
        setState(() => _pin += number);
        if (_pin.length == 4) {
          setState(() => _isConfirming = true);
        }
      }
    } else {
      if (_confirmPin.length < 4) {
        setState(() => _confirmPin += number);
        if (_confirmPin.length == 4) {
          _handleSetPin();
        }
      }
    }
  }

  void _onDelete() {
    if (!_isConfirming) {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    } else {
      if (_confirmPin.isNotEmpty) {
        setState(() => _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1));
      } else {
        setState(() => _isConfirming = false);
      }
    }
  }

  Future<void> _handleSetPin() async {
    if (_pin != _confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match. Try again.')),
      );
      setState(() {
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
      return;
    }

    final success = await ref.read(authProvider.notifier).setPin(_pin);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction PIN created successfully!')),
      );
      // Main navigation logic will handle redirection since hasPin is now true
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFFF1F5F9),
                    child: Icon(Icons.security_rounded, size: 40, color: Color(0xFF011B60)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isConfirming ? 'Confirm PIN' : 'Create Transaction PIN',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose a secure 4-digit PIN for your transactions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 48),
                  
                  // PIN Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      String current = _isConfirming ? _confirmPin : _pin;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < current.length ? const Color(0xFF011B60) : const Color(0xFFE2E8F0),
                        ),
                      );
                    }),
                  ),
                  
                  const Spacer(),
                  _buildKeypad(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (authState.isLoading) const CustomLoader(message: 'Securing your account...'),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3']),
        _buildKeypadRow(['4', '5', '6']),
        _buildKeypadRow(['7', '8', '9']),
        _buildKeypadRow([null, '0', 'delete']),
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
