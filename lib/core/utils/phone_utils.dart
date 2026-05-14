class PhoneUtils {
  /// Cleans a phone number by removing all non-numeric characters.
  /// Handles the +234 prefix by converting it to 0 for local compatibility
  /// or preserving it if international format is required.
  static String formatPhoneNumber(String phone) {
    // Remove all non-digits
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');

    if (cleaned.startsWith('234')) {
      // Convert 23480... to 080...
      cleaned = '0${cleaned.substring(3)}';
    } else if (cleaned.startsWith('009234')) {
      // Handle rare 009 prefix
      cleaned = '0${cleaned.substring(6)}';
    }

    // Basic validation: Nigerian numbers are usually 11 digits starting with 0
    // or 10 digits if we strip the leading 0.
    // If it's 10 digits and doesn't start with 0, add 0.
    if (cleaned.length == 10 && !cleaned.startsWith('0')) {
      cleaned = '0$cleaned';
    }

    return cleaned;
  }

  /// Basic validation for Nigerian phone numbers
  static bool isValidNigerianNumber(String phone) {
    String cleaned = formatPhoneNumber(phone);
    return RegExp(r'^0[789][01]\d{8}$').hasMatch(cleaned);
  }
}
