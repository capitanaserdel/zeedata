import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_colors.dart';
import '../widgets/custom_loader.dart';
import 'transaction_pin_screen.dart';
import 'package:intl/intl.dart';
import '../core/utils/keyboard_utils.dart';
import '../widgets/common/insufficient_balance_indicator.dart';
import '../providers/balance_provider.dart';

class RechargePinScreen extends ConsumerStatefulWidget {
  const RechargePinScreen({super.key});

  @override
  ConsumerState<RechargePinScreen> createState() => _RechargePinScreenState();
}

class _RechargePinScreenState extends ConsumerState<RechargePinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  
  String? _selectedNetwork;
  int _quantity = 1;
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _networks = [
    {'name': 'MTN', 'id': 'mtn', 'color': const Color(0xFFFFCC00), 'ussd': '*555*PIN#'},
    {'name': 'Airtel', 'id': 'airtel', 'color': const Color(0xFFFF0000), 'ussd': '*126*PIN#'},
    {'name': 'Glo', 'id': 'glo', 'color': const Color(0xFF00FF00), 'ussd': '*123*PIN#'},
    {'name': '9mobile', 'id': '9mobile', 'color': const Color(0xFF006600), 'ussd': '*222*PIN#'},
  ];

  double get _totalAmount {
    final amount = double.tryParse(_amountController.text) ?? 0;
    return amount * _quantity;
  }

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handlePurchase() async {
    KeyboardUtils.hide(context);
    
    if (_selectedNetwork == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a network'), backgroundColor: Colors.orange));
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authProvider);
    if ((authState.wallet?.balance ?? 0) < _totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient balance'), backgroundColor: Colors.red));
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
    try {
      final api = ref.read(apiServiceProvider);
      final amount = double.parse(_amountController.text);
      
      final response = await api.post('/recharge-pin/purchase', data: {
        'network': _selectedNetwork,
        'amount': amount,
        'quantity': _quantity,
        'total_amount': _totalAmount,
        'pin': pin,
      });

      if (response.data['responseSuccessful']) {
        if (mounted) {
          await ref.read(authProvider.notifier).saveStoredPin(pin);
          await ref.read(authProvider.notifier).refreshProfile();
          
          final pins = (response.data['responseBody']['transaction']['metadata']['pins'] as List?) ?? [];
          final ussd = _networks.firstWhere((n) => n['id'] == _selectedNetwork)['ussd'];
          
          _showSuccessDialog(pins, ussd);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.data['responseMessage'] ?? 'Purchase failed'),
              backgroundColor: Colors.red,
            ),
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

  void _showSuccessDialog(List pins, String ussd) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text('PINs Purchased', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Recharge with $ussd', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: pins.length,
                itemBuilder: (context, index) {
                  final pin = pins[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            pin.toString(),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20, color: AppColors.primary),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: pin.toString()));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN copied!'), duration: Duration(seconds: 1)));
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
    final hideBalance = ref.watch(balanceVisibilityProvider);

    return KeyboardDismissOnTap(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Recharge PIN', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w900)),
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
                      amount: _totalAmount,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    const Text('Select Network', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 16),
                    _buildNetworkGrid(),
                    
                    const SizedBox(height: 24),
                    _buildTextField(
                      label: 'Amount (₦)',
                      controller: _amountController,
                      hint: 'e.g. 100',
                      keyboardType: TextInputType.number,
                    ),
                    
                    const SizedBox(height: 24),
                    const Text('Quantity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 12),
                    _buildQuantitySelector(),
                    
                    const SizedBox(height: 40),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: (_isProcessing || authState.isLoading) ? null : _handlePurchase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                        ),
                        child: Text(
                          _isProcessing ? 'Processing...' : 'Generate PIN(s)',
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
            if (_isProcessing || authState.isLoading) const CustomLoader(message: 'Processing...'),
          ],
        ),
      ),
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

  Widget _buildNetworkGrid() {
    return GridView.builder(
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
        final isSelected = _selectedNetwork == network['id'];
        return GestureDetector(
          onTap: () => setState(() => _selectedNetwork = network['id']),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? network['color'] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? network['color'] : const Color(0xFFE2E8F0),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                network['name'],
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      children: [
        _buildQtyBtn(Icons.remove, () { if (_quantity > 1) setState(() => _quantity--); }),
        const SizedBox(width: 24),
        Text('$_quantity', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        const SizedBox(width: 24),
        _buildQtyBtn(Icons.add, () { if (_quantity < 10) setState(() => _quantity++); }),
      ],
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.primary, width: 2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent)),
          ),
          validator: (val) {
            if (val == null || val.isEmpty) return 'Required';
            final n = double.tryParse(val);
            if (n == null || n <= 0) return 'Invalid amount';
            return null;
          },
        ),
      ],
    );
  }
}
