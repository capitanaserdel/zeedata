import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_loader.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String fullname;
  final String email;
  final String password;
  final String? referralCode;

  const EmailVerificationScreen({
    super.key,
    required this.fullname,
    required this.email,
    required this.password,
    this.referralCode,
  });

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  final _otpController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Decor
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF011B60).withOpacity(0.03),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF011B60)),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Verify Email',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      text: 'We sent a 6-digit verification code to ',
                      style: const TextStyle(fontSize: 16, color: Color(0xFF64748B), height: 1.5),
                      children: [
                        TextSpan(
                          text: widget.email,
                          style: const TextStyle(color: Color(0xFF011B60), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.w900, 
                      letterSpacing: 12,
                      color: Color(0xFF011B60)
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: TextStyle(color: const Color(0xFF94A3B8).withOpacity(0.3)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 24),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  if (authState.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        authState.error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _handleVerifyAndRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF011B60),
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Verify & Register',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  Center(
                    child: TextButton(
                      onPressed: () => ref.read(authProvider.notifier).sendRegistrationOtp(widget.email),
                      child: const Text(
                        'Didn\'t receive code? Resend',
                        style: TextStyle(
                          color: Color(0xFF011B60),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (authState.isLoading) const CustomLoader(message: 'Creating account...'),
        ],
      ),
    );
  }

  Future<void> _handleVerifyAndRegister() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP'))
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).register(
      fullname: widget.fullname,
      email: widget.email,
      password: widget.password,
      otp: _otpController.text.trim(),
      referralCode: widget.referralCode,
    );
    
    if (success && mounted) {
      // Auth state change in main.dart handles navigation to home
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}
