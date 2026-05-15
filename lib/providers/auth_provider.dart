import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../models/user_data.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../core/utils/session_manager.dart';

class AuthState {
  final User? user;
  final Wallet? wallet;
  final List<Transaction> recentTransactions;
  final bool isLoading;
  final bool isInitializing;
  final bool isLoginBioLoading;
  final bool isTransBioLoading;
  final String? error;
  final bool isAuthenticated;
  final bool isFirstTime;
  final bool isLocked;
  final bool isAccountDeleted;
  final bool shouldShowLogin;
  
  // Helper getters for easy UI binding
  bool get loginBioEnabled => user?.userSettings?.passwordFingerprint ?? false;
  bool get transBioEnabled => user?.userSettings?.pinFingerprint ?? false;

  AuthState({
    this.user,
    this.wallet,
    this.recentTransactions = const [],
    this.isLoading = false,
    this.isInitializing = true,
    this.isLoginBioLoading = false,
    this.isTransBioLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.isFirstTime = false,
    this.isLocked = false,
    this.isAccountDeleted = false,
    this.shouldShowLogin = false,
  });

  AuthState copyWith({
    User? user,
    Wallet? wallet,
    List<Transaction>? recentTransactions,
    bool? isLoading,
    bool? isInitializing,
    bool? isLoginBioLoading,
    bool? isTransBioLoading,
    String? error,
    bool? isAuthenticated,
    bool? isFirstTime,
    bool? isLocked,
    bool? isAccountDeleted,
    bool? shouldShowLogin,
  }) {
    return AuthState(
      user: user ?? this.user,
      wallet: wallet ?? this.wallet,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
      isLoginBioLoading: isLoginBioLoading ?? this.isLoginBioLoading,
      isTransBioLoading: isTransBioLoading ?? this.isTransBioLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isFirstTime: isFirstTime ?? this.isFirstTime,
      isLocked: isLocked ?? this.isLocked,
      isAccountDeleted: isAccountDeleted ?? this.isAccountDeleted,
      shouldShowLogin: shouldShowLogin ?? this.shouldShowLogin,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final SettingsService _settingsService;
  final SessionManager _sessionManager = SessionManager();

  String _getErrorMessage(dynamic responseData) {
    if (responseData == null) return 'An unexpected error occurred';
    
    String message = responseData['responseMessage'] ?? 'An error occurred';
    
    if (responseData['errors'] != null) {
      final errors = responseData['errors'] as Map<String, dynamic>;
      if (errors.isNotEmpty) {
        final firstError = errors.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          return firstError.first.toString();
        } else if (firstError is String) {
          return firstError;
        }
      }
    }
    
    return message;
  }

  AuthNotifier(this._apiService, this._settingsService) : super(AuthState()) {
    checkAuth();
    // Debug listener
    addListener((state) {
    // State change tracking
    });
  }

  Future<void> fetchTransactions() async {
    try {
      final response = await _apiService.get('/transactions');
      if (response.data['responseSuccessful']) {
        final body = response.data['responseBody'];
        state = state.copyWith(
          recentTransactions: (body['transactions']['data'] as List)
              .map((t) => Transaction.fromJson(t))
              .toList(),
        );
      }
    } catch (e) {
      // Fetch error
    }
  }

  Future<void> refreshProfile() async {
    try {
      final response = await _apiService.get('/profile');
      if (response.data['responseSuccessful']) {
        final body = response.data['responseBody'];
        final user = User.fromJson(body['user']);
        
        state = state.copyWith(
          user: user,
          wallet: Wallet.fromJson(body['wallet']),
          recentTransactions: (body['recentTransactions'] as List)
              .map((t) => Transaction.fromJson(t))
              .toList(),
        );
      }
    } catch (e) {
      if (e.toString().contains('Session expired') || e.toString().contains('Unauthenticated') || e.toString().contains('Access denied') || e.toString().contains('Deleted')) {
        await _sessionManager.clearSession(); 
        final lastUser = await _sessionManager.getLastUser();
        final loginBio = await _sessionManager.isLoginBiometricsEnabled();
        final transBio = await _sessionManager.isTransactionBiometricsEnabled();
        
        state = AuthState(
          isFirstTime: false, 
          isAccountDeleted: e.toString().contains('Deleted'), 
          isInitializing: false,
          user: lastUser['name'] != null ? User(
            id: 0, 
            fullname: lastUser['name']!, 
            email: lastUser['email']!, 
            phone: '', 
            status: '', 
            tier: '', 
            isVerified: false, 
            hasPin: true,
            userSettings: UserSetting(
              id: 0, 
              pinFingerprint: transBio, 
              passwordFingerprint: loginBio
            )
          ) : null,
        );
      }
    }
  }

  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      final isFirstTime = await _sessionManager.isFirstTime();
      final token = await _sessionManager.getToken();
      final lastUser = await _sessionManager.getLastUser();
      final loginBio = await _sessionManager.isLoginBiometricsEnabled();
      final transBio = await _sessionManager.isTransactionBiometricsEnabled();
      
      final bool hasAccount = lastUser['hasAccount'] == 'true';
      
      // Auth status check
      
      if (token != null) {
        try {
          final response = await _apiService.get('/profile');
          if (response.data['responseSuccessful']) {
            final body = response.data['responseBody'];
            final user = User.fromJson(body['user']);
            
            await _sessionManager.setLoginBiometricsEnabled(user.userSettings?.passwordFingerprint ?? false);
            await _sessionManager.setTransactionBiometricsEnabled(user.userSettings?.pinFingerprint ?? false);
            
            state = state.copyWith(
              isAuthenticated: true,
              isLocked: true,
              isLoading: false,
              isInitializing: false,
              isFirstTime: isFirstTime,
              user: user,
              wallet: Wallet.fromJson(body['wallet']),
              recentTransactions: (body['recentTransactions'] as List)
                  .map((t) => Transaction.fromJson(t))
                  .toList(),
            );
            return;
          }
        } catch (e) {
          // Fetch error
        }
        
        state = state.copyWith(
          isLoading: false, 
          isInitializing: false,
          isAuthenticated: false, 
          isFirstTime: isFirstTime,
          user: lastUser['name'] != null ? User(
            id: 0, 
            fullname: lastUser['name']!, 
            email: lastUser['email']!, 
            phone: '', 
            status: '', 
            tier: '', 
            isVerified: false, 
            hasPin: true,
            userSettings: UserSetting(
              id: 0, 
              pinFingerprint: transBio, 
              passwordFingerprint: loginBio
            )
          ) : null,
        );
      } else {
        state = state.copyWith(
          isLoading: false, 
          isInitializing: false,
          isFirstTime: isFirstTime,
          shouldShowLogin: !hasAccount && !isFirstTime,
          user: hasAccount && lastUser['name'] != null ? User(
            id: 0, 
            fullname: lastUser['name']!, 
            email: lastUser['email']!, 
            phone: '', 
            status: '', 
            tier: '', 
            isVerified: false, 
            hasPin: true,
            userSettings: UserSetting(
              id: 0, 
              pinFingerprint: transBio, 
              passwordFingerprint: loginBio
            )
          ) : null,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, isInitializing: false);
    }
  }

