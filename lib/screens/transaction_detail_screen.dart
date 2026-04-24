import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_data.dart';
import '../core/theme/app_colors.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Transaction Details', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (transaction.isCredit ? Colors.green : Colors.red).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      transaction.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: transaction.isCredit ? Colors.green : Colors.red,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    transaction.serviceType,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${transaction.isCredit ? "+" : "-"}${currencyFormat.format(transaction.amount)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: transaction.isCredit ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(transaction.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      transaction.status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(transaction.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TRANSACTION INFO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1)),
                  const SizedBox(height: 24),
                  _buildDetailRow('Reference', transaction.reference),
                  _buildDetailRow('Date', dateFormat.format(transaction.createdAt)),
                  _buildDetailRow('Description', transaction.description),
                  if (transaction.metadata != null) ...[
                    const Divider(height: 40),
                    const Text('RAW METADATA / SENDER INFO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1)),
                    const SizedBox(height: 24),
                    ...transaction.metadata!.entries.map((entry) {
                      // Skip internal fields if you want, or show everything
                      if (entry.key == 'source' || entry.key == 'amount_received') return const SizedBox();
                      
                      String value = entry.value.toString();
                      // Handle nested maps/lists if necessary
                      if (entry.value is Map || entry.value is List) {
                        value = entry.value.toString();
                      }

                      return _buildDetailRow(
                        entry.key.replaceAll('_', ' ').toUpperCase(), 
                        value
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'FAILED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
