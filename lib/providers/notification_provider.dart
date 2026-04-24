import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class NotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final ApiService _apiService;

  NotificationNotifier(this._apiService) : super(NotificationState()) {
    fetchUnreadCount();
  }

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.get('/notifications');
      if (response.data['responseSuccessful']) {
        final List data = response.data['responseBody']['notifications']['data'];
        final notifications = data.map((n) => AppNotification.fromJson(n)).toList();
        state = state.copyWith(
          notifications: notifications,
          isLoading: false,
        );
        fetchUnreadCount();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final response = await _apiService.get('/notifications/unread-count');
      if (response.data['responseSuccessful']) {
        state = state.copyWith(unreadCount: response.data['responseBody']['count']);
      }
    } catch (e) {
      print("❌ Unread Count Error: $e");
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      final response = await _apiService.post('/notifications/$id/mark-as-read');
      if (response.data['responseSuccessful']) {
        final updatedNotifications = state.notifications.map((n) {
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
          notifications: updatedNotifications,
          unreadCount: (state.unreadCount - 1).clamp(0, 999),
        );
      }
    } catch (e) {
      print("❌ Mark Read Error: $e");
    }
  }

  Future<void> markAllAsRead() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiService.post('/notifications/mark-all-as-read');
      if (response.data['responseSuccessful']) {
        final updatedNotifications = state.notifications.map((n) {
          return AppNotification(
            id: n.id,
            title: n.title,
            message: n.message,
            type: n.type,
            readAt: DateTime.now(),
            createdAt: n.createdAt,
          );
        }).toList();
        state = state.copyWith(
          notifications: updatedNotifications,
          unreadCount: 0,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref.watch(apiServiceProvider));
});
