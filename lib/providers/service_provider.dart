import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

class ServiceStatus {
  final int id;
  final String name;
  final String type;
  final bool isActive;

  ServiceStatus({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
  });

  factory ServiceStatus.fromJson(Map<String, dynamic> json) {
    return ServiceStatus(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }
}

class ServiceState {
  final List<ServiceStatus> services;
  final bool isLoading;
  final String? error;

  ServiceState({
    this.services = const [],
    this.isLoading = false,
    this.error,
  });

  ServiceState copyWith({
    List<ServiceStatus>? services,
    bool? isLoading,
    String? error,
  }) {
    return ServiceState(
      services: services ?? this.services,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ServiceNotifier extends StateNotifier<ServiceState> {
  final ApiService _apiService = ApiService();

  ServiceNotifier() : super(ServiceState()) {
    fetchServices();
  }

  Future<void> fetchServices() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiService.get('/services');
      final List<dynamic> data = response.data['data'];
      final services = data.map((s) => ServiceStatus.fromJson(s)).toList();
      state = state.copyWith(services: services, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  bool isServiceActive(String type) {
    if (state.services.isEmpty) return true; // Default to active if not loaded yet
    final service = state.services.where((s) => s.type.toUpperCase() == type.toUpperCase()).firstOrNull;
    return service?.isActive ?? true;
  }
}

final serviceProvider = StateNotifierProvider<ServiceNotifier, ServiceState>((ref) {
  return ServiceNotifier();
});
