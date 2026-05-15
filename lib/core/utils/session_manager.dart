import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Shared Preferences Keys (Non-sensitive/UI state)
  static const String keyIsFirstTime = 'is_first_time';

  // Secure Storage Keys (Sensitive/Persistent)
  static const String keyAuthToken = 'auth_token';
  static const String keyUserPin = 'user_transaction_pin';
  static const String keyUserPassword = 'user_login_password';
  static const String keyLastUserName = 'last_user_name';
  static const String keyLastUserEmail = 'last_user_email';
  static const String keyHasAccount = 'has_active_account';
  static const String keyLoginBiometricsEnabled = 'login_biometrics_enabled';
  static const String keyTransactionBiometricsEnabled = 'transaction_biometrics_enabled';

  // First Time User
  Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyIsFirstTime) ?? true;
  }

  Future<void> setFirstTimeComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIsFirstTime, false);
  }

  // Auth Token
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: keyAuthToken, value: token);
    await _secureStorage.write(key: keyHasAccount, value: 'true');
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: keyAuthToken);
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: keyAuthToken);
  }

  // User Transaction PIN
  Future<void> savePin(String pin) async {
    await _secureStorage.write(key: keyUserPin, value: pin);
  }

  Future<String?> getPin() async {
    return await _secureStorage.read(key: keyUserPin);
  }

  Future<void> deletePin() async {
    await _secureStorage.delete(key: keyUserPin);
  }

  // Clear Biometric Enrollment (Security Invalidation)
  Future<void> clearBiometricEnrollment() async {
    await setLoginBiometricsEnabled(false);
    await setTransactionBiometricsEnabled(false);
    await _secureStorage.delete(key: keyUserPin);
    await _secureStorage.delete(key: keyUserPassword);
  }

  // User Password (for biometric login recovery)
  Future<void> savePassword(String password) async {
    await _secureStorage.write(key: keyUserPassword, value: password);
  }

  Future<String?> getPassword() async {
    return await _secureStorage.read(key: keyUserPassword);
  }

  Future<void> deletePassword() async {
    await _secureStorage.delete(key: keyUserPassword);
  }

  // Login Biometrics
  Future<void> setLoginBiometricsEnabled(bool enabled) async {
    await _secureStorage.write(key: keyLoginBiometricsEnabled, value: enabled.toString());
  }

  Future<bool> isLoginBiometricsEnabled() async {
    final val = await _secureStorage.read(key: keyLoginBiometricsEnabled);
    return val == 'true';
  }

  // Transaction Biometrics
  Future<void> setTransactionBiometricsEnabled(bool enabled) async {
    await _secureStorage.write(key: keyTransactionBiometricsEnabled, value: enabled.toString());
  }

  Future<bool> isTransactionBiometricsEnabled() async {
    final val = await _secureStorage.read(key: keyTransactionBiometricsEnabled);
    return val == 'true';
  }

  // Last User Data (for Welcome Back)
  Future<void> saveLastUser(String name, String email) async {
    await _secureStorage.write(key: keyLastUserName, value: name);
    await _secureStorage.write(key: keyLastUserEmail, value: email);
    await _secureStorage.write(key: keyHasAccount, value: 'true');
  }

  Future<Map<String, String?>> getLastUser() async {
    return {
      'name': await _secureStorage.read(key: keyLastUserName),
      'email': await _secureStorage.read(key: keyLastUserEmail),
      'hasAccount': await _secureStorage.read(key: keyHasAccount),
    };
  }

  // Clear Session (Normal Logout / Expiry)
  Future<void> clearSession() async {
    await deleteToken();
    // We KEEP last user data and hasAccount flag for "Welcome Back"
  }

  // Full Wipe (Delete Account / Switch Account)
  Future<void> fullWipe() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool(keyIsFirstTime) ?? true;
    await prefs.clear();
    await prefs.setBool(keyIsFirstTime, isFirstTime);
  }
}
