import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_loader.dart';
import '../models/user_data.dart';
import 'transaction_success_screen.dart';

// ─── Network ID map (matches Autopilot networkId) ───────────────────────────
const _networkMap = {
  'MTN': '1',
  'Airtel': '2',
  'Glo': '3',
  '9Mobile': '4',
};

const _networkColors = {
  'MTN': Color(0xFFFFCC00),
  'Airtel': Color(0xFFFF0000),
  'Glo': Color(0xFF00BB00),
  '9Mobile': Color(0xFF006600),
};

enum _A2CStep { form, otp, confirm }

class AirtimeToCashScreen extends ConsumerStatefulWidget {
  const AirtimeToCashScreen({super.key});

  @override
  ConsumerState<AirtimeToCashScreen> createState() => _AirtimeToCashScreenState();
}

class _AirtimeToCashScreenState extends ConsumerState<AirtimeToCashScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _phoneCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _qtyCtrl    = TextEditingController(text: '1');
  final _otpCtrl    = TextEditingController();
  final _simPinCtrl = TextEditingController();

  String? _selectedNetwork;
  _A2CStep _step = _A2CStep.form;
  bool _isLoading = false;
  int _resendTimer = 0;
  bool _canResend = true;

  // Returned by Step 1
  String? _identifier;
  // Returned by Step 2
  String? _sessionId;
  String? _airtimeBalance;

  double get _amount     => double.tryParse(_amountCtrl.text) ?? 0;
  int    get _qty        => int.tryParse(_qtyCtrl.text) ?? 1;
  double get _totalAirtime => _amount * _qty;
  double get _youReceive   => _totalAirtime * 0.85;

  @override
  void dispose() {
    _phoneCtrl.dispose(); _amountCtrl.dispose(); _qtyCtrl.dispose();
    _otpCtrl.dispose(); _simPinCtrl.dispose();
    super.dispose();
  }

  // ── STEP 1: Send OTP ──────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    if (_step == _A2CStep.form && !_formKey.currentState!.validate()) return;
    if (_selectedNetwork == null) {
      _showSnack('Please select a network');
      return;
    }
    setState(() => _isLoading = true);
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.post('/a2c/send-otp', data: {
        'network':      _networkMap[_selectedNetwork],
        'senderNumber': _phoneCtrl.text.trim(),
      });
      if (res.data['responseSuccessful'] == true) {
        setState(() {
          _identifier = res.data['responseBody']['identifier'];
          _step = _A2CStep.otp;
          _startResendTimer();
        });
        _showSnack('OTP sent to ${_phoneCtrl.text}', isSuccess: true);
      } else {
        _showSnack(res.data['responseMessage'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startResendTimer() {
    setState(() {
      _resendTimer = 60;
      _canResend = false;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _canResend = true;
        }
      });
      return _resendTimer > 0;
    });
  }

  // ── STEP 2: Verify OTP ────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().isEmpty) { _showSnack('Enter the OTP'); return; }
    setState(() => _isLoading = true);
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.post('/a2c/verify-otp', data: {
        'identifier': _identifier,
        'otp':        _otpCtrl.text.trim(),
      });
      if (res.data['responseSuccessful'] == true) {
        setState(() {
          _sessionId     = res.data['responseBody']['sessionId'];
          _airtimeBalance = res.data['responseBody']['airtimeBalance'];
          _step = _A2CStep.confirm;
        });
      } else {
        _showSnack(res.data['responseMessage'] ?? 'OTP verification failed');
      }
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── STEP 3: Submit ────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_simPinCtrl.text.trim().isEmpty) { _showSnack('Enter your SIM PIN'); return; }
    setState(() => _isLoading = true);
    final api = ref.read(apiServiceProvider);
    try {
      final res = await api.post('/a2c/submit', data: {
        'network':      _networkMap[_selectedNetwork],
        'senderNumber': _phoneCtrl.text.trim(),
        'sessionId':    _sessionId,
        'amount':       _amount.toString(),
        'quantity':     _qty.toString(),
        'phone_pin':    _simPinCtrl.text.trim(),
      });
      if (res.data['responseSuccessful'] == true) {
        await ref.read(authProvider.notifier).refreshProfile();
        if (mounted) {
          final tx = Transaction.fromJson(res.data['responseBody']);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => TransactionSuccessScreen(transaction: tx)),
          );
        }
      } else {
        _showSnack(res.data['responseMessage'] ?? 'Transaction failed');
        // Reset to step 1 if session is invalid
        setState(() { _step = _A2CStep.form; _sessionId = null; _identifier = null; });
      }
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? const Color(0xFF10B981) : Colors.red[700],
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Airtime to Cash',
            style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () {
            if (_step == _A2CStep.otp) {
              setState(() => _step = _A2CStep.form);
            } else if (_step == _A2CStep.confirm) {
              setState(() => _step = _A2CStep.otp);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Stack(
        children: [
          _buildBody(isTablet, size),
          if (_isLoading)
            CustomLoader(message: _step == _A2CStep.form
                ? 'Sending OTP…'
                : _step == _A2CStep.otp ? 'Verifying OTP…' : 'Processing…'),
        ],
      ),
    );
  }

  Widget _buildBody(bool isTablet, Size size) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? size.width * 0.2 : 24.0,
        vertical: 24.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepIndicator(),
          const SizedBox(height: 28),
          if (_step == _A2CStep.form)   _buildStep1()
          else if (_step == _A2CStep.otp) _buildStep2()
          else                           _buildStep3(),
        ],
      ),
    );
  }

  // ── Step Indicator ────────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    final steps = ['Details', 'Verify OTP', 'Confirm'];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = (i ~/ 2) < _step.index;
          return Expanded(child: Container(height: 2,
              color: done ? AppColors.primary : const Color(0xFFE2E8F0)));
        }
        final idx  = i ~/ 2;
        final active = idx == _step.index;
        final done   = idx <  _step.index;
        return Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done || active ? AppColors.primary : const Color(0xFFE2E8F0),
            ),
            child: Center(child: done
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text('${idx + 1}', style: TextStyle(
                    color: active ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700, fontSize: 13))),
          ),
          const SizedBox(height: 4),
          Text(steps[idx], style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: active ? AppColors.primary : const Color(0xFF94A3B8))),
        ]);
      }),
    );
  }

  // ── STEP 1 UI ─────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Select Network'),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _networkMap.keys.map((name) {
            final selected = _selectedNetwork == name;
            final color = _networkColors[name]!;
            return GestureDetector(
              onTap: () => setState(() => _selectedNetwork = name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72, height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: selected ? color : Colors.white,
                  border: Border.all(color: selected ? color : const Color(0xFFE2E8F0), width: 2),
                  boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))] : [],
                ),
                child: Center(child: Text(name,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w900,
                        color: selected
                            ? (name == 'MTN' || name == 'Glo' ? Colors.black87 : Colors.white)
                            : const Color(0xFF64748B)))),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        _sectionLabel('Sender Phone Number'),
        const SizedBox(height: 10),
        _inputField(
          controller: _phoneCtrl,
          hint: '08012345678',
          icon: Icons.phone_android_rounded,
          keyboardType: TextInputType.phone,
          validator: (v) => (v == null || v.isEmpty) ? 'Enter phone number' : null,
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionLabel('Amount per Send (₦)'),
            const SizedBox(height: 10),
            _inputField(
              controller: _amountCtrl,
              hint: '500',
              icon: Icons.attach_money_rounded,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final d = double.tryParse(v ?? '');
                if (d == null || d < 100) return 'Min ₦100';
                return null;
              },
            ),
          ])),
          const SizedBox(width: 16),
          SizedBox(width: 110, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionLabel('Quantity'),
            const SizedBox(height: 10),
            _inputField(
              controller: _qtyCtrl,
              hint: '1',
              icon: Icons.repeat_rounded,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final i = int.tryParse(v ?? '');
                if (i == null || i < 1) return 'Min 1';
                return null;
              },
            ),
          ])),
        ]),
        const SizedBox(height: 28),
        _buildSummaryCard(),
        const SizedBox(height: 32),
        _primaryButton('Send OTP to Phone', _sendOtp),
        const SizedBox(height: 16),
        _infoNote('An OTP will be sent to ${_phoneCtrl.text.isEmpty ? "your number" : _phoneCtrl.text} to authorise this transaction.'),
      ]),
    );
  }

  // ── STEP 2 UI ─────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoCard(Icons.sms_rounded, 'OTP Sent',
          'Enter the OTP sent to ${_phoneCtrl.text} to verify consent.'),
      const SizedBox(height: 28),
      _sectionLabel('Enter OTP'),
      const SizedBox(height: 10),
      _inputField(
        controller: _otpCtrl,
        hint: '123456',
        icon: Icons.lock_outline_rounded,
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 32),
      _primaryButton('Verify OTP', _verifyOtp),
      const SizedBox(height: 16),
      Center(child: TextButton(
        onPressed: (_isLoading || !_canResend) ? null : _sendOtp,
        child: Text(
          _canResend ? 'Resend OTP' : 'Resend in ${_resendTimer}s',
          style: TextStyle(
            color: _canResend ? AppColors.primary : const Color(0xFF94A3B8),
            fontWeight: FontWeight.w700
          )
        ),
      )),
    ]);
  }

  // ── STEP 3 UI ─────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_airtimeBalance != null)
        _infoCard(Icons.account_balance_wallet_outlined, 'Airtime Balance Confirmed',
            'Available airtime on ${_phoneCtrl.text}: $_airtimeBalance'),
      const SizedBox(height: 20),
      _buildSummaryCard(),
      const SizedBox(height: 28),
      _sectionLabel('SIM Card Transaction PIN'),
      const SizedBox(height: 10),
      _inputField(
        controller: _simPinCtrl,
        hint: '****',
        icon: Icons.dialpad_rounded,
        keyboardType: TextInputType.number,
        obscureText: true,
      ),
      const SizedBox(height: 32),
      _primaryButton('Convert & Credit Wallet', _submit),
      const SizedBox(height: 16),
      _infoNote('Your wallet will be credited ₦${NumberFormat("#,##0.00").format(_youReceive)} (85% of ₦${NumberFormat("#,##0.00").format(_totalAirtime)}).'),
    ]);
  }

  // ── Shared Widgets ────────────────────────────────────────────────────────
  Widget _buildSummaryCard() {
    final fmt = NumberFormat("#,##0.00");
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
      ),
      child: Column(children: [
        _summaryRow('Network', _selectedNetwork ?? '—'),
        _summaryRow('Phone', _phoneCtrl.text.isEmpty ? '—' : _phoneCtrl.text),
        _summaryRow('Amount × Qty', '₦${fmt.format(_amount)} × $_qty'),
        _summaryRow('Total Airtime', '₦${fmt.format(_totalAirtime)}'),
        _summaryRow('Service Charge (15%)', '-₦${fmt.format(_totalAirtime * 0.15)}', valueColor: Colors.red),
        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
        _summaryRow('You Receive', '₦${fmt.format(_youReceive)}',
            labelBold: true, valueColor: AppColors.primary, valueSize: 20),
      ]),
    );
  }

  Widget _summaryRow(String label, String value, {
    Color? valueColor, bool labelBold = false, double? valueSize,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: const Color(0xFF64748B),
            fontWeight: labelBold ? FontWeight.w800 : FontWeight.w500)),
        Text(value, style: TextStyle(
            color: valueColor ?? const Color(0xFF1E293B),
            fontWeight: FontWeight.w800,
            fontSize: valueSize)),
      ]),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent)),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity, height: 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String body) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E293B), fontSize: 14)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        ])),
      ]),
    );
  }

  Widget _infoNote(String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.5))),
    ]);
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF475569)));
  }
}
