import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_colors.dart';
import '../widgets/custom_loader.dart';
import 'transaction_pin_screen.dart';
import 'transaction_success_screen.dart';
import '../models/user_data.dart';
import '../core/utils/keyboard_utils.dart';
import '../widgets/common/insufficient_balance_indicator.dart';
import 'package:intl/intl.dart';
import '../providers/balance_provider.dart';

class CableTVScreen extends ConsumerStatefulWidget {
  const CableTVScreen({super.key});

  @override
  ConsumerState<CableTVScreen> createState() => _CableTVScreenState();
}

class _CableTVScreenState extends ConsumerState<CableTVScreen> {
  final _formKey = GlobalKey<FormState>();
  final _smartcardController = TextEditingController();
  
  String? _selectedProvider = 'dstv';
  Map<String, dynamic>? _selectedPlan;
  List<dynamic> _plans = [];
  bool _isLoadingPlans = false;
  bool _isValidated = false;
  String? _accountName;
  bool _isVerifying = false;
  bool _isProcessing = false;
  double _currentPrice = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPlans('dstv');
    });
  }

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
      _currentPrice = 0;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch plans: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingPlans = false);
    }
  }

  Future<void> _verifySmartcard() async {
    KeyboardUtils.hide(context);
    if (_selectedProvider == null || _smartcardController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select provider and enter smartcard number'), backgroundColor: Colors.orange));
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
        
        // Check for internal errors like "WrongBillersCode" or "error" message
        if (data != null && (data['error'] != null || data['WrongBillersCode'] == true)) {
          final errorMsg = data['error'] ?? 'Invalid smartcard number. Please check and try again.';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
          setState(() {
            _isValidated = false;
            _isVerifying = false;
          });
          return;
        }

        setState(() {
          _isValidated = true;
          _accountName = data['Customer_Name'] ?? data['customer_name'] ?? data['name'] ?? 'Verified Customer';
        });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.data['responseMessage'] ?? 'Validation failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _handlePayment() async {
    KeyboardUtils.hide(context);
    if (_selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a package'), backgroundColor: Colors.orange));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (!_isValidated) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please verify smartcard first'), backgroundColor: Colors.orange));
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
            SnackBar(content: Text(response.data['responseMessage'] ?? 'Transaction failed'), backgroundColor: Colors.red),
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
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
    final balance = authState.wallet?.balance ?? 0;
    final hideBalance = ref.watch(balanceVisibilityProvider);
    final isBalanceLow = _currentPrice > balance;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return KeyboardDismissOnTap(
      child: Scaffold(
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
            Positioned.fill(
              child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? size.width * 0.2 : 24.0,
                vertical: 24,
              ),
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
                    const Text('Smartcard / IUC Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _smartcardController,
                            keyboardType: TextInputType.number,
                            onChanged: (val) => setState(() => _isValidated = false),
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            decoration: InputDecoration(
                              hintText: 'Enter IUC or Smartcard',
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
                            onPressed: _isVerifying ? null : _verifySmartcard,
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2))),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_accountName!, style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w900, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
  
                    const SizedBox(height: 32),
  
                    if (_selectedProvider != null) ...[
                      const Text('Choose Package', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                      const SizedBox(height: 12),
                      
                      if (_isLoadingPlans)
                        const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: AppColors.primary)))
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
                            final price = double.tryParse(plan['variation_amount']?.toString() ?? plan['amount']?.toString() ?? '0') ?? 0;
                            final planIsBalanceLow = price > balance;
                            
                            return GestureDetector(
                              onTap: () => setState(() {
                                _selectedPlan = plan;
                                _currentPrice = price;
                              }),
                              child: Stack(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0), width: 2),
                                      boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))] : [],
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
                                            color: planIsBalanceLow 
                                                ? Colors.red.withOpacity(isSelected ? 0.3 : 0.1)
                                                : (isSelected ? Colors.white.withOpacity(0.2) : const Color(0xFFF1F5F9)),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            "₦${plan['variation_amount']}",
                                            style: TextStyle(
                                              color: planIsBalanceLow 
                                                  ? (isSelected ? Colors.white : Colors.red)
                                                  : (isSelected ? Colors.white : AppColors.primary),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (plan['is_featured'] == true)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Featured',
                                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                        ),
                                      ),
                                    )
                                  else if (plan['is_recommended'] == true)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B82F6),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Popular',
                                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                    
                    InsufficientBalanceIndicator(amount: _currentPrice, balance: balance),
                    const SizedBox(height: 40),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: (_isValidated && !_isProcessing && !isBalanceLow && _selectedPlan != null) ? _handlePayment : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                        ),
                        child: Text(
                          isBalanceLow ? 'Insufficient Balance' : (_isValidated ? 'Pay ${currencyFormat.format(_currentPrice)}' : 'Verify Account First'),
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
            if (authState.isLoading || _isProcessing || _isVerifying) 
              CustomLoader(message: _isVerifying ? 'Verifying Smartcard...' : 'Processing Transaction...'),
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
          hint: const Text('Select Provider', style: TextStyle(color: Color(0xFF94A3B8))),
          isExpanded: true,
          style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
          items: _providers.map((p) => DropdownMenuItem<String>(value: p['id'], child: Text(p['name']!))).toList(),
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
}
