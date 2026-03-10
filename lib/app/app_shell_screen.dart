import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/mixins/view_model_binding_mixin.dart';
import '../features/home/presentation/views/home_radar_screen.dart';
import '../features/match/presentation/views/match_screen.dart';
import '../features/notifications/presentation/views/notification_screen.dart';
import '../features/profile/presentation/views/profile_screen.dart';
import '../features/chat/presentation/views/chat_list_screen.dart';
import '../services/global_chat_service.dart';
import '../services/notification_service.dart';
import 'app_shell_view_model.dart';

class MainNavigatorScreen extends StatefulWidget {
  const MainNavigatorScreen({super.key});

  @override
  State<MainNavigatorScreen> createState() => _MainNavigatorScreenState();
}

class _MainNavigatorScreenState extends State<MainNavigatorScreen>
    with
        WidgetsBindingObserver,
        ViewModelBindingMixin<MainNavigatorScreen, AppShellViewModel> {
  final GlobalKey<MatchScreenState> _matchKey = GlobalKey<MatchScreenState>();
  final GlobalKey<ProfileScreenState> _profileKey =
      GlobalKey<ProfileScreenState>();

  @override
  AppShellViewModel createViewModel() => AppShellViewModel();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF0F0F0F),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      NotificationService.instance.init(context);
      await GlobalChatService.instance.init(<Map<String, dynamic>>[]);
      GlobalChatService.instance
          .setChatListVisible(viewModel.currentIndex == 2);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    GlobalChatService.instance.handleAppLifecycle(isForeground);
  }

  List<Widget> _pages(AppShellViewModel vm) => <Widget>[
        const HomeRadarScreen(),
        MatchScreen(key: _matchKey),
        const ChatListScreen(),
        const NotificationScreen(),
        ProfileScreen(key: _profileKey),
      ];

  @override
  Widget buildWithViewModel(BuildContext context, AppShellViewModel vm) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF0F0F0F),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: IndexedStack(
          index: vm.currentIndex,
          children: _pages(vm),
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: const Color(0xFF0F0F0F),
          selectedItemColor: Colors.redAccent,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          currentIndex: vm.currentIndex,
          onTap: (index) {
            if (index == 1) {
              _matchKey.currentState?.setVisibility(true);
              _matchKey.currentState?.reloadWatchingStatus();
            } else {
              _matchKey.currentState?.setVisibility(false);
            }

            vm.selectTab(index);
            if (index == 4) {
              _profileKey.currentState?.refreshProfile();
            }
            GlobalChatService.instance.setChatListVisible(index == 2);
          },
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Anasayfa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.radar),
              label: 'Eşleşme Ara',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Mesajlar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              label: 'Bildirimler',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Hesabım',
            ),
          ],
        ),
      ),
    );
  }
}