  Future<void> completeOnboarding({bool toLogin = false}) async {
    await _sessionManager.setFirstTimeComplete();
    state = state.copyWith(
      isFirstTime: false, 
      shouldShowLogin: toLogin
    );
  }

  Future<bool> unlockWithPassword(String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final lastUser = await _sessionManager.getLastUser();
      final email = lastUser['email'];

      if (email == null) {
        state = state.copyWith(isLoading: false, error: 'User email not found');
        return false;
      }

      // Verify credentials
      final response = await _apiService.post('/login', data: {
        'email': email,
        'password': password,
      });

      if (response.data['responseSuccessful']) {
        final body = response.data['responseBody'];
        final token = body['accessToken'];
        final user = User.fromJson(body['user']);
        await _sessionManager.saveToken(token);
        
        if (user.userSettings?.passwordFingerprint == true) {
          await _sessionManager.savePassword(password);
        }
        
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          isLocked: false,
          user: User.fromJson(body['user']),
          wallet: Wallet.fromJson(body['wallet']),
          recentTransactions: (body['recentTransactions'] as List)
              .map((t) => Transaction.fromJson(t))
              .toList(),
        );
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: _getErrorMessage(response.data));
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> unlockWithBiometrics() async {
    final auth = LocalAuthentication();
    try {
      bool canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      final isEnabled = await _sessionManager.isLoginBiometricsEnabled();
      if (!canCheck || !isEnabled) return false;

      bool authenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to unlock ZeeData',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // More compatible with various devices
          useErrorDialogs: true,
        ),
      );

      if (!authenticated) return false;

      state = state.copyWith(isLoading: true, error: null);

      // Session verification
      final response = await _apiService.get('/profile');

