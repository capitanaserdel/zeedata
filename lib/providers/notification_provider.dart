import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_data.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class NotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;

  NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final ApiService _api;
  final Ref _ref;
  Timer? _pollingTimer;

  NotificationNotifier(this._api, this._ref) : super(NotificationState()) {
    startPolling();
  }

  void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      fetchUnreadCount();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _api.get('/notifications');
      final responseData = response.data;
      if (responseData['responseSuccessful']) {
        final List data = responseData['responseBody']['notifications']['data'];
        final notifications = data.map((e) => AppNotification.fromJson(e)).toList();
        state = state.copyWith(notifications: notifications, isLoading: false);
        fetchUnreadCount();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final response = await _api.get('/notifications/unread-count');
      final responseData = response.data;
      if (responseData['responseSuccessful']) {
        final newCount = responseData['responseBody']['count'];
        
        // IF WE HAVE NEW UNREAD NOTIFICATIONS, RELOAD DASHBOARD (Balance/Transactions)
        if (newCount > state.unreadCount) {
          debugPrint('🔔 NEW NOTIFICATION DETECTED: Refreshing Dashboard...');
          _ref.read(authProvider.notifier).refreshProfile();
        }
        
        state = state.copyWith(unreadCount: newCount);
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      final response = await _api.post('/notifications/$id/mark-as-read', data: {});
      final responseData = response.data;
      if (responseData['responseSuccessful']) {
        final updated = state.notifications.map((n) {
          if (n.id == id) {
            return AppNotification(
              id: n.id,
              title: n.title,
              message: n.message,
              type: n.type,
              readAt: DateTime.now(),
              createdAt: n.createdAt,
            );
          }
          return n;
        }).toList();
        state = state.copyWith(
          notifications: updated,
          unreadCount: (state.unreadCount - 1).clamp(0, 999),
        );
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final response = await _api.post('/notifications/mark-all-as-read', data: {});
      final responseData = response.data;
      if (responseData['responseSuccessful']) {
        final updated = state.notifications.map((n) {
          return AppNotification(
            id: n.id,
            title: n.title,
            message: n.message,
            type: n.type,
            readAt: DateTime.now(),
            createdAt: n.createdAt,
          );
        }).toList();
        state = state.copyWith(notifications: updated, unreadCount: 0);
      }
    } catch (e) {
      // Ignore
    }
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return NotificationNotifier(api, ref);
});
