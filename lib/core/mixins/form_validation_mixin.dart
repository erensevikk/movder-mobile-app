mixin FormValidationMixin {
  final Map<String, String?> fieldErrors = <String, String?>{};

  String? errorFor(String key) => fieldErrors[key];

  void setFieldError(String key, String? value) {
    fieldErrors[key] = value;
  }

  void clearFieldError(String key) {
    fieldErrors.remove(key);
  }

  void clearFieldErrors() {
    fieldErrors.clear();
  }
}
