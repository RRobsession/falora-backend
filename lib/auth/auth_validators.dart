class AuthValidators {
  AuthValidators._();

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'İsim gerekli';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'E-posta gerekli';
    }
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Geçerli bir e-posta girin';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Şifre gerekli';
    }
    if (value.length < 6) {
      return 'Şifre en az 6 karakter olmalı';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Şifre tekrarı gerekli';
    }
    if (value != password) {
      return 'Şifreler eşleşmiyor';
    }
    return null;
  }
}
