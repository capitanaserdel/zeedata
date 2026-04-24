import 'package:dio/dio.dart';
import 'api_service.dart';

class SettingsService {
  final ApiService _apiService;

  SettingsService(this._apiService);

  Future<Map<String, dynamic>> updateProfile({String? fullname, String? phone, String? imagePath}) async {
    dynamic data;
    if (imagePath != null) {
      data = FormData.fromMap({
        if (fullname != null) 'fullname': fullname,
        if (phone != null) 'phone': phone,
        'picture': await MultipartFile.fromFile(imagePath),
      });
    } else {
      data = {
        if (fullname != null) 'fullname': fullname,
        if (phone != null) 'phone': phone,
      };
    }

    final response = await _apiService.post('/profile/update', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    final response = await _apiService.post('/profile/change-password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
      'new_password_confirmation': newPassword,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> changePin(String currentPin, String newPin) async {
    final response = await _apiService.post('/profile/change-pin', data: {
      'current_pin': currentPin,
      'new_pin': newPin,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> toggleBiometric(String type, bool enabled) async {
    final response = await _apiService.post('/profile/toggle-biometric', data: {
      'type': type,
      'enabled': enabled,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    final response = await _apiService.delete('/account');
    return response.data;
  }
}
