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

  final List<String> _planGroups = ['All', 'SME', 'CG', 'GIFTING'];
  String _selectedGroup = 'All';

  final List<String> _validityFilters = ['All', 'Daily', 'Weekly', 'Monthly'];
  String _selectedValidity = 'All';

  String _getPlanCategory(Map<String, dynamic> plan) {
    final name = plan['name'].toString().toUpperCase();
    if (name.contains('SME')) return 'SME';
    if (name.contains('GIFTING') || name.contains('GIFT')) return 'GIFTING';
    if (name.contains('CG') || name.contains('CORPORATE') || name.contains('CORP')) return 'CG';
    return 'NORMAL';
  }

  String _getPlanValidity(Map<String, dynamic> plan) {
    final name = plan['name'].toString().toUpperCase();
    if (name.contains('DAY') || name.contains('HRS') || name.contains('HOUR') || name.contains('DAILY') || name.contains('1D')) {
      return 'DAILY';
    }
    if (name.contains('WEEK') || name.contains('7 DAYS') || name.contains('14 DAYS') || name.contains('WEEKLY') || name.contains('7D')) {
      return 'WEEKLY';
    }
    return 'MONTHLY';
  }

  Future<void> _fetchPlans(String serviceId) async {
    setState(() {
      _isLoadingPlans = true;
      _availablePlans = [];
      _selectedPlanData = null;
      _selectedGroup = 'All';
      _selectedValidity = 'All';
    });

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/vtu/variations', queryParameters: {'serviceID': serviceId});
      
      if (response.data['responseSuccessful']) {
        final List<dynamic> plans = response.data['responseBody'];
        setState(() {
          _availablePlans = plans;
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

  List<dynamic> get _filteredPlans {
    List<dynamic> plans = _availablePlans;

    if (_selectedGroup != 'All') {
      plans = plans.where((plan) => _getPlanCategory(plan) == _selectedGroup).toList();
    }

    if (_selectedValidity != 'All') {
      plans = plans.where((plan) => _getPlanValidity(plan) == _selectedValidity.toUpperCase()).toList();
    }

    return plans;
  }

  String _getGroupName(String group) {
    switch (group) {
      case 'All': return 'All Plans';
      case 'SME': return 'SME';
      case 'CG': return 'Corporate';
      case 'GIFTING': return 'Gifting';
      case 'NORMAL': return 'Normal';
      default: return group;
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
                    
                    // --- PREMIUM SEGMENTED TABS ---
                    if (_planGroups.length > 1) ...[
                      const Text(
                        'Select Category',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 50,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final tabWidth = constraints.maxWidth / _planGroups.length;
                            return Stack(
                              children: [
                                // Animated Background Highlight
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOutCubic,
                                  left: _planGroups.indexOf(_selectedGroup) * tabWidth,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: tabWidth,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Tab Labels
                                Row(
                                  children: _planGroups.map((group) {
                                    final isSelected = _selectedGroup == group;
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedGroup = group;
                                            _selectedPlanData = null;
                                          });
                                        },
                                        behavior: HitTestBehavior.opaque,
                                        child: Center(
                                          child: AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 200),
                                            style: TextStyle(
                                              color: isSelected ? const Color(0xFF011B60) : const Color(0xFF64748B),
                                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                            child: Text(_getGroupName(group)),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            );
                          }
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    
                    _buildInputField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter recipient number' : (v.length < 11 ? 'Invalid phone number' : null),
                    ),
    
                    const SizedBox(height: 24),
                    if (_availablePlans.isNotEmpty) ...[
                      const Text(
                        'Choose Data Plan',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 16),

                      // --- SUB-FILTER (VALIDITY / DURATION) ---
                      SizedBox(
                        height: 38,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _validityFilters.length,
                          itemBuilder: (context, index) {
                            final filter = _validityFilters[index];
                            final isSelected = _selectedValidity == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedValidity = filter;
                                    _selectedPlanData = null;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF011B60).withOpacity(0.08) : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF011B60) : const Color(0xFFE2E8F0),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      filter,
                                      style: TextStyle(
                                        color: isSelected ? const Color(0xFF011B60) : const Color(0xFF64748B),
                                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      if (_isLoadingPlans)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(color: Color(0xFF011B60)),
                        ))
                      else if (_filteredPlans.isEmpty)
                        const Center(child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text('No plans available in this category.'),
                        ))
                      else
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedPlanData,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8), size: 24),
                          decoration: InputDecoration(
                            labelText: 'Select Data Plan',
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                            prefixIcon: const Icon(Icons.network_wifi_rounded, color: Color(0xFF94A3B8), size: 22),
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          ),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          items: _filteredPlans.map<DropdownMenuItem<Map<String, dynamic>>>((plan) {
                            final price = plan['variation_amount']?.toString() ?? '0';
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: plan as Map<String, dynamic>,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        if (plan['is_featured'] == true) ...[
                                          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                          const SizedBox(width: 4),
                                        ] else if (plan['is_recommended'] == true) ...[
                                          const Icon(Icons.thumb_up_rounded, color: Colors.blue, size: 14),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            plan['name'].toString(),
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF1E293B),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "₦$price",
                                      style: const TextStyle(
                                        color: Color(0xFF011B60),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (Map<String, dynamic>? newValue) {
                            setState(() {
                              _selectedPlanData = newValue;
                            });
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
