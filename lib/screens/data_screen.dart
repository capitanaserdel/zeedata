import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_loader.dart';
import 'transaction_pin_screen.dart';
import 'transaction_success_screen.dart';
import '../models/user_data.dart';
import '../core/validators/app_validators.dart';
import '../core/utils/keyboard_utils.dart';
import '../widgets/common/insufficient_balance_indicator.dart';
import 'package:intl/intl.dart';
import '../providers/balance_provider.dart';
import '../widgets/contact_picker_button.dart';

class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String? _selectedNetwork = 'MTN';
  bool _isProcessing = false;
  Map<String, dynamic>? _selectedPlanData;
  List<dynamic> _availablePlans = [];
  bool _isLoadingPlans = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPlans('mtn-data');
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> _networks = [
    {'name': 'MTN', 'id': 'mtn-data', 'color': const Color(0xFFFFCC00), 'textColor': Colors.black},
    {'name': 'Airtel', 'id': 'airtel-data', 'color': const Color(0xFFFF0000), 'textColor': Colors.white},
    {'name': 'Glo', 'id': 'glo-data', 'color': const Color(0xFF00FF00), 'textColor': Colors.black},
    {'name': '9mobile', 'id': '9mobile-data', 'color': const Color(0xFF006600), 'textColor': Colors.white},
  ];

  Future<void> _fetchPlans(String serviceId) async {
    setState(() {
      _isLoadingPlans = true;
      _availablePlans = [];
      _selectedPlanData = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/vtu/variations', queryParameters: {'serviceID': serviceId});
      
      if (response.data['responseSuccessful']) {
        setState(() {
          _availablePlans = response.data['responseBody'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load plans: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoadingPlans = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final wallet = authState.wallet;
    final balance = wallet?.balance ?? 0;
    final hideBalance = ref.watch(balanceVisibilityProvider);
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    final selectedPrice = double.tryParse(_selectedPlanData?['variation_amount']?.toString() ?? '0') ?? 0;
    final isBalanceLow = selectedPrice > balance;

    return KeyboardDismissOnTap(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Buy Data', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
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
                vertical: 10,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF011B60),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF011B60).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Wallet Balance',
                                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
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
                            hideBalance ? '₦ ••••••••' : currencyFormat.format(balance),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: hideBalance ? 2 : -1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    const Text(
                      'Select Network',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 16),
                    
                    // Network Selection Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: _networks.length,
                      itemBuilder: (context, index) {
                        final network = _networks[index];
                        final isSelected = _selectedNetwork == network['name'];
                        return GestureDetector(
                          onTap: () {
                            KeyboardUtils.hide(context);
                            setState(() => _selectedNetwork = network['name']);
                            _fetchPlans(network['id']);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected ? network['color'] : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? network['color'] : const Color(0xFFF1F5F9),
                                width: 2,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(color: network['color'].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                              ] : [],
                            ),
                            child: Center(
                              child: Text(
                                network['name'],
                                style: TextStyle(
                                  color: isSelected ? network['textColor'] : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    _buildInputField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter recipient number' : (v.length < 11 ? 'Invalid phone number' : null),
                    ),
    
                    const SizedBox(height: 24),
                    if (_selectedNetwork != null) ...[
                      const Text(
                        'Choose Data Plan',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_isLoadingPlans)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(color: Color(0xFF011B60)),
                        ))
                      else if (_availablePlans.isEmpty)
                        const Center(child: Text('No plans available for this network.'))
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
                          itemCount: _availablePlans.length,
                          itemBuilder: (context, index) {
                            final plan = _availablePlans[index];
                            final isSelected = _selectedPlanData == plan;
                            final price = double.tryParse(plan['variation_amount']?.toString() ?? '0') ?? 0;
                            final planIsBalanceLow = price > balance;
                            
                            return GestureDetector(
                              onTap: () {
                                KeyboardUtils.hide(context);
                                setState(() => _selectedPlanData = plan);
                              },
                              child: Stack(
                                children: [
                                  AnimatedContainer(
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
                                            fontSize: 14,
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
                                                  : (isSelected ? Colors.white : const Color(0xFF011B60)),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (plan['is_featured'] == true)
                                    Positioned(
                                      top: 8,
                                      right: 8,
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
                                      top: 8,
                                      right: 8,
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
                    
                    InsufficientBalanceIndicator(
                      amount: selectedPrice,
                      balance: balance,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    ElevatedButton(
                      onPressed: (authState.isLoading || _isProcessing || isBalanceLow || _selectedPlanData == null) ? null : _handlePurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF011B60),
                        disabledBackgroundColor: const Color(0xFF011B60).withOpacity(0.5),
                        minimumSize: const Size(double.infinity, 64),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: Text(
                        isBalanceLow 
                          ? 'Insufficient Balance' 
                          : (_selectedPlanData != null 
                              ? 'Pay ${currencyFormat.format(selectedPrice)}'
                              : 'Purchase Data'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
            
            if (authState.isLoading || _isProcessing) const CustomLoader(message: 'Processing Transaction...'),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 22),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF011B60), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        suffixIcon: label == 'Phone Number' 
            ? ContactPickerButton(controller: controller) 
            : null,
      ),
    );
  }

  Future<void> _processTransaction(String pin) async {
    setState(() => _isProcessing = true);

    final api = ref.read(apiServiceProvider);
    try {
      final response = await api.post('/data', data: {
        'phone': _phoneController.text,
        'serviceID': _networks.firstWhere((n) => n['name'] == _selectedNetwork)['id'],
        'variation_code': _selectedPlanData!['variation_code'],
        'amount': _selectedPlanData!['variation_amount'],
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
            SnackBar(
              content: Text(response.data['responseMessage'] ?? 'Transaction failed'),
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

  Future<void> _handlePurchase() async {
    KeyboardUtils.hide(context);
    
    if (_selectedNetwork == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a network provider'), backgroundColor: Colors.orange));
      return;
    }

    if (_selectedPlanData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a data plan'), backgroundColor: Colors.orange));
      return;
    }

    if (_formKey.currentState!.validate()) {
      final pinResult = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TransactionPinScreen()),
      );

      if (pinResult != null && pinResult is String) {
        await _processTransaction(pinResult);
      }
    }
  }
}
