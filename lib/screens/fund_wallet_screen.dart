import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_colors.dart';

class FundWalletScreen extends ConsumerWidget {
  const FundWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final va = authState.user?.virtualAccount;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Fund Wallet', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bank Transfer',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fund your wallet instantly by making a transfer to your dedicated virtual account.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 32),
            if (va == null || va.accountNumber == null)
              _buildEmptyState()
            else
              _buildAccountCard(context, va),
            const SizedBox(height: 40),
            _buildInstructions(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.account_balance_rounded, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 16),
          const Text(
            'No Account Generated',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your virtual account is being generated. Please check back shortly.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, dynamic va) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF041f62),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF041f62).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('VIRTUAL ACCOUNT', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              Image.network(
                'https://cdn.iconscout.com/icon/free/png-256/free-bank-144-432506.png', // Generic bank icon
                height: 24,
                color: Colors.white24,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow(context, 'Bank Name', va.bankName ?? 'PALMPAY', Colors.white),
          const SizedBox(height: 20),
          _buildInfoRow(context, 'Account Number', va.accountNumber ?? '', Colors.white, isAccountNumber: true),
          const SizedBox(height: 20),
          _buildInfoRow(context, 'Account Name', va.accountName ?? '', Colors.white),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, Color textColor, {bool isAccountNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: textColor,
                  fontSize: isAccountNumber ? 24 : 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: isAccountNumber ? 1 : 0,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              icon: Icon(Icons.copy_rounded, color: textColor.withOpacity(0.5), size: 20),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HOW IT WORKS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.5),
        ),
        const SizedBox(height: 20),
        _buildStep(1, 'Copy your account number above.'),
        _buildStep(2, 'Open your mobile banking app or use USSD.'),
        _buildStep(3, 'Make a transfer to the account provided.'),
        _buildStep(4, 'Your ZeeData wallet will be credited automatically in seconds.'),
      ],
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: Text(
              '$number',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF041f62)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF475569), fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
