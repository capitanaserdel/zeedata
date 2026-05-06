import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_loader.dart';
import 'transaction_pin_screen.dart';
import 'transaction_success_screen.dart';
import '../models/user_data.dart';

class EducationPaymentScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> service;

  const EducationPaymentScreen({super.key, required this.service});

  @override
  ConsumerState<EducationPaymentScreen> createState() => _EducationPaymentScreenState();
}

class _EducationPaymentScreenState extends ConsumerState<EducationPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController(); // For JAMB Profile ID
  final _phoneController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  
  List<dynamic> _variations = [];
  String? _selectedVariationCode;
  bool _isLoadingVariations = true;
  bool _isValidated = false;
  String? _customerName;
  bool _isChecking = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchVariations();
  }

  @override
  void dispose() {
    _idController.dispose();
    _phoneController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _fetchVariations() async {
    final api = ref.read(apiServiceProvider);
    try {
      final response = await api.get('/vtu/variations', queryParameters: {'serviceID': widget.service['id']});
      if (response.data['responseSuccessful']) {
        setState(() {
          _variations = response.data['responseBody'];
          _isLoadingVariations = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingVariations = false);
    }
  }

  Future<void> _verifyProfile() async {
    if (_selectedVariationCode == null || _idController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a variation and enter Profile ID')),
      );
      return;
    }

    setState(() => _isChecking = true);

    final api = ref.read(apiServiceProvider);
    try {
      final response = await api.post('/education/verify', data: {
        'serviceID': widget.service['id'],
        'billersCode': _idController.text,
        'type': _selectedVariationCode,
      });

      if (response.data['responseSuccessful']) {
        setState(() {
          _isChecking = false;
          _isValidated = true;
          _customerName = response.data['responseBody']['Customer_Name'];
        });
      } else {
        setState(() => _isChecking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.data['responseMessage'] ?? 'Verification failed')),
        );
      }
    } catch (e) {
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _handlePayment() async {
    if (!_formKey.currentState!.validate()) return;
    
    // For JAMB, must be validated
    if (widget.service['id'] == 'jamb' && !_isValidated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your Profile ID first')),
      );
      return;
    }

    if (_selectedVariationCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a variation')),
      );
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
    setState(() => _isProcessing = true);
    final api = ref.read(apiServiceProvider);
    
    final selectedVariation = _variations.firstWhere((v) => v['variation_code'] == _selectedVariationCode);
    
    try {
      final response = await api.post('/education/pay', data: {
        'serviceID': widget.service['id'],
        'variation_code': _selectedVariationCode,
        'amount': selectedVariation['variation_amount'],
        'phone': _phoneController.text,
        'billersCode': widget.service['id'] == 'jamb' ? _idController.text : null,
        'quantity': int.tryParse(_quantityController.text) ?? 1,
        'pin': pin,
      });

      if (response.data['responseSuccessful']) {
        await ref.read(authProvider.notifier).saveStoredPin(pin);
        final transaction = Transaction.fromJson(response.data['responseBody']);
        await ref.read(authProvider.notifier).refreshProfile();
        
        if (mounted) {
          setState(() => _isProcessing = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionSuccessScreen(transaction: transaction),
            ),
          );
        }
      } else {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.data['responseMessage'] ?? 'Payment failed')),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isJamb = widget.service['id'] == 'jamb';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.service['name'], style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w900)),
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
                  // Wallet Balance Card
                  _buildBalanceCard(authState),
                  const SizedBox(height: 32),
                  
                  const Text('Select Package', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  _buildVariationDropdown(),
                  
                  if (isJamb) ...[
                    const SizedBox(height: 24),
                    const Text('Profile ID', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _idController,
                            keyboardType: TextInputType.number,
                            onChanged: (val) => setState(() => _isValidated = false),
                            decoration: InputDecoration(
                              hintText: 'Enter JAMB Profile ID',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isChecking ? null : _verifyProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: const Text('Verify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    if (_isValidated && _customerName != null)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                            const SizedBox(width: 8),
                            Text(_customerName!, style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                  ],

                  const SizedBox(height: 24),
                  const Text('Recipient Phone', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Enter phone number',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),

                  if (!isJamb) ...[
                    const SizedBox(height: 24),
                    const Text('Quantity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Number of PINs',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_isProcessing) ? null : _handlePayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Purchase ${widget.service['id'].toUpperCase()}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoadingVariations || _isProcessing || _isChecking) 
            Positioned.fill(
              child: CustomLoader(message: _isLoadingVariations ? 'Loading variations...' : (_isChecking ? 'Verifying...' : 'Processing Payment...')),
            ),
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

  Widget _buildVariationDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedVariationCode,
          hint: const Text('Select Option'),
          isExpanded: true,
          items: _variations.map((v) {
            return DropdownMenuItem<String>(
              value: v['variation_code'],
              child: Text("${v['name']} - ₦${v['variation_amount']}"),
            );
          }).toList(),
          onChanged: (val) => setState(() {
            _selectedVariationCode = val;
            _isValidated = false;
          }),
        ),
      ),
    );
  }
}