      if (response.data['responseSuccessful']) {
        final body = response.data['responseBody'];
        
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          isLocked: false,
          user: User.fromJson(body['user']),
          wallet: Wallet.fromJson(body['wallet']),
          recentTransactions: (body['recentTransactions'] as List)
              .map((t) => Transaction.fromJson(t))
              .toList(),
        );
        return true;
      } else {
        // Token might be expired, try password login if we have it
        final storedPassword = await _sessionManager.getPassword();
        if (storedPassword != null) {
          return await unlockWithPassword(storedPassword);
        }

        await _sessionManager.clearBiometricEnrollment();
        state = state.copyWith(
          isLoading: false, 
          error: 'Session expired. Please login again with your password.',
          isAuthenticated: false,
          isLocked: false
        );
        return false;
      }
    } catch (e) {
      // If error contains Session expired, try password login
      if (e.toString().contains('Session expired') || e.toString().contains('Unauthenticated')) {
        final storedPassword = await _sessionManager.getPassword();
        if (storedPassword != null) {
          return await unlockWithPassword(storedPassword);
        }
        await _sessionManager.clearBiometricEnrollment();
      }
      state = state.copyWith(isLoading: false, error: 'Authentication failed: $e');
      return false;
    }
  }

  Future<String?> getStoredPin() async {
    final pin = await _sessionManager.getPin();
    if (pin != null) {
      // Success
    }
    return pin;
  }

  Future<void> saveStoredPin(String pin) async {
    await _sessionManager.savePin(pin);
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null, isAccountDeleted: false);
    try {
      final response = await _apiService.post('/login', data: {
        'email': email,
        'password': password,
      });

      if (response.data['responseSuccessful']) {
        final body = response.data['responseBody'];
        final token = body['accessToken'];
        final user = User.fromJson(body['user']);
        final wallet = Wallet.fromJson(body['wallet']);
        
        await _sessionManager.saveLastUser(user.fullname, user.email);
        await _sessionManager.saveToken(token);
        
        final loginBio = user.userSettings?.passwordFingerprint ?? false;
        final transBio = user.userSettings?.pinFingerprint ?? false;
        
        await _sessionManager.setLoginBiometricsEnabled(loginBio);
        await _sessionManager.setTransactionBiometricsEnabled(transBio);
        if (loginBio) {
          await _sessionManager.savePassword(password);
        }
        await _sessionManager.setFirstTimeComplete();
        
        // Login success

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          isLocked: false,
          user: user,
          wallet: wallet,
          recentTransactions: (body['recentTransactions'] as List)
              .map((t) => Transaction.fromJson(t))
              .toList(),
        );
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: _getErrorMessage(response.data));
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> register({
    required String fullname,
    required String email,
    required String phone,
    required String password,
    required String otp,
    String? pin,
    String? referralCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isAccountDeleted: false);
    try {
      final response = await _apiService.post('/register', data: {
        'fullname': fullname,
        'email': email,
        'phone': phone,
        'password': password,
        'otp': otp,
        'pin': pin,
        'referral_code': referralCode,
      });

      if (response.data['responseSuccessful']) {
        final body = response.data['responseBody'];
        final token = body['accessToken'];
        
        final user = User.fromJson(body['user']);
        await _sessionManager.saveLastUser(user.fullname, user.email);
        await _sessionManager.saveToken(token);
        
        await _sessionManager.setLoginBiometricsEnabled(user.userSettings?.passwordFingerprint ?? false);
        await _sessionManager.setTransactionBiometricsEnabled(user.userSettings?.pinFingerprint ?? false);
        if (user.userSettings?.passwordFingerprint == true) {
          await _sessionManager.savePassword(password);
        }
        await _sessionManager.setFirstTimeComplete();

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: user,
          wallet: Wallet.fromJson(body['wallet']),
          recentTransactions: [],
        );
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: _getErrorMessage(response.data));
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> sendRegistrationOtp(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.post('/registration/send-otp', data: {'email': email});
      if (response.data['responseSuccessful']) {
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: _getErrorMessage(response.data));
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _sessionManager.deleteToken();
    final lastUser = await _sessionManager.getLastUser();
    final loginBio = await _sessionManager.isLoginBiometricsEnabled();
    final transBio = await _sessionManager.isTransactionBiometricsEnabled();
    
    state = AuthState(
      isFirstTime: state.isFirstTime,
      user: lastUser['name'] != null ? User(
        id: 0, 
        fullname: lastUser['name']!, 
        email: lastUser['email']!, 
        phone: '', 
        status: '', 
        tier: '', 
        isVerified: false, 
        hasPin: true,
        userSettings: UserSetting(
          id: 0, 
          pinFingerprint: transBio, 
          passwordFingerprint: loginBio
        )
      ) : null,
      isAuthenticated: false,
      isLocked: true,
      isInitializing: false,
    );
  }

  Future<void> switchAccount() async {
    await _sessionManager.fullWipe();
    state = AuthState(
      isFirstTime: state.isFirstTime,
      shouldShowLogin: true,
      isInitializing: false,
    );
  }

  Future<bool> updateProfile({String? fullname, String? phone, String? imagePath}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _settingsService.updateProfile(
        fullname: fullname,
        phone: phone,
        imagePath: imagePath,
      );

      if (response['responseSuccessful']) {
        final body = response['responseBody'];
        state = state.copyWith(
          isLoading: false,
          user: User.fromJson(body['user']),
        );
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: _getErrorMessage(response));
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> setPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.post('/profile/set-pin', data: {
        'pin': pin,
        'pin_confirmation': pin,
      });

      if (response.data['responseSuccessful']) {
        final body = response.data['responseBody'];
        state = state.copyWith(
          isLoading: false,
          user: User.fromJson(body['user']),
        );
        await _sessionManager.savePin(pin); 
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: _getErrorMessage(response.data));
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _settingsService.changePassword(currentPassword, newPassword);
      if (response['responseSuccessful'] == true) {
        await _sessionManager.clearBiometricEnrollment();
        await logout();
        state = state.copyWith(
          isLoading: false,
          error: 'Password changed successfully. Please login with your new password.'
        );
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: response['responseMessage'] ?? 'Failed to change password');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> changePin(String currentPin, String newPin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.post('/profile/change-pin', data: {
        'current_pin': currentPin,
        'new_pin': newPin,
      });
      if (response.data['responseSuccessful']) {
        state = state.copyWith(isLoading: false);
        await _sessionManager.savePin(newPin); 
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: _getErrorMessage(response.data));
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> toggleBiometric(String type, bool enabled, {String? secret}) async {
    if (type == 'login') {
      state = state.copyWith(isLoginBioLoading: true, error: null);
    } else {
      state = state.copyWith(isTransBioLoading: true, error: null);
    }

    try {
      final response = await _settingsService.toggleBiometric(type, enabled);
      if (response['responseSuccessful']) {
        final body = response['responseBody'];
        final updatedUser = User.fromJson(body['user']);
        
        final loginBio = updatedUser.userSettings?.passwordFingerprint ?? false;
        final transBio = updatedUser.userSettings?.pinFingerprint ?? false;
        
        await _sessionManager.setLoginBiometricsEnabled(loginBio);
        await _sessionManager.setTransactionBiometricsEnabled(transBio);
        
        if (enabled && secret != null) {
          if (type == 'login') {
            await _sessionManager.savePassword(secret);
          } else {
            await _sessionManager.savePin(secret);
          }
        } else if (!enabled) {
          if (type == 'login') {
            await _sessionManager.deletePassword();
          } else {
            await _sessionManager.deletePin();
          }
        }
        
        state = state.copyWith(
          isLoginBioLoading: false,
          isTransBioLoading: false,
          user: updatedUser,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoginBioLoading: false,
          isTransBioLoading: false,
          error: _getErrorMessage(response),
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoginBioLoading: false,
        isTransBioLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    state = state.copyWith(isLoading: true, error: null, isAuthenticated: false);
    try {
      final response = await _settingsService.deleteAccount();
      if ((response['responseSuccessful'] == true) || (response['message'] == 'Account deleted')) {
        state = state.copyWith(isAuthenticated: false, isAccountDeleted: true, user: null, wallet: null);
        await _sessionManager.fullWipe();
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: _getErrorMessage(response));
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.post('/forgot-password', data: {'email': email});
      if (response.data['responseSuccessful']) {
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: _getErrorMessage(response.data));
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String confirmPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.post('/reset-password', data: {
        'email': email,
        'otp': otp,
        'password': password,
        'password_confirmation': confirmPassword,
      });
      if (response.data['responseSuccessful']) {
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: _getErrorMessage(response.data));
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final apiServiceProvider = Provider((ref) => ApiService());

final settingsServiceProvider = Provider((ref) => SettingsService(ref.watch(apiServiceProvider)));

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(apiServiceProvider),
    ref.watch(settingsServiceProvider),
  );
});
