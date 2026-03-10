class AppFailure {
  const AppFailure({
    required this.message,
    this.code,
    this.detail,
  });

  final String message;
  final String? code;
  final Object? detail;
}
