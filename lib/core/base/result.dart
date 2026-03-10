import 'app_failure.dart';

class Result<T> {
  const Result._({
    this.data,
    this.failure,
  });

  const Result.success(T data) : this._(data: data);

  const Result.failure(AppFailure failure) : this._(failure: failure);

  final T? data;
  final AppFailure? failure;

  bool get isSuccess => failure == null;
  bool get isFailure => failure != null;
}
