import '../core/base/base_view_model.dart';

class AppShellViewModel extends BaseViewModel {
  int currentIndex = 0;
  int chatRefreshSignal = 0;

  void selectTab(int index) {
    if (index == 2 && currentIndex != 2) {
      chatRefreshSignal++;
    }
    currentIndex = index;
    notifyListeners();
  }
}
