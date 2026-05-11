import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_loader.dart';
import 'transaction_pin_screen.dart';
import 'transaction_success_screen.dart';
import '../models/user_data.dart';
import 'package:intl/intl.dart';
import '../core/validators/app_validators.dart';
import '../core/utils/keyboard_utils.dart';
import '../widgets/common/insufficient_balance_indicator.dart';
import '../providers/balance_provider.dart';

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

  double get _selectedAmount {
    if (_selectedVariationCode == null) return 0;
    try {
      final v = _variations.firstWhere((v) => v['variation_code'] == _selectedVariationCode);
      final baseAmount = double.tryParse(v['variation_amount'].toString()) ?? 0;
      final qty = int.tryParse(_quantityController.text) ?? 1;
      return baseAmount * qty;
    } catch (_) {
      return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchVariations();
    _quantityController.addListener(() => setState(() {}));
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
    KeyboardUtils.hide(context);
    
    if (_selectedVariationCode == null || _idController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a variation and enter Profile ID'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isChecking = true);

    final api = ref.read(apiServiceProvider);
    try {
      final response = await api.post('/education/verify', data: {
        'serviceID': widget.service['id'],
        'billersCode': _idController.text.trim(),
        'type': _selectedVariationCode,
      });

      if (response.data['responseSuccessful']) {
        final body = response.data['responseBody'];
        if (body != null && (body['error'] != null || body['WrongBillersCode'] == true)) {
          final errorMsg = body['error'] ?? 'Invalid Profile ID. Please check and try again.';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
          setState(() {
            _isValidated = false;
            _isChecking = false;
          });
          return;
        }

        setState(() {
          _isChecking = false;
          _isValidated = true;
          _customerName = body['Customer_Name'] ?? body['name'];
        });
      } else {
        setState(() => _isChecking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.data['responseMessage'] ?? 'Verification failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handlePayment() async {
    KeyboardUtils.hide(context);
    
    if (!_formKey.currentState!.validate()) return;
    
    // For JAMB, must be validated
    if (widget.service['id'] == 'jamb' && !_isValidated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your Profile ID first'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_selectedVariationCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a variation'), backgroundColor: Colors.orange),
      );
      return;
    }

    final authState = ref.read(authProvider);
    if ((authState.wallet?.balance ?? 0) < _selectedAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance'), backgroundColor: Colors.red),
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
        'phone': _phoneController.text.trim(),
        'billersCode': widget.service['id'] == 'jamb' ? _idController.text.trim() : null,
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
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.data['responseMessage'] ?? 'Payment failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isJamb = widget.service['id'] == 'jamb';
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
    final hideBalance = ref.watch(balanceVisibilityProvider);

    return KeyboardDismissOnTap(
      child: Scaffold(
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
            Positioned.fill(
              child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceCard(authState, currencyFormat, hideBalance),
                    const SizedBox(height: 12),
                    
                    InsufficientBalanceIndicator(
                      balance: authState.wallet?.balance ?? 0,
                      amount: _selectedAmount,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    _buildSectionHeader('Select Package'),
                    const SizedBox(height: 12),
                    _buildVariationDropdown(),
                    
                    if (isJamb) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader('Profile ID'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _idController,
                              keyboardType: TextInputType.number,
                              onChanged: (val) => setState(() => _isValidated = false),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              decoration: _inputDecoration('Enter JAMB Profile ID'),
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
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
                                disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
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
                              Expanded(child: Text(_customerName!, style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 13))),
                            ],
                          ),
                        ),
                    ],
  
                    const SizedBox(height: 24),
                    _buildSectionHeader('Recipient Phone'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      decoration: _inputDecoration('Enter phone number'),
                      validator: AppValidators.validatePhone,
                    ),
  
                    if (!isJamb) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader('Quantity'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        decoration: _inputDecoration('Number of PINs'),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          final q = int.tryParse(val);
                          if (q == null || q < 1) return 'Min 1';
                          if (q > 10) return 'Max 10';
                          return null;
                        },
                      ),
                    ],
  
                    const SizedBox(height: 40),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: (_isProcessing || _isChecking || _isLoadingVariations) ? null : _handlePayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                        ),
                        child: Text(
                          _isProcessing ? 'Processing...' : 'Purchase ${widget.service['id'].toUpperCase()}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
            if (_isLoadingVariations || _isProcessing || _isChecking) 
              CustomLoader(message: _isLoadingVariations ? 'Loading variations...' : (_isChecking ? 'Verifying...' : 'Processing...')),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent)),
    );
  }

  Widget _buildBalanceCard(AuthState authState, NumberFormat format, bool hideBalance) {
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
          Row(
            children: [
              const Text('Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => ref.read(balanceVisibilityProvider.notifier).toggle(),
                child: Icon(
                  hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hideBalance ? '₦ ••••••••' : format.format(authState.wallet?.balance ?? 0),
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: hideBalance ? 2 : -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariationDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedVariationCode,
          hint: const Text('Select Option', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
          items: _variations.map((v) {
            return DropdownMenuItem<String>(
              value: v['variation_code'],
              child: Text("${v['name']} - ₦${v['variation_amount']}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
