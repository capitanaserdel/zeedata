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
      debugPrint('🔔 AuthState Changed: isAuthenticated=${state.isAuthenticated}, isAccountDeleted=${state.isAccountDeleted}, isLoading=${state.isLoading}');
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
      print("❌ Fetch Transactions Error: $e");
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
      print("❌ Refresh Error: $e");
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
      
      print("🔍 AUTH CHECK: Token: ${token != null}, LoginBio: $loginBio, TransBio: $transBio");
      
      if (token != null) {
        final response = await _apiService.get('/profile');
        if (response.data['responseSuccessful']) {
          final body = response.data['responseBody'];
          final user = User.fromJson(body['user']);
          
          // Sync with local storage
          await _sessionManager.setLoginBiometricsEnabled(user.userSettings?.passwordFingerprint ?? false);
          await _sessionManager.setTransactionBiometricsEnabled(user.userSettings?.pinFingerprint ?? false);
          
          state = state.copyWith(
            isAuthenticated: true,
            isLocked: true,
            isLoading: false,
            isFirstTime: isFirstTime,
            user: user,
            wallet: Wallet.fromJson(body['wallet']),
            recentTransactions: (body['recentTransactions'] as List)
                .map((t) => Transaction.fromJson(t))
                .toList(),
          );
        } else {
          // Token expired or invalid
          state = state.copyWith(
            isLoading: false, 
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
        }
      } else {
        state = state.copyWith(
          isLoading: false, 
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
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
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

      print("🌐 LOCK SCREEN: CALLING LOGIN API FOR PWORD ");
      final response = await _apiService.post('/login', data: {
        'email': email,
        'password': password,
      });

      if (response.data['responseSuccessful']) {
        final body = response.data['responseBody'];
        final token = body['accessToken'];
        await _sessionManager.saveToken(token);
        
        // Also update the secure store to keep it fresh
        await _sessionManager.savePassword(password);

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
      final isEnabled = state.user?.userSettings?.passwordFingerprint ?? false;
      if (!canCheck || !isEnabled) return false;

      // 1. Local biometric check
      bool authenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to unlock ZeeData',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );

      if (!authenticated) return false;

      // 2. Retrieve stored credentials for API auth
      final lastUser = await _sessionManager.getLastUser();
      final savedPassword = await _sessionManager.getPassword();
      
      if (lastUser['email'] == null || savedPassword == null) {
        state = state.copyWith(error: 'Biometric login requires previous password login');
        return false;
      }

      state = state.copyWith(isLoading: true, error: null);

      // 3. Real Backend Authentication
      print("🌐 LOCK SCREEN: CALLING LOGIN API FOR BIOMETRIC AUTH");
      final response = await _apiService.post('/login', data: {
        'email': lastUser['email'],
        'password': savedPassword,
      });

      if (response.data['responseSuccessful']) {
        final body = response.data['responseBody'];
        final token = body['accessToken'];
        await _sessionManager.saveToken(token);

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
        state = state.copyWith(isLoading: false, error: 'Biometric auth failed on server');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<String?> getStoredPin() async {
    final pin = await _sessionManager.getPin();
    if (pin != null) {
      print("🔐 Biometric success → PIN retrieved");
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
        
        // Save user info for Welcome Back
        await _sessionManager.saveLastUser(user.fullname, user.email);
        await _sessionManager.saveToken(token);
        await _sessionManager.savePassword(password);
        
        final loginBio = user.userSettings?.passwordFingerprint ?? false;
        final transBio = user.userSettings?.pinFingerprint ?? false;
        
        await _sessionManager.setLoginBiometricsEnabled(loginBio);
        await _sessionManager.setTransactionBiometricsEnabled(transBio);
        await _sessionManager.setFirstTimeComplete();
        
        print("🔑 LOGIN SUCCESS - BIO STATE: LOGIN=$loginBio, TRANS=$transBio");

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
    String? pin,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isAccountDeleted: false);
    try {
      final response = await _apiService.post('/register', data: {
        'fullname': fullname,
        'email': email,
        'phone': phone,
        'password': password,
        'pin': pin,
      });

      if (response.data['responseSuccessful']) {
        final body = response.data['responseBody'];
        final token = body['accessToken'];
        
        final user = User.fromJson(body['user']);
        await _sessionManager.saveLastUser(user.fullname, user.email);
        await _sessionManager.saveToken(token);
        await _sessionManager.savePassword(password);
        await _sessionManager.setLoginBiometricsEnabled(user.userSettings?.passwordFingerprint ?? false);
        await _sessionManager.setTransactionBiometricsEnabled(user.userSettings?.pinFingerprint ?? false);
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
    );
  }

  Future<void> switchAccount() async {
    await _sessionManager.fullWipe();
    state = AuthState(
      isFirstTime: state.isFirstTime,
      shouldShowLogin: true,
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
        await _sessionManager.savePin(pin); // Save locally for biometrics
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
      state = state.copyWith(isLoading: false);
      return response['responseSuccessful'] ?? false;
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
        await _sessionManager.savePin(newPin); // Update local store
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

  Future<bool> toggleBiometric(String type, bool enabled) async {
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
        
        print("📲 BIOMETRIC SYNC ($type) - API Response: Login=$loginBio, Trans=$transBio");
        print("📲 BIOMETRIC SYNC ($type) - UI State: Login=${state.loginBioEnabled}, Trans=${state.transBioEnabled}");
        
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
        debugPrint('🧹 Wiping session and setting isAccountDeleted=true');
        await _sessionManager.fullWipe();
        state = AuthState(isFirstTime: false, isAccountDeleted: true);
        debugPrint('✅ State set: isAccountDeleted=${state.isAccountDeleted}');
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
