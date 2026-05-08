import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_colors.dart';
import '../widgets/custom_loader.dart';
import 'transaction_pin_screen.dart';
import 'package:intl/intl.dart';

class BulkSMSScreen extends ConsumerStatefulWidget {
  const BulkSMSScreen({super.key});

  @override
  ConsumerState<BulkSMSScreen> createState() => _BulkSMSScreenState();
}

class _BulkSMSScreenState extends ConsumerState<BulkSMSScreen> {
  final _formKey = GlobalKey<FormState>();
  final _senderController = TextEditingController();
  final _recipientsController = TextEditingController();
  final _messageController = TextEditingController();
  
  int _charCount = 0;
  int _pages = 1;
  int _recipientCount = 0;
  double _totalCost = 0.0;
  final double _ratePerPage = 5.0;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_updateSummary);
    _recipientsController.addListener(_updateSummary);
  }

  @override
  void dispose() {
    _senderController.dispose();
    _recipientsController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _updateSummary() {
    final message = _messageController.text;
    final recipients = _recipientsController.text;
    
    setState(() {
      _charCount = message.length;
      
      // Simple Unicode detection: if any character code is > 127
      bool isUnicode = message.runes.any((r) => r > 127);
      int charsPerPage = isUnicode ? 70 : 160;
      
      _pages = (_charCount / charsPerPage).ceil();
      if (_pages == 0) _pages = 1;
      
      // Count unique recipients (comma or newline separated)
      final list = recipients.split(RegExp(r'[,\n\r]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet() // Use Set for unique count
          .toList();
      _recipientCount = list.length;
      
      _totalCost = _recipientCount * _pages * _ratePerPage;
    });
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) return;
    if (_recipientCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one recipient')));
      return;
    }

    final pinResult = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransactionPinScreen()),
    );

    if (pinResult != null && pinResult is String) {
      _processTransaction(pinResult);
    }
  }

  Future<void> _processTransaction(String pin) async {
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post('/sms/send', data: {
        'sender_id': _senderController.text.trim(),
        'recipients': _recipientsController.text.trim(),
        'message': _messageController.text,
        'pin': pin,
      });

      if (response.data['responseSuccessful']) {
        if (mounted) {
          await ref.read(authProvider.notifier).saveStoredPin(pin);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bulk SMS sent successfully!'), backgroundColor: Colors.green),
          );
          await ref.read(authProvider.notifier).refreshProfile();
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.data['responseMessage'] ?? 'Failed to send SMS')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Bulk SMS', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceCard(authState, currencyFormat),
                  const SizedBox(height: 32),
                  
                  _buildTextField(
                    label: 'Sender ID',
                    controller: _senderController,
                    hint: 'e.g., ZEEDATA',
                    maxLength: 11,
                    validator: (v) => v!.isEmpty ? 'Sender ID is required' : (v.length > 11 ? 'Max 11 characters' : null),
                  ),
                  
                  const SizedBox(height: 24),
                  _buildTextField(
                    label: 'Recipients',
                    controller: _recipientsController,
                    hint: 'Enter numbers separated by comma or newline',
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    validator: (v) => v!.isEmpty ? 'At least one recipient is required' : null,
                  ),
                  
                  const SizedBox(height: 24),
                  _buildTextField(
                    label: 'Message',
                    controller: _messageController,
                    hint: 'Type your message here...',
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    validator: (v) => v!.isEmpty ? 'Message cannot be empty' : null,
                  ),
                  
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$_charCount characters | $_pages page(s)', style: TextStyle(fontSize: 12, color: Colors.blueGrey[600], fontWeight: FontWeight.w600)),
                      Text('₦$_ratePerPage per page', style: TextStyle(fontSize: 12, color: Colors.blueGrey[400])),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow('Total Recipients', '$_recipientCount'),
                        const Divider(height: 24),
                        _buildSummaryRow('Total Cost', currencyFormat.format(_totalCost), isTotal: true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _handleSend,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Send Bulk SMS',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (authState.isLoading) const CustomLoader(message: 'Processing...'),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(AuthState authState, NumberFormat format) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            format.format(authState.wallet?.balance ?? 0),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int? maxLines = 1,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            counterText: "",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: isTotal ? AppColors.textPrimary : const Color(0xFF64748B), fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600)),
        Text(value, style: TextStyle(fontSize: isTotal ? 18 : 14, color: isTotal ? AppColors.primary : AppColors.textPrimary, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
