import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_colors.dart';
import '../widgets/custom_loader.dart';
import 'transaction_pin_screen.dart';
import 'transaction_success_screen.dart';
import '../models/user_data.dart';
import 'package:intl/intl.dart';

class EducationPinScreen extends ConsumerStatefulWidget {
  const EducationPinScreen({super.key});

  @override
  ConsumerState<EducationPinScreen> createState() => _EducationPinScreenState();
}

class _EducationPinScreenState extends ConsumerState<EducationPinScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedExam;
  Map<String, dynamic>? _selectedPlan;
  List<dynamic> _plans = [];
  int _quantity = 1;
  bool _isLoadingPlans = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() => _isLoadingPlans = true);
    try {
      final api = ref.read(apiServiceProvider);
      // Fetch for both WAEC and NECO or just one as a starting point
      // VTPass typically has separate serviceIDs for each
      final response = await api.get('/vtu/variations', queryParameters: {'serviceID': 'waec'});
      if (response.data['responseSuccessful']) {
        setState(() {
          _plans = response.data['responseBody'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch plans: $e')));
    } finally {
      setState(() => _isLoadingPlans = false);
    }
  }

  Future<void> _handlePurchase() async {
    if (_selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an exam type')));
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
      
      final response = await api.post('/education/purchase', data: {
        'serviceID': 'waec', // Or dynamically set based on selected plan
        'variation_code': _selectedPlan!['variation_code'] ?? _selectedPlan!['id'],
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
            SnackBar(content: Text(response.data['responseMessage'] ?? 'Purchase failed')),
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

  void _showSuccessDialog(List pins) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text('Purchase Successful', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your examination PIN(s) are ready:', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ...pins.map((pin) => Container(
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
            )).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to dashboard
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Education PIN', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w900)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBalanceCard(authState, currencyFormat),
                const SizedBox(height: 32),
                
                const Text('Select Exam Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                _buildExamDropdown(),
                
                const SizedBox(height: 24),
                const Text('Quantity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                _buildQuantitySelector(),
                
                const SizedBox(height: 40),
                
                // Price Summary
                if (_selectedPlan != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow('Unit Price', currencyFormat.format(_selectedPlan!['amount'])),
                        const Divider(height: 24),
                        _buildSummaryRow('Quantity', 'x$_quantity'),
                        const Divider(height: 24),
                        _buildSummaryRow('Total Amount', currencyFormat.format((_selectedPlan!['amount'] as num) * _quantity), isTotal: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isLoadingPlans || _isProcessing) ? null : _handlePurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      _isProcessing ? 'Processing...' : 'Purchase PIN',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isProcessing || _isLoadingPlans) const CustomLoader(message: 'Please wait...'),
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

  Widget _buildExamDropdown() {
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
          hint: Text(_isLoadingPlans ? 'Fetching exams...' : 'Choose Examination Body'),
          isExpanded: true,
          items: _plans.map((p) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: Map<String, dynamic>.from(p),
              child: Text(p['name'].toString().toUpperCase()),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedPlan = val),
        ),
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      children: List.generate(5, (index) {
        final q = index + 1;
        final isSelected = _quantity == q;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 4 ? 0 : 8),
            child: InkWell(
              onTap: () => setState(() => _quantity = q),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '$q',
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: isTotal ? AppColors.textPrimary : const Color(0xFF64748B), fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600)),
        Text(value, style: TextStyle(fontSize: isTotal ? 18 : 14, color: isTotal ? AppColors.primary : AppColors.textPrimary, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
