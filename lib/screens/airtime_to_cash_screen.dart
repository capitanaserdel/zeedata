import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';

class AirtimeToCashScreen extends StatefulWidget {
  const AirtimeToCashScreen({super.key});

  @override
  State<AirtimeToCashScreen> createState() => _AirtimeToCashScreenState();
}

class _AirtimeToCashScreenState extends State<AirtimeToCashScreen> {
  String? _selectedNetwork;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  double _receiveAmount = 0.0;
  final double _rate = 0.85; // 85% payout rate

  final List<Map<String, dynamic>> _networks = [
    {'name': 'MTN', 'color': Colors.yellow[700], 'logo': Icons.network_check},
    {'name': 'Airtel', 'color': Colors.red, 'logo': Icons.network_check},
    {'name': 'GLO', 'color': Colors.green, 'logo': Icons.network_check},
    {'name': '9Mobile', 'color': Colors.green[900], 'logo': Icons.network_check},
  ];

  void _calculateReceive(String value) {
    if (value.isEmpty) {
      setState(() => _receiveAmount = 0.0);
      return;
    }
    double amount = double.tryParse(value) ?? 0.0;
    setState(() => _receiveAmount = amount * _rate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Airtime to Cash', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
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
              'Select Network',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _networks.map((net) {
                bool isSelected = _selectedNetwork == net['name'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedNetwork = net['name']),
                  child: Column(
                    children: [
                      Container(
                        height: 65,
                        width: 65,
                        decoration: BoxDecoration(
                          color: isSelected ? net['color'] : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? net['color'] : Colors.grey[200]!,
                            width: 2,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: net['color'].withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]
                              : null,
                        ),
                        child: Icon(
                          net['logo'],
                          color: isSelected ? Colors.white : net['color'],
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        net['name'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? AppColors.textPrimary : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            _buildTextField(
              label: 'Sender Phone Number',
              hint: '08012345678',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              label: 'Airtime Amount',
              hint: '500 - 50,000',
              controller: _amountController,
              keyboardType: TextInputType.number,
              onChanged: _calculateReceive,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('You Send', style: TextStyle(color: Color(0xFF64748B))),
                      Text(
                        '₦${_amountController.text.isEmpty ? "0.00" : _amountController.text}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Service Charge (15%)', style: TextStyle(color: Color(0xFF64748B))),
                      Text(
                        '-₦${(_receiveAmount / _rate * (1 - _rate)).toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('You Receive', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        '₦${_receiveAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {}, // To be implemented
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Convert Airtime', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
