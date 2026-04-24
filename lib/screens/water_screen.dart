import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_loader.dart';
import 'transaction_pin_screen.dart';

class WaterScreen extends ConsumerStatefulWidget {
  const WaterScreen({super.key});

  @override
  ConsumerState<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends ConsumerState<WaterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _amountController = TextEditingController();
  
  String? _selectedProvider;
  bool _isValidated = false;
  String? _accountName;
  bool _isChecking = false;

  final List<Map<String, String>> _providers = [
    {'name': 'Lagos Water Corporation', 'id': 'lagos-water'},
    {'name': 'FCT Water Board', 'id': 'fct-water'},
    {'name': 'Ogun State Water', 'id': 'ogun-water'},
    {'name': 'Kano State Water', 'id': 'kano-water'},
    {'name': 'Rivers State Water', 'id': 'rivers-water'},
  ];

  @override
  void dispose() {
    _accountController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _verifyAccount() async {
    if (_selectedProvider == null || _accountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select provider and enter account number')),
      );
      return;
    }

    setState(() => _isChecking = true);

    // Mock API verification
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() {
        _isChecking = false;
        _isValidated = true;
        _accountName = "SALMA GAMBO (Verified)";
      });
    }
  }

  Future<void> _handlePayment() async {
    if (!_formKey.currentState!.validate() || !_isValidated) return;

    final pinResult = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransactionPinScreen()),
    );

    if (pinResult != null && pinResult is String) {
      _processTransaction(pinResult);
    }
  }

  Future<void> _processTransaction(String pin) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Water bill payment processing...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Water Bill', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w900)),
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
                  _buildBalanceCard(authState),
                  const SizedBox(height: 32),
                  
                  const Text('Select Water Board', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  _buildProviderDropdown(),
                  
                  const SizedBox(height: 24),
                  _buildTextField(
                    label: 'Account Number',
                    controller: _accountController,
                    hint: 'Enter your utility account number',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() => _isValidated = false),
                  ),
                  
                  if (_isValidated && _accountName != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                          const SizedBox(width: 8),
                          Text(_accountName!, style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  _buildTextField(
                    label: 'Amount',
                    controller: _amountController,
                    hint: '₦ 0.00',
                    keyboardType: TextInputType.number,
                    prefixText: '₦ ',
                  ),
                  
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isValidated ? _handlePayment : _verifyAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isChecking 
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _isValidated ? 'Pay Bill' : 'Verify Account',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (authState.isLoading) const CustomLoader(message: 'Processing Payment...'),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(AuthState authState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '₦ ${authState.wallet?.balance.toStringAsFixed(2) ?? "0.00"}',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedProvider,
          hint: const Text('Select Water Utility Provider'),
          isExpanded: true,
          items: _providers.map((p) {
            return DropdownMenuItem<String>(
              value: p['id'],
              child: Text(p['name']!),
            );
          }).toList(),
          onChanged: (val) => setState(() {
            _selectedProvider = val;
            _isValidated = false;
          }),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }
}
