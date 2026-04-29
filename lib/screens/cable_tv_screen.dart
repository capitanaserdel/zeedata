import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_colors.dart';
import '../widgets/custom_loader.dart';
import 'transaction_pin_screen.dart';
import 'transaction_success_screen.dart';
import '../models/user_data.dart';
import 'package:intl/intl.dart';

class CableTVScreen extends ConsumerStatefulWidget {
  const CableTVScreen({super.key});

  @override
  ConsumerState<CableTVScreen> createState() => _CableTVScreenState();
}

class _CableTVScreenState extends ConsumerState<CableTVScreen> {
  final _formKey = GlobalKey<FormState>();
  final _smartcardController = TextEditingController();
  
  String? _selectedProvider = 'dstv';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPlans('dstv');
    });
  }
  Map<String, dynamic>? _selectedPlan;
  List<dynamic> _plans = [];
  bool _isLoadingPlans = false;
  bool _isValidated = false;
  String? _accountName;
  bool _isVerifying = false;
  bool _isProcessing = false;

  final List<Map<String, String>> _providers = [
    {'name': 'DSTV', 'id': 'dstv'},
    {'name': 'GOTV', 'id': 'gotv'},
    {'name': 'Startimes', 'id': 'startimes'},
    {'name': 'Showmax', 'id': 'showmax'},
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
      final response = await api.get('/vtu/variations', queryParameters: {'serviceID': providerId.toLowerCase()});
      
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
        'serviceID': _selectedProvider!.toLowerCase(),
        'billersCode': _smartcardController.text.trim(),
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
    if (_selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a package')));
      return;
    }
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
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post('/cable/purchase', data: {
        'serviceID': _selectedProvider!.toLowerCase(),
        'variation_code': _selectedPlan!['variation_code'] ?? _selectedPlan!['id'],
        'billersCode': _smartcardController.text.trim(),
        'amount': _selectedPlan!['variation_amount'] ?? _selectedPlan!['amount'],
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
            SnackBar(content: Text(response.data['responseMessage'] ?? 'Transaction failed')),
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
                  if (_selectedProvider != null) ...[
                    const Text(
                      'Choose Package',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_isLoadingPlans)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(color: Color(0xFF011B60)),
                      ))
                    else if (_plans.isEmpty)
                      const Center(child: Text('No packages available.'))
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.3,
                        ),
                        itemCount: _plans.length,
                        itemBuilder: (context, index) {
                          final plan = _plans[index];
                          final isSelected = _selectedPlan == plan;
                          
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedPlan = plan;
                              _isValidated = false;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF011B60) : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF011B60) : const Color(0xFFE2E8F0),
                                  width: 2,
                                ),
                                boxShadow: isSelected ? [
                                  BoxShadow(color: const Color(0xFF011B60).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                                ] : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    plan['name'].toString(),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white.withOpacity(0.2) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "₦${plan['variation_amount']}",
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : const Color(0xFF011B60),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                  
                  const SizedBox(height: 24),
                  _buildTextField(
                    label: 'Smartcard / IUC Number',
                    controller: _smartcardController,
                    hint: 'Enter IUC or Smartcard number',
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      setState(() => _isValidated = false);
                      if (val.length == 10 && !_isVerifying) {
                        _verifySmartcard();
                      }
                    },
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
                      child: Text(
                            _isValidated 
                                ? 'Pay ${_selectedPlan != null ? currencyFormat.format(double.tryParse(_selectedPlan!['variation_amount']?.toString() ?? _selectedPlan!['amount']?.toString() ?? '0') ?? 0) : ''}' 
                                : 'Verify Smartcard',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (authState.isLoading || _isProcessing || _isVerifying) 
            CustomLoader(message: _isVerifying ? 'Verifying Smartcard...' : 'Processing Transaction...'),
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
