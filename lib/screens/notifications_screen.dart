import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/notification_provider.dart';
import '../core/theme/app_colors.dart';
import '../widgets/custom_loader.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (notificationState.unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationProvider.notifier).markAllAsRead(),
              child: const Text('Mark all as read', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => ref.read(notificationProvider.notifier).fetchNotifications(),
            color: AppColors.primary,
            child: notificationState.notifications.isEmpty && !notificationState.isLoading
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    itemCount: notificationState.notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notificationState.notifications[index];
                      return _buildNotificationTile(notification);
                    },
                  ),
          ),
          if (notificationState.isLoading && notificationState.notifications.isEmpty)
            const CustomLoader(message: 'Loading alerts...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                child: const Icon(Icons.notifications_none_rounded, size: 80, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 24),
              const Text('All caught up!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              const Text('Your alerts and messages will appear here.', style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationTile(dynamic notification) {
    bool isRead = notification.isRead;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (!isRead) {
            ref.read(notificationProvider.notifier).markAsRead(notification.id);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : const Color(0xFFF1F5F9).withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: isRead ? Border.all(color: const Color(0xFFE2E8F0)) : Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: _getIconColor(notification.type).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIcon(notification.type), color: _getIconColor(notification.type), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isRead ? FontWeight.bold : FontWeight.w900,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('hh:mm a').format(notification.createdAt),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: isRead ? const Color(0xFF64748B) : const Color(0xFF1E293B),
                        fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('MMM dd, yyyy').format(notification.createdAt),
                      style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type.toUpperCase()) {
      case 'SUCCESS':
        return Icons.check_circle_rounded;
      case 'WARNING':
        return Icons.warning_rounded;
      case 'ERROR':
        return Icons.error_rounded;
      case 'SECURITY':
        return Icons.security_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _getIconColor(String type) {
    switch (type.toUpperCase()) {
      case 'SUCCESS':
        return const Color(0xFF10B981);
      case 'WARNING':
        return const Color(0xFFF59E0B);
      case 'ERROR':
        return const Color(0xFFEF4444);
      case 'SECURITY':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF3B82F6);
    }
  }
}
