import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_data.dart';

class TransactionSuccessScreen extends StatelessWidget {
  final Transaction transaction;

  const TransactionSuccessScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              
              // Success Animation / Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF4CAF50),
                  size: 80,
                ),
              ),
              
              const SizedBox(height: 32),
              
              const Text(
                'Transaction Successful',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Your ${transaction.serviceType.toLowerCase()} purchase was completed successfully.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Summary Box
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Amount', currencyFormat.format(transaction.amount), isAmount: true),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: Color(0xFFE2E8F0)),
                    ),
                    _buildSummaryRow('Service', transaction.serviceType),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Reference', transaction.reference),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Date', dateFormat.format(transaction.createdAt)),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Action Buttons
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // Navigator.popUntil(context, (route) => route.isFirst);
                      // Or just go back to main screen
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF011B60),
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      // Logic to share or download receipt
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.share_rounded, size: 20, color: Color(0xFF011B60)),
                        SizedBox(width: 8),
                        Text(
                          'Share Receipt',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF011B60),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isAmount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isAmount ? 20 : 14,
            fontWeight: isAmount ? FontWeight.w900 : FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
