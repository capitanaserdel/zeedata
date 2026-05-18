import 'package:flutter/foundation.dart';
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
        
        if (kDebugMode) {
          debugPrint('\n==================== 🚀 API REQUEST ====================');
          debugPrint('🌐 URL: [${options.method}] ${options.uri}');
          debugPrint('📁 Headers: ${options.headers}');
          if (options.data != null) {
            debugPrint('✉️ Request Body: ${options.data}');
          }
          debugPrint('========================================================');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          debugPrint('\n==================== ✅ API RESPONSE ====================');
          debugPrint('🌐 URL: [${response.requestOptions.method}] ${response.requestOptions.uri}');
          debugPrint('🚨 Status Code: ${response.statusCode}');
          debugPrint('📦 Response Payload:');
          _logLongString(response.data.toString());
          debugPrint('========================================================');
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        if (kDebugMode) {
          debugPrint('\n==================== ❌ API ERROR =====================');
          debugPrint('🌐 URL: [${e.requestOptions.method}] ${e.requestOptions.uri}');
          debugPrint('🚨 Status Code: ${e.response?.statusCode}');
          debugPrint('🚨 Error Type: ${e.type}');
          debugPrint('💬 Error Message: ${e.message}');
          if (e.response?.data != null) {
            debugPrint('📦 Error Response Body: ${e.response?.data}');
          }
          debugPrint('========================================================');
        }
        return handler.next(e);
      },
    ));
  }

  void _logLongString(String text) {
    if (kDebugMode) {
      final pattern = RegExp('.{1,800}');
      pattern.allMatches(text).forEach((match) => debugPrint(match.group(0)));
    }
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
