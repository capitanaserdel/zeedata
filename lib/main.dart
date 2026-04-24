import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/create_pin_screen.dart';
import 'screens/registration_screen.dart';

void main() {
  runApp(const ProviderScope(child: ZeeDataApp()));
}

class ZeeDataApp extends ConsumerWidget {
  const ZeeDataApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      key: ValueKey('${authState.isAuthenticated}_${authState.isAccountDeleted}'),
      title: 'Zee Data',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _getHome(authState),
    );
  }

  Widget _getHome(AuthState authState) {
    if (authState.isLoading) {
      debugPrint('🏠 Routing to: SplashScreen');
      return const SplashScreen();
    }
    
    if (authState.isAccountDeleted) {
      debugPrint('🏠 Routing to: RegistrationScreen (Account Deleted)');
      return const RegistrationScreen();
    }
    
    if (authState.isFirstTime) {
      debugPrint('🏠 Routing to: OnboardingScreen');
      return const OnboardingScreen();
    }
    
    if (authState.isAuthenticated) {
      if (authState.isLocked) {
        debugPrint('🏠 Routing to: LockScreen');
        return const LockScreen();
      }
      if (authState.user != null && !authState.user!.hasPin) {
        debugPrint('🏠 Routing to: CreatePinScreen');
        return const CreatePinScreen();
      }
      debugPrint('🏠 Routing to: MainScreen');
      return const MainScreen();
    }

    // If we have user data (returning user), show the Lock Screen
    if (authState.user != null) {
      debugPrint('🏠 Routing to: LockScreenFallback');
      return const LockScreen();
    }

    if (authState.shouldShowLogin) {
      debugPrint('🏠 Routing to: LoginScreen');
      return const LoginScreen();
    }

    // Default to registration for new users who finished onboarding
    debugPrint('🏠 Routing to: RegistrationScreen');
    return const RegistrationScreen();
  }
}
