import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_loader.dart';
import 'transaction_pin_screen.dart';
import '../core/utils/keyboard_utils.dart';
import '../widgets/common/insufficient_balance_indicator.dart';
import 'package:intl/intl.dart';
import '../providers/balance_provider.dart';
import '../core/theme/app_colors.dart';

class DataPinScreen extends ConsumerStatefulWidget {
  const DataPinScreen({super.key});

  @override
  ConsumerState<DataPinScreen> createState() => _DataPinScreenState();
}

class _DataPinScreenState extends ConsumerState<DataPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  String? _selectedNetwork = 'MTN';
  int _quantity = 1;
  bool _isProcessing = false;
  Map<String, dynamic>? _selectedPlan;

  final List<Map<String, dynamic>> _networks = [
    {'name': 'MTN', 'id': '1', 'color': const Color(0xFFFFCC00), 'textColor': Colors.black},
    {'name': 'Glo', 'id': '2', 'color': const Color(0xFF00FF00), 'textColor': Colors.black},
    {'name': '9mobile', 'id': '3', 'color': const Color(0xFF006600), 'textColor': Colors.white},
    {'name': 'Airtel', 'id': '4', 'color': const Color(0xFFFF0000), 'textColor': Colors.white},
  ];

  // Placeholder plans - User should update these based on VTUNaija Documentation Page 1
  final List<Map<String, dynamic>> _mtnPlans = [
    {'id': '1', 'name': '1.5GB Data Pin', 'price': 300.0},
    {'id': '2', 'name': '2GB Data Pin', 'price': 500.0},
    {'id': '3', 'name': '3GB Data Pin', 'price': 700.0},
    {'id': '4', 'name': '5GB Data Pin', 'price': 1100.0},
  ];

  @override
  void dispose() {
    _businessNameController.dispose();
    super.dispose();
  }

  double get _totalAmount => (_selectedPlan?['price'] ?? 0.0) * _quantity;

  Future<void> _handlePurchase() async {
    KeyboardUtils.hide(context);
    
    if (_selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a data plan'), backgroundColor: Colors.orange));
      return;
    }

    final balance = ref.read(authProvider).wallet?.balance ?? 0;
    if (balance < _totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient balance'), backgroundColor: Colors.red));
      return;
    }

    final pinResult = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransactionPinScreen()),
    );

    if (pinResult != null && pinResult is String) {
      _processPurchase(pinResult);
    }
  }

  Future<void> _processPurchase(String pin) async {
    setState(() => _isProcessing = true);
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post('/data-pin/purchase', data: {
        'network': _selectedNetwork,
        'data_plan': _selectedPlan!['id'],
        'quantity': _quantity,
        'business_name': _businessNameController.text.trim(),
        'amount': _totalAmount,
        'pin': pin,
      });

      if (response.data['responseSuccessful']) {
        if (mounted) {
          final result = response.data['responseBody'];
          final List<dynamic> pins = result['metadata']['pins'] ?? [];
          
          await _showSuccessDialog(pins);
          await ref.read(authProvider.notifier).refreshProfile();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.data['responseMessage'] ?? 'Purchase failed'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showSuccessDialog(List<dynamic> pins) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text('Data PINs Purchased!', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your pins have been generated successfully.'),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: pins.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) => ListTile(
                    title: Text('PIN ${index + 1}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(pins[index].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () {
                        // Copy logic
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final balance = authState.wallet?.balance ?? 0;
    final hideBalance = ref.watch(balanceVisibilityProvider);
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Data PIN', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
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
                  _buildBalanceCard(balance, currencyFormat, hideBalance),
                  const SizedBox(height: 32),
                  
                  const Text('Select Network', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  _buildNetworkGrid(),

                  const SizedBox(height: 32),
                  const Text('Select Data Plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  _buildPlanGrid(),

                  const SizedBox(height: 32),
                  _buildQuantitySelector(),

                  const SizedBox(height: 32),
                  _buildTextField(
                    label: 'Business Name (Optional)',
                    controller: _businessNameController,
                    hint: 'e.g. Boma Enterprise',
                  ),

                  const SizedBox(height: 32),
                  _buildSummaryCard(currencyFormat),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handlePurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(_isProcessing ? 'Processing...' : 'Purchase Data PINs', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isProcessing) const CustomLoader(message: 'Generating PINs...'),
        ],
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
                child: Icon(hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white70, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hideBalance ? '₦ ••••••••' : format.format(balance),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: _networks.length,
      itemBuilder: (context, index) {
        final net = _networks[index];
        final isSelected = _selectedNetwork == net['name'];
        return GestureDetector(
          onTap: () => setState(() => _selectedNetwork = net['name']),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? net['color'] : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? net['color'] : Colors.transparent, width: 2),
            ),
            child: Center(child: Text(net['name'], style: TextStyle(color: isSelected ? net['textColor'] : Colors.black54, fontWeight: FontWeight.bold))),
          ),
        );
      },
    );
  }

  Widget _buildPlanGrid() {
    // Only showing MTN plans for sandbox demo, but user can add others
    final plans = _selectedNetwork == 'MTN' ? _mtnPlans : [];
    if (plans.isEmpty) return const Center(child: Text('No plans available for this network in sandbox.'));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        final isSelected = _selectedPlan == plan;
        return GestureDetector(
          onTap: () => setState(() => _selectedPlan = plan),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? AppColors.primary : Colors.grey[300]!, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(plan['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppColors.primary : Colors.black87)),
                Text('₦${plan['price']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuantitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quantity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Row(
          children: [
            _qtyBtn(Icons.remove, () => setState(() => _quantity = _quantity > 1 ? _quantity - 1 : 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_quantity.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            _qtyBtn(Icons.add, () => setState(() => _quantity++)),
          ],
        ),
      ],
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 20),
      ),
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, required String hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(NumberFormat format) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(format.format(_totalAmount), style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 18)),
        ],
      ),
    );
  }
}
