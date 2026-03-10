import 'dart:async';

import 'package:flutter/foundation.dart';

import '../mixins/loading_state_mixin.dart';
import 'app_failure.dart';
import 'result.dart';
import 'view_effect.dart';

abstract class BaseViewModel extends ChangeNotifier with LoadingStateMixin {
  final StreamController<ViewEffect> _effectsController =
      StreamController<ViewEffect>.broadcast();

  Stream<ViewEffect> get effects => _effectsController.stream;

  Future<void> initialize() async {}

  Future<void> disposeViewModel() async {
    await _effectsController.close();
  }

  void emitEffect(ViewEffect effect) {
    if (!_effectsController.isClosed) {
      _effectsController.add(effect);
    }
  }

  void setLoading(bool value) {
    if (isLoading == value) return;
    isLoading = value;
    notifyListeners();
  }

  void setError(String? value) {
    if (errorMessage == value) return;
    errorMessage = value;
    notifyListeners();
  }

  Future<Result<T>> guard<T>(Future<Result<T>> Function() action) async {
    setError(null);
    setLoading(true);

    try {
      return await action();
    } catch (error, stackTrace) {
      debugPrint('ViewModel guard failed: $error\n$stackTrace');
      return Result.failure(
        AppFailure(
          message: 'Beklenmeyen bir hata oluştu.',
          detail: error,
        ),
      );
    } finally {
      setLoading(false);
    }
  }
}
