import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'electricity_screen.dart';
import 'notifications_screen.dart';
import '../providers/notification_provider.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import 'airtime_screen.dart';
import 'data_screen.dart';
import 'profile_screen.dart';
import 'fund_wallet_screen.dart';
import 'transaction_detail_screen.dart';
import 'airtime_to_cash_screen.dart';
import 'transactions_screen.dart';
import 'cable_tv_screen.dart';
import 'bulk_sms_screen.dart';
import 'education_screen.dart';
import 'recharge_pin_screen.dart';
import '../widgets/user_avatar.dart';
import '../models/user_data.dart' as model;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final wallet = authState.wallet;
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final horizontalPadding = screenWidth * 0.05; // 5% padding

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(authProvider.notifier).refreshProfile();
            await ref.read(notificationProvider.notifier).fetchUnreadCount();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Premium Header
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 10),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good Day,',
                            style: TextStyle(fontSize: isTablet ? 16 : 14, color: Colors.blueGrey[400], fontWeight: FontWeight.w500),
                          ),
                          Text(
                            user?.fullname.split(' ').first ?? 'User',
                            style: TextStyle(fontSize: isTablet ? 28 : 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Consumer(
                            builder: (context, ref, child) {
                              final unreadCount = ref.watch(notificationProvider).unreadCount;
                              return GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                                        ],
                                      ),
                                      child: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary, size: 20),
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        top: -2,
                                        right: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                          child: Text(
                                            unreadCount > 9 ? '9+' : '$unreadCount',
                                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                            child: UserAvatar(
                              name: user?.fullname ?? 'User',
                              imageUrl: user?.picture,
                              radius: isTablet ? 24 : 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Wallet Card
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isTablet ? 500 : double.infinity),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isTablet ? 36 : 28),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF041F62), Color(0xFF0A3D91), Color(0xFF00BFFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF041F62).withOpacity(0.4),
                              blurRadius: 25,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: isTablet ? 16 : 14, fontWeight: FontWeight.w600)),
                                GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FundWalletScreen())),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                                    child: Icon(Icons.add_rounded, color: Colors.white, size: isTablet ? 24 : 20),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currencyFormat.format(wallet?.balance ?? 0),
                              style: TextStyle(color: Colors.white, fontSize: isTablet ? 48 : 36, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 12),

                            if (user?.virtualAccount != null) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (user?.virtualAccount?.bankName ?? 'PALMPAY').toUpperCase(),
                                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: isTablet ? 12 : 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          user?.virtualAccount?.accountNumber ?? '0000000000',
                                          style: TextStyle(color: Colors.white, fontSize: isTablet ? 18 : 16, fontWeight: FontWeight.w800, letterSpacing: 1),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: user?.virtualAccount?.accountNumber ?? ''));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text('Account Number Copied!'),
                                            backgroundColor: AppColors.primary,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                        child: Icon(Icons.copy_rounded, color: Colors.white, size: isTablet ? 20 : 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Quick Actions
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
                sliver: const SliverToBoxAdapter(
                  child: Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                ),
              ),

              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isTablet ? 6 : 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.7,
                  ),
                  delegate: SliverChildListDelegate([
                    _QuickAction(
                      icon: Icons.phone_android_rounded,
                      label: 'Airtime',
                      color: const Color(0xFFEEF2FF),
                      iconColor: const Color(0xFF6366F1),
                      isTablet: isTablet,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AirtimeScreen())),
                    ),
                    _QuickAction(
                      icon: Icons.wifi_rounded,
                      label: 'Data',
                      color: const Color(0xFFF0FDF4),
                      iconColor: const Color(0xFF22C55E),
                      isTablet: isTablet,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DataScreen())),
                    ),
                    _QuickAction(
                      icon: Icons.swap_horizontal_circle_rounded,
                      label: 'Airtime to cash',
                      color: const Color(0xFFFFF7ED),
                      iconColor: const Color(0xFFF97316),
                      isTablet: isTablet,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AirtimeToCashScreen())),
                    ),
                    _QuickAction(
                      icon: Icons.tv_rounded,
                      label: 'Cable',
                      color: const Color(0xFFF5F3FF),
                      iconColor: const Color(0xFF8B5CF6),
                      isTablet: isTablet,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CableTVScreen())),
                    ),
                    _QuickAction(
                      icon: Icons.sms_rounded,
                      label: 'SMS',
                      color: const Color(0xFFFFF7ED),
                      iconColor: const Color(0xFFF97316),
                      isTablet: isTablet,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BulkSMSScreen())),
                    ),
                    _QuickAction(
                      icon: Icons.school_rounded,
                      label: 'Education',
                      color: const Color(0xFFF0FDF4),
                      iconColor: const Color(0xFF10B981),
                      isTablet: isTablet,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EducationScreen())),
                    ),
                    _QuickAction(
                      icon: Icons.vibration_rounded,
                      label: 'RPIN',
                      color: const Color(0xFFEEF2FF),
                      iconColor: const Color(0xFF6366F1),
                      isTablet: isTablet,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RechargePinScreen())),
                    ),
                    _QuickAction(
                      icon: Icons.electric_bolt_rounded,
                      label: 'Electricity',
                      color: const Color(0xFFFFFBEB),
                      iconColor: const Color(0xFFF59E0B),
                      isTablet: isTablet,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ElectricityScreen())),
                    ),
                  ]),
                ),
              ),

              // Transactions Header
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding + 4, 32, horizontalPadding + 4, 10),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TransactionsScreen())),
                        child: const Text('See All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),

              // Transactions List
              if (authState.recentTransactions.isEmpty)
                const SliverToBoxAdapter(
                  child: Center(child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Column(
                      children: [
                        Icon(Icons.history_rounded, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No transactions yet', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tx = authState.recentTransactions[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: _TransactionItem(transaction: tx),
                        ),
                      );
                    },
                    childCount: authState.recentTransactions.length > 2 ? 2 : authState.recentTransactions.length,
                  ),
                ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required bool isTablet, required VoidCallback onTap}) {
    return Expanded(
      child: Material(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: isTablet ? 22 : 18),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isTablet ? 15 : 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final bool isTablet;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
          child: Container(
            height: isTablet ? 80 : 60,
            width: isTablet ? 80 : 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
            ),
            child: Icon(icon, color: iconColor, size: isTablet ? 36 : 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: isTablet ? 13 : 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final model.Transaction transaction;
  const _TransactionItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TransactionDetailScreen(transaction: transaction),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: transaction.isCredit ? Colors.green[50] : Colors.red[50],
          child: Icon(
            transaction.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: transaction.isCredit ? Colors.green : Colors.red,
            size: 18,
          ),
        ),
        title: Text(transaction.serviceType, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(DateFormat('MMM dd, hh:mm a').format(transaction.createdAt)),
        trailing: Text(
          '${transaction.isCredit ? "+" : "-"}₦${transaction.amount}',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: transaction.isCredit ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }
}
