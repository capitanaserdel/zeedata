import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_loader.dart';
import 'transaction_pin_screen.dart';
import 'transaction_success_screen.dart';
import '../models/user_data.dart';

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
  String _meterType = 'PREPAID'; // PREPAID or POSTPAID
  bool _isValidated = false;
  String? _accountName;
  String? _address;
  double? _minAmount;
  bool _isChecking = false;
  bool _isProcessing = false;

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
    if (_selectedProvider == null || _meterController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select provider and enter meter number')),
      );
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
          setState(() {
            _isChecking = false;
            _isValidated = true;
            _accountName = body['Customer_Name'] ?? body['name'] ?? "Verified Customer";
            _address = body['Address'] ?? body['address'];
            // Capture minimum amount if available (checking various possible keys)
            final minAmtRaw = body['Min_Purchase_Amount'] ?? body['MIN_AMOUNT'] ?? body['minimal_amount'] ?? body['min_amount'];
            
            if (minAmtRaw != null && minAmtRaw.toString().isNotEmpty) {
              _minAmount = double.tryParse(minAmtRaw.toString());
            }
            
            // If still null or couldn't parse, default to 1000.0 (Standard for most DisCos)
            _minAmount ??= 1000.0;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isChecking = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.data['responseMessage'] ?? 'Verification failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isChecking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
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
              MaterialPageRoute(
                builder: (context) => TransactionSuccessScreen(transaction: transaction),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.data['responseMessage'] ?? 'Payment failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
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
                  
                  const Text('Select Provider', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  _buildProviderDropdown(),
                  
                  const SizedBox(height: 24),
                  const Text('Meter Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  _buildMeterTypeToggle(),
                  
                  const SizedBox(height: 24),
                  const Text('Meter Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _meterController,
                          keyboardType: TextInputType.number,
                          onChanged: (val) => setState(() => _isValidated = false),
                          decoration: InputDecoration(
                            hintText: 'Enter 11 or 13 digit meter number',
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
                          onPressed: _isChecking ? null : _verifyMeter,
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
                  
                  if (_isValidated && _accountName != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _accountName!,
                                  style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          if (_address != null && _address!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on, color: Color(0xFF10B981), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _address!,
                                    style: const TextStyle(color: Color(0xFF065F46), fontSize: 13, height: 1.4),
                                  ),
                                ),
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
                    hint: '₦ 0.00',
                    keyboardType: TextInputType.number,
                    prefixText: '₦ ',
                  ),
                  if (_isValidated && _minAmount != null && _minAmount! > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text(
                        'Minimum amount: ₦${_minAmount!.toStringAsFixed(0)}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_isValidated && !_isProcessing) ? _handlePayment : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                      ),
                      child: const Text(
                        'Pay Bill',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (authState.isLoading || _isProcessing || _isChecking) 
            Positioned.fill(
              child: CustomLoader(message: _isChecking ? 'Verifying Meter...' : 'Processing Payment...'),
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
        image: DecorationImage(
          image: const AssetImage('assets/images/card_bg.png'), // Use consistent pattern if available
          fit: BoxFit.cover,
          opacity: 0.1,
        ),
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
          hint: const Text('Select DisCo Provider'),
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
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0)),
          ),
          child: Text(
            type,
            style: TextStyle(
              color: isSelected ? AppColors.primary : const Color(0xFF64748B),
              fontWeight: FontWeight.bold,
            ),
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
