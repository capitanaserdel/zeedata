import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiUrl,
    connectTimeout: const Duration(seconds: 90),
    receiveTimeout: const Duration(seconds: 90),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ));

  final _storage = const FlutterSecureStorage();

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        print("🌐 API REQUEST [${options.method}] → ${options.uri}");
        if (options.data != null) print("📦 BODY → ${options.data}");
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print("✅ API RESPONSE [${response.statusCode}] → ${response.data}");
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        print("❌ API ERROR [${e.response?.statusCode}] → ${e.response?.data ?? e.message}");
        return handler.next(e);
      },
    ));
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(String path, {dynamic data}) async {
    try {
      return await _dio.delete(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection. Please check your data.';
    }

    if (e.response != null) {
      final data = e.response?.data;
      if (data is Map) {
        if (data.containsKey('responseMessage')) {
          return data['responseMessage'];
        }
        if (data.containsKey('message')) {
          return data['message'];
        }
        if (data.containsKey('errors')) {
          // Flatten Laravel validation errors if present
          final errors = data['errors'];
          if (errors is Map) {
            return errors.values.first.first.toString();
          }
        }
      }
      if (e.response?.statusCode == 401) return 'Session expired. Please login again.';
      if (e.response?.statusCode == 403) return 'Access denied.';
      if ((e.response?.statusCode ?? 0) >= 500) return 'Server error. Please try again later.';
    }
    return 'An unexpected error occurred. Please try again.';
  }
}
