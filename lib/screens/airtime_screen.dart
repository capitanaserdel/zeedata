import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_loader.dart';
import 'transaction_pin_screen.dart';
import 'transaction_success_screen.dart';
import '../models/user_data.dart';
import 'package:intl/intl.dart';

class AirtimeScreen extends ConsumerStatefulWidget {
  const AirtimeScreen({super.key});

  @override
  ConsumerState<AirtimeScreen> createState() => _AirtimeScreenState();
}

class _AirtimeScreenState extends ConsumerState<AirtimeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();
  String? _selectedNetwork;
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _networks = [
    {'name': 'MTN', 'color': const Color(0xFFFFCC00), 'textColor': Colors.black},
    {'name': 'Airtel', 'color': const Color(0xFFFF0000), 'textColor': Colors.white},
    {'name': 'Glo', 'color': const Color(0xFF00FF00), 'textColor': Colors.black},
    {'name': '9mobile', 'color': const Color(0xFF006600), 'textColor': Colors.white},
  ];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final wallet = authState.wallet;
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Buy Airtime', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
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
                        const Text(
                          'Wallet Balance',
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormat.format(wallet?.balance ?? 0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
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
                        onTap: () => setState(() => _selectedNetwork = network['name']),
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
                    validator: (v) => v!.isEmpty ? 'Enter recipient number' : null,
                  ),
                  const SizedBox(height: 20),
                  
                  _buildInputField(
                    controller: _amountController,
                    label: 'Amount (₦)',
                    icon: Icons.account_balance_wallet_rounded,
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Enter amount' : null,
                  ),
                  const SizedBox(height: 20),
                  
                  const SizedBox(height: 40),
                  
                  ElevatedButton(
                    onPressed: (authState.isLoading || _isProcessing) ? null : _handlePurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF011B60),
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Purchase Airtime',
                      style: TextStyle(
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
          
          if (authState.isLoading || _isProcessing) const CustomLoader(message: 'Processing Transaction...'),
        ],
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
      ),
    );
  }

  Future<void> _processTransaction(String pin) async {
    setState(() => _isProcessing = true);
    print("🚀 Sending transaction with PIN: $pin");
    
    final api = ref.read(apiServiceProvider);
    try {
      final response = await api.post('/airtime', data: {
        'amount': _amountController.text,
        'phone': _phoneController.text,
        'network': _selectedNetwork,
        'pin': pin,
      });

      if (response.data['responseSuccessful']) {
        if (mounted) {
          // Save the verified PIN for future biometric use
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

  Future<void> _handlePurchase() async {
    if (_selectedNetwork == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a network provider')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      // 1. Show Transaction PIN Screen
      final pinResult = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TransactionPinScreen()),
      );

      // 2. If we got a valid PIN (either from manual entry or biometric retrieval)
      if (pinResult != null && pinResult is String) {
        await _processTransaction(pinResult);
      }
    }
  }
}
