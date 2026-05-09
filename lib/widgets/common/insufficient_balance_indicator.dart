import 'package:flutter/material.dart';

class InsufficientBalanceIndicator extends StatelessWidget {
  final double amount;
  final double balance;
  final bool visible;

  const InsufficientBalanceIndicator({
    super.key,
    required this.amount,
    required this.balance,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || amount <= balance) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Insufficient balance. Your current balance is ₦${balance.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
