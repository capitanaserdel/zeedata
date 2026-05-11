import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final balanceVisibilityProvider = StateNotifierProvider<BalanceVisibilityNotifier, bool>((ref) {
  return BalanceVisibilityNotifier();
});

class BalanceVisibilityNotifier extends StateNotifier<bool> {
  BalanceVisibilityNotifier() : super(false) {
    _loadState();
  }

  static const _key = 'hide_balance';

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}
