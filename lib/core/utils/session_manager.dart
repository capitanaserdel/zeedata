import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Shared Preferences Keys
  static const String keyIsFirstTime = 'is_first_time';
  static const String keyLastUserName = 'last_user_name';
  static const String keyLastUserEmail = 'last_user_email';
  static const String keyBiometricsEnabled = 'biometrics_enabled';

  // Secure Storage Keys
  static const String keyAuthToken = 'auth_token';
  static const String keyUserPin = 'user_transaction_pin';
  static const String keyUserPassword = 'user_login_password';

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

  // Clear Biometric Enrollment (Security Invalidation)
  Future<void> clearBiometricEnrollment() async {
    await setLoginBiometricsEnabled(false);
    await setTransactionBiometricsEnabled(false);
    await _secureStorage.delete(key: keyUserPin); // Invalidate stored PIN too
    print("🔒 BIOMETRIC ENROLLMENT CLEARED");
  }

  // Login Biometrics
  Future<void> setLoginBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('login_biometrics_enabled', enabled);
  }

  Future<bool> isLoginBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('login_biometrics_enabled') ?? false;
  }

  // Transaction Biometrics
  Future<void> setTransactionBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('transaction_biometrics_enabled', enabled);
  }

  Future<bool> isTransactionBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('transaction_biometrics_enabled') ?? false;
  }

  // Last User Data (for Welcome Back)
  Future<void> saveLastUser(String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLastUserName, name);
    await prefs.setString(keyLastUserEmail, email);
  }

  Future<Map<String, String?>> getLastUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(keyLastUserName),
      'email': prefs.getString(keyLastUserEmail),
    };
  }

  // Clear Session
  Future<void> clearSession() async {
    await deleteToken();
    // We keep last user data for "Welcome Back" unless it's a "Switch Account"
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
