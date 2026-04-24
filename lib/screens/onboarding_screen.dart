import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Fast & Reliable\nVTU Services',
      description: 'Buy airtime, data, and pay bills instantly with zero delays. Experience speed like never before.',
      icon: Icons.bolt_rounded,
      color: const Color(0xFF011B60),
    ),
    OnboardingData(
      title: 'Airtime to Cash\nIn Seconds',
      description: 'Convert your excess airtime to real cash in your wallet. Fast, secure, and hassle-free.',
      icon: Icons.currency_exchange_rounded,
      color: const Color(0xFF041F62),
    ),
    OnboardingData(
      title: 'Secure & Smart\nFintech Wallet',
      description: 'Your funds are protected with bank-grade security. Manage your wealth with total peace of mind.',
      icon: Icons.shield_moon_rounded,
      color: const Color(0xFF021241),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Decor
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pages[_currentPage].color.withOpacity(0.03),
              ),
            ),
          ),
          
          Column(
            children: [
              Expanded(
                flex: 3,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _OnboardingPage(data: _pages[index], isTablet: isTablet);
                  },
                ),
              ),
              
              // Bottom Section
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? size.width * 0.2 : 32.0,
                  vertical: 40.0,
                ),
                child: Column(
                  children: [
                    // Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 32 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _currentPage == index 
                                ? _pages[_currentPage].color 
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // Main Action Button (Continue / Create Account)
                    Consumer(builder: (context, ref, child) {
                      return ElevatedButton(
                        onPressed: () {
                          if (_currentPage < _pages.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutQuint,
                            );
                          } else {
                            ref.read(authProvider.notifier).completeOnboarding(toLogin: false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pages[_currentPage].color,
                          minimumSize: const Size(double.infinity, 64),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: Text(
                          _currentPage == _pages.length - 1 ? 'Create Account' : 'Continue',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      );
                    }),
                    
                    const SizedBox(height: 16),
                    
                    // Login Instead Button (LAST SCREEN ONLY)
                    if (_currentPage == _pages.length - 1)
                      Consumer(builder: (context, ref, child) {
                        return TextButton(
                          onPressed: () => ref.read(authProvider.notifier).completeOnboarding(toLogin: true),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text(
                            'Log In Instead',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        );
                      })
                    else
                      const SizedBox(height: 50), // Maintain layout consistency
                  ],
                ),
              ),
            ],
          ),

          // Skip Button (Top Right) - Placed last in Stack to be on top
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Consumer(builder: (context, ref, child) {
                return TextButton(
                  onPressed: () => ref.read(authProvider.notifier).completeOnboarding(toLogin: false),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _OnboardingPage extends StatelessWidget {
  final OnboardingData data;
  final bool isTablet;
  const _OnboardingPage({required this.data, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          // Animated Illustration Placeholder
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: isTablet ? 300 : 220,
                height: isTablet ? 300 : 220,
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: isTablet ? 220 : 160,
                height: isTablet ? 220 : 160,
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
              Icon(
                data.icon,
                size: isTablet ? 120 : 80,
                color: data.color,
              ),
            ],
          ),
          const SizedBox(height: 60),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isTablet ? 36 : 30,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E293B),
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              color: const Color(0xFF64748B),
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
