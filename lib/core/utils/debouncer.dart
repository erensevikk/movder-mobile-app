import 'dart:async';

class Debouncer {
  Debouncer(this.duration);

  final Duration duration;
  Timer? _timer;

  void run(Future<void> Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, () async {
      await action();
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}
