class AppValidators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length != 6) {
      return 'Password must be exactly 6 digits';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'Password must contain only digits';
    }

    // Reject weak patterns
    final weakPatterns = ['000000', '111111', '222222', '333333', '444444', '555555', '666666', '123456', '654321'];
    if (weakPatterns.contains(value)) {
      return 'Please choose a stronger password';
    }

    // Reject sequential or highly repeated numbers
    if (_isSequential(value) || _isRepeated(value)) {
      return 'Pattern is too weak. Avoid sequential or repeated numbers.';
    }

    return null;
  }

  static String? validatePin(String? value) {
    if (value == null || value.isEmpty) {
      return 'PIN is required';
    }
    if (value.length != 4) {
      return 'PIN must be exactly 4 digits';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'PIN must contain only digits';
    }

    // Reject weak patterns
    final weakPatterns = ['0000', '1111', '2222', '3333', '1234', '4321', '000000', '111111', '123456'];
    if (weakPatterns.contains(value)) {
      return 'Please choose a stronger PIN';
    }

    // Reject sequential numbers
    if (_isSequential(value)) {
      return 'Sequential numbers are not allowed';
    }

    // Reject repeated digits
    if (_isRepeated(value)) {
      return 'Repeated digits are not allowed';
    }

    return null;
  }

  static bool _isSequential(String value) {
    for (int i = 0; i < value.length - 2; i++) {
      int d1 = int.parse(value[i]);
      int d2 = int.parse(value[i + 1]);
      int d3 = int.parse(value[i + 2]);
      if ((d1 + 1 == d2 && d2 + 1 == d3) || (d1 - 1 == d2 && d2 - 1 == d3)) {
        return true;
      }
    }
    return false;
  }

  static bool _isRepeated(String value) {
    for (int i = 0; i < value.length - 2; i++) {
      if (value[i] == value[i + 1] && value[i + 1] == value[i + 2]) {
        return true;
      }
    }
    return false;
  }

  static String? validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().split(' ').length < 2) {
      return 'Please enter at least two names';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length < 11) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  static String? validateAmount(String? value, double balance) {
    if (value == null || value.isEmpty) {
      return 'Amount is required';
    }
    final amount = double.tryParse(value);
    if (amount == null || amount <= 0) {
      return 'Enter a valid amount';
    }
    if (amount > balance) {
      return 'Insufficient wallet balance';
    }
    return null;
  }
}
