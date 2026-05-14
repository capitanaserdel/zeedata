import 'package:flutter/foundation.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import '../core/utils/phone_utils.dart';

class ContactPickerResult {
  final String? name;
  final String? phoneNumber;
  final bool success;
  final String? error;

  ContactPickerResult({
    this.name,
    this.phoneNumber,
    this.success = true,
    this.error,
  });
}

class ContactService {
  final FlutterNativeContactPicker _contactPicker = FlutterNativeContactPicker();

  /// Opens the native contact picker and returns a single selected contact.
  /// This implementation is Google Play Store compliant as it uses the 
  /// native system intent and does not require broad READ_CONTACTS permission.
  Future<ContactPickerResult> pickContact() async {
    try {
      final Contact? contact = await _contactPicker.selectContact();
      
      if (contact == null) {
        return ContactPickerResult(success: false, error: 'No contact selected');
      }

      // The package returns a list of phone numbers for a contact
      if (contact.phoneNumbers == null || contact.phoneNumbers!.isEmpty) {
        return ContactPickerResult(
          name: contact.fullName,
          success: false, 
          error: 'Contact has no phone number'
        );
      }

      // Pick the first phone number available
      String rawNumber = contact.phoneNumbers!.first;
      String formattedNumber = PhoneUtils.formatPhoneNumber(rawNumber);

      return ContactPickerResult(
        name: contact.fullName,
        phoneNumber: formattedNumber,
        success: true,
      );
    } catch (e) {
      debugPrint('❌ Error picking contact: $e');
      return ContactPickerResult(
        success: false, 
        error: 'Failed to open contact picker: ${e.toString()}'
      );
    }
  }
}
