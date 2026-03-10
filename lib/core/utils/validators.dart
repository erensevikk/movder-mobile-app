class Validators {
  static String? required(String value, String message) {
    return value.trim().isEmpty ? message : null;
  }

  static String? minLength(
    String value, {
    required int min,
    required String message,
  }) {
    return value.trim().length < min ? message : null;
  }

  static String? email(String value) {
    if (value.trim().isEmpty) {
      return 'E-posta zorunlu.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    return null;
  }

  static String? password(String value) {
    if (value.isEmpty) {
      return 'Şifre zorunlu.';
    }
    if (value.length < 6) {
      return 'Şifre en az 6 karakter olmalı.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Şifre en az 1 büyük harf içermeli.';
    }
    return null;
  }
}
