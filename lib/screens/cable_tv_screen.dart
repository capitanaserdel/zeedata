import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_colors.dart';
import '../widgets/custom_loader.dart';
import 'transaction_pin_screen.dart';
import 'package:intl/intl.dart';

class CableTVScreen extends ConsumerStatefulWidget {
  const CableTVScreen({super.key});

  @override
  ConsumerState<CableTVScreen> createState() => _CableTVScreenState();
}

class _CableTVScreenState extends ConsumerState<CableTVScreen> {
  final _formKey = GlobalKey<FormState>();
  final _smartcardController = TextEditingController();
  
  String? _selectedProvider;
  Map<String, dynamic>? _selectedPlan;
  List<dynamic> _plans = [];
  bool _isLoadingPlans = false;
  bool _isValidated = false;
  String? _accountName;
  bool _isVerifying = false;

  final List<Map<String, String>> _providers = [
    {'name': 'DSTV', 'id': 'dstv'},
    {'name': 'GOTV', 'id': 'gotv'},
    {'name': 'Startimes', 'id': 'startimes'},
  ];

  @override
  void dispose() {
    _smartcardController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlans(String providerId) async {
    setState(() {
      _isLoadingPlans = true;
      _plans = [];
      _selectedPlan = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/cable/plans', queryParameters: {'cablename': providerId.toUpperCase()});
      
      if (response.data['responseSuccessful']) {
        setState(() {
          _plans = response.data['responseBody'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch plans: $e')),
      );
    } finally {
      setState(() => _isLoadingPlans = false);
    }
  }

  Future<void> _verifySmartcard() async {
    if (_selectedProvider == null || _smartcardController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select provider and enter smartcard number')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post('/cable/validate', data: {
        'cablename': _selectedProvider!.toUpperCase(),
        'smartcard': _smartcardController.text.trim(),
      });

      if (response.data['responseSuccessful']) {
        final data = response.data['responseBody'];
        setState(() {
          _isValidated = true;
          _accountName = data['name'] ?? data['customer_name'] ?? 'Account Verified';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.data['responseMessage'] ?? 'Validation failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification error: $e')),
      );
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _handlePayment() async {
    if (!_formKey.currentState!.validate() || !_isValidated || _selectedPlan == null) return;

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
      final response = await api.post('/cable/purchase', data: {
        'cablename': _selectedProvider!.toUpperCase(),
        'cableplan': _selectedPlan!['plan_code'] ?? _selectedPlan!['id'],
        'smartcard': _smartcardController.text.trim(),
        'amount': _selectedPlan!['amount'],
        'pin': pin,
      });

      if (response.data['responseSuccessful']) {
        if (mounted) {
          await ref.read(authProvider.notifier).saveStoredPin(pin);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cable TV subscription successful!'), backgroundColor: Colors.green),
          );
          await ref.read(authProvider.notifier).refreshProfile();
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.data['responseMessage'] ?? 'Transaction failed')),
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
        title: const Text('Cable TV', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w900)),
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
                  // Balance Card
                  _buildBalanceCard(authState, currencyFormat),
                  const SizedBox(height: 32),
                  
                  const Text('Select Provider', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  _buildProviderDropdown(),
                  
                  const SizedBox(height: 24),
                  const Text('Select Plan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  _buildPlanDropdown(),
                  
                  const SizedBox(height: 24),
                  _buildTextField(
                    label: 'Smartcard / IUC Number',
                    controller: _smartcardController,
                    hint: 'Enter IUC or Smartcard number',
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
                          Expanded(
                            child: Text(_accountName!, style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isValidated ? _handlePayment : _verifySmartcard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isVerifying 
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _isValidated ? 'Pay ${_selectedPlan != null ? currencyFormat.format(_selectedPlan!['amount']) : ''}' : 'Verify Smartcard',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (authState.isLoading) const CustomLoader(message: 'Processing Transaction...'),
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
          hint: const Text('Select Cable Provider'),
          isExpanded: true,
          items: _providers.map((p) {
            return DropdownMenuItem<String>(
              value: p['id'],
              child: Text(p['name']!),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedProvider = val;
                _isValidated = false;
              });
              _fetchPlans(val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildPlanDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: _selectedPlan,
          hint: Text(_isLoadingPlans ? 'Loading plans...' : 'Select Package'),
          isExpanded: true,
          items: _plans.map((p) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: Map<String, dynamic>.from(p),
              child: Text("${p['name']} - ₦${p['amount']}"),
            );
          }).toList(),
          onChanged: _isLoadingPlans ? null : (val) => setState(() {
            _selectedPlan = val;
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
          style: const TextStyle(fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.primary, width: 2)),
          ),
          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }
}
