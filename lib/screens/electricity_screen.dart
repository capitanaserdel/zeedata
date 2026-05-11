import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_loader.dart';
import 'transaction_pin_screen.dart';
import 'transaction_success_screen.dart';
import '../models/user_data.dart';
import '../core/utils/keyboard_utils.dart';
import '../widgets/common/insufficient_balance_indicator.dart';
import 'package:intl/intl.dart';
import '../providers/balance_provider.dart';

class ElectricityScreen extends ConsumerStatefulWidget {
  const ElectricityScreen({super.key});

  @override
  ConsumerState<ElectricityScreen> createState() => _ElectricityScreenState();
}

class _ElectricityScreenState extends ConsumerState<ElectricityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _meterController = TextEditingController();
  final _amountController = TextEditingController();
  
  String? _selectedProvider;
  String _meterType = 'PREPAID';
  bool _isValidated = false;
  String? _accountName;
  String? _address;
  double? _minAmount;
  bool _isChecking = false;
  bool _isProcessing = false;
  double _currentAmount = 0;

  final List<Map<String, String>> _providers = [
    {'name': 'Ikeja Electric (IKEDC)', 'id': 'ikeja-electric'},
    {'name': 'Eko Electric (EKEDC)', 'id': 'eko-electric'},
    {'name': 'Abuja Electric (AEDC)', 'id': 'abuja-electric'},
    {'name': 'Kano Electric (KEDCO)', 'id': 'kano-electric'},
    {'name': 'Port Harcourt Electric (PHED)', 'id': 'ph-electric'},
    {'name': 'Jos Electric (JED)', 'id': 'jos-electric'},
    {'name': 'Ibadan Electric (IBEDC)', 'id': 'ibadan-electric'},
    {'name': 'Enugu Electric (EEDC)', 'id': 'enugu-electric'},
    {'name': 'Benin Electric (BEDC)', 'id': 'benin-electric'},
    {'name': 'Kaduna Electric (KAEDCO)', 'id': 'kaduna-electric'},
  ];

  @override
  void dispose() {
    _meterController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _verifyMeter() async {
    KeyboardUtils.hide(context);
    if (_selectedProvider == null || _meterController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select provider and enter meter number'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isChecking = true);

    final api = ref.read(apiServiceProvider);
    try {
      final response = await api.post('/electricity/verify', data: {
        'serviceID': _selectedProvider,
        'billersCode': _meterController.text,
        'type': _meterType.toLowerCase(),
      });

      if (response.data['responseSuccessful']) {
        if (mounted) {
          final body = response.data['responseBody'];
          
          // Check for internal errors like "WrongBillersCode" or "error" message
          if (body != null && (body['error'] != null || body['WrongBillersCode'] == true)) {
            final errorMsg = body['error'] ?? 'Invalid meter number. Please check and try again.';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
            setState(() {
              _isValidated = false;
              _isChecking = false;
            });
            return;
          }

          setState(() {
            _isValidated = true;
            _accountName = body['Customer_Name'] ?? body['name'] ?? "Verified Customer";
            _address = body['Address'] ?? body['address'];
            final minAmtRaw = body['Minimum_Amount'] ?? body['Min_Purchase_Amount'] ?? body['MIN_AMOUNT'] ?? body['min_amount'];
            final parsedMin = minAmtRaw != null ? double.tryParse(minAmtRaw.toString()) : null;
            _minAmount = (parsedMin != null && parsedMin > 0) ? parsedMin : null;
          });
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.data['responseMessage'] ?? 'Verification failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _handlePayment() async {
    KeyboardUtils.hide(context);
    if (!_formKey.currentState!.validate()) return;
    if (!_isValidated) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please verify meter first'), backgroundColor: Colors.orange));
       return;
    }

    final pinResult = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransactionPinScreen()),
    );

    if (pinResult != null && pinResult is String) {
      await _processTransaction(pinResult);
    }
  }

  Future<void> _processTransaction(String pin) async {
    setState(() => _isProcessing = true);
    final api = ref.read(apiServiceProvider);
    
    try {
      final response = await api.post('/electricity/pay', data: {
        'serviceID': _selectedProvider,
        'billersCode': _meterController.text,
        'variation_code': _meterType.toLowerCase(),
        'amount': _amountController.text,
        'phone': ref.read(authProvider).user?.phone ?? '',
        'pin': pin,
      });

      if (response.data['responseSuccessful']) {
        if (mounted) {
          await ref.read(authProvider.notifier).saveStoredPin(pin);
          final transaction = Transaction.fromJson(response.data['responseBody']);
          await ref.read(authProvider.notifier).refreshProfile();
          
          if (mounted) {
            setState(() => _isProcessing = false);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => TransactionSuccessScreen(transaction: transaction)),
            );
          }
        }
      } else {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.data['responseMessage'] ?? 'Payment failed'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
    final balance = authState.wallet?.balance ?? 0;
    final hideBalance = ref.watch(balanceVisibilityProvider);
    final isBalanceLow = _currentAmount > balance;

    return KeyboardDismissOnTap(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Electricity Bill', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w900)),
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
                    _buildBalanceCard(balance, currencyFormat, hideBalance),
                    const SizedBox(height: 32),
                    
                    const Text('Select Provider', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                    const SizedBox(height: 12),
                    _buildProviderDropdown(),
                    
                    const SizedBox(height: 24),
                    const Text('Meter Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                    const SizedBox(height: 12),
                    _buildMeterTypeToggle(),
                    
                    const SizedBox(height: 24),
                    const Text('Meter Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _meterController,
                            keyboardType: TextInputType.number,
                            onChanged: (val) => setState(() => _isValidated = false),
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            decoration: InputDecoration(
                              hintText: 'Enter meter number',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isChecking ? null : _verifyMeter,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            child: const Text('Verify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                    
                    if (_isValidated && _accountName != null)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_accountName!, style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w900, fontSize: 14))),
                              ],
                            ),
                            if (_address != null && _address!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on, color: Color(0xFF10B981), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_address!, style: const TextStyle(color: Color(0xFF065F46), fontSize: 13, height: 1.4))),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
  
                    const SizedBox(height: 24),
                    _buildTextField(
                      label: 'Amount',
                      controller: _amountController,
                      hint: '0.00',
                      keyboardType: TextInputType.number,
                      prefixText: '₦ ',
                      onChanged: (v) => setState(() => _currentAmount = double.tryParse(v) ?? 0),
                    ),
                    if (_isValidated && _minAmount != null && _minAmount! > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Text('Minimum amount: ₦${_minAmount!.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w900)),
                      ),
                    
                    InsufficientBalanceIndicator(amount: _currentAmount, balance: balance),
                    const SizedBox(height: 40),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: (_isValidated && !_isProcessing && !isBalanceLow && _currentAmount > 0) ? _handlePayment : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                        ),
                        child: Text(
                          isBalanceLow ? 'Insufficient Balance' : (_isValidated ? 'Pay ${currencyFormat.format(_currentAmount)}' : 'Verify Meter First'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
            if (authState.isLoading || _isProcessing || _isChecking) 
              CustomLoader(message: _isChecking ? 'Verifying Meter...' : 'Processing Payment...'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBalanceCard(double balance, NumberFormat format, bool hideBalance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
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
            hideBalance ? '₦ ••••••••' : format.format(balance),
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

  Widget _buildProviderDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedProvider,
          hint: const Text('Select DisCo Provider', style: TextStyle(color: Color(0xFF94A3B8))),
          isExpanded: true,
          style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
          items: _providers.map((p) => DropdownMenuItem<String>(value: p['id'], child: Text(p['name']!))).toList(),
          onChanged: (val) => setState(() {
            _selectedProvider = val;
            _isValidated = false;
          }),
        ),
      ),
    );
  }

  Widget _buildMeterTypeToggle() {
    return Row(
      children: [
        _buildToggleItem('PREPAID'),
        const SizedBox(width: 12),
        _buildToggleItem('POSTPAID'),
      ],
    );
  }

  Widget _buildToggleItem(String type) {
    bool isSelected = _meterType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _meterType = type;
          _isValidated = false;
        }),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0), width: 1.5),
          ),
          child: Text(
            type,
            style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.w900),
          ),
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
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          style: const TextStyle(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1)),
          ),
        ),
      ],
    );
  }
}
