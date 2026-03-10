import 'package:flutter/material.dart';

import '../../../../core/base/base_state.dart';
import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../data/models/notification_settings_model.dart';
import '../view_models/notification_settings_view_model.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with
        ViewModelBindingMixin<NotificationSettingsScreen,
            NotificationSettingsViewModel>,
        ViewEffectListenerMixin<NotificationSettingsScreen,
            NotificationSettingsViewModel> {
  @override
  NotificationSettingsViewModel createViewModel() =>
      NotificationSettingsViewModel();

  @override
  Widget buildWithViewModel(
    BuildContext context,
    NotificationSettingsViewModel vm,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text(
          'Bildirimler',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: switch (vm.status) {
        ViewStatus.loading => const LoadingView(),
        ViewStatus.error => ErrorView(
            message: vm.errorMessage ?? 'Bildirim ayarlari yuklenemedi.',
            onRetry: vm.initialize,
          ),
        _ => ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: <Widget>[
              const _SettingsHeader(title: 'Anlık Bildirimler'),
              _SettingsSwitch(
                title: 'Bildirimlere İzin Ver',
                subtitle: 'Tüm anlık bildirimleri açar veya kapatır.',
                value: vm.settings.pushEnabled,
                onChanged: (value) => _update(
                  vm,
                  vm.settings.copyWith(pushEnabled: value),
                ),
                isMaster: true,
              ),
              const SizedBox(height: 16),
              const _SettingsHeader(title: 'Detayli Bildirimler'),
              _SettingsSwitch(
                title: 'Yeni Eslesmeler',
                subtitle: 'Biriyle eslestiginde bildirim al.',
                value: vm.settings.matchAlerts,
                disabled: !vm.settings.pushEnabled,
                onChanged: (value) => _update(
                  vm,
                  vm.settings.copyWith(matchAlerts: value),
                ),
              ),
              _SettingsSwitch(
                title: 'Yeni Mesajlar',
                subtitle: 'Eslesmelerinizden gelen mesajlar.',
                value: vm.settings.messageAlerts,
                disabled: !vm.settings.pushEnabled,
                onChanged: (value) => _update(
                  vm,
                  vm.settings.copyWith(messageAlerts: value),
                ),
              ),
              _SettingsSwitch(
                title: 'Arkadaslik Istekleri',
                subtitle: 'Biri sizi eklemek istediginde bildirim al.',
                value: vm.settings.friendAlerts,
                disabled: !vm.settings.pushEnabled,
                onChanged: (value) => _update(
                  vm,
                  vm.settings.copyWith(friendAlerts: value),
                ),
              ),
              const SizedBox(height: 16),
              const _SettingsHeader(title: 'Uygulama Ici Tercihler'),
              _SettingsSwitch(
                title: 'Uygulama Ici Sesler',
                subtitle: 'Uygulama kullanilirken calinan efekt sesleri.',
                value: vm.settings.inAppSounds,
                onChanged: (value) => _update(
                  vm,
                  vm.settings.copyWith(inAppSounds: value),
                ),
              ),
              _SettingsSwitch(
                title: 'Titresim',
                subtitle: 'Mesaj ve eslesme bildiriminde titresim.',
                value: vm.settings.vibration,
                onChanged: (value) => _update(
                  vm,
                  vm.settings.copyWith(vibration: value),
                ),
              ),
            ],
          ),
      },
    );
  }

  void _update(
    NotificationSettingsViewModel vm,
    NotificationSettingsModel next,
  ) {
    vm.update(next);
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.disabled = false,
    this.isMaster = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool disabled;
  final bool isMaster;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Opacity(
        opacity: disabled ? 0.4 : 1,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: isMaster ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          trailing: Switch(
            value: value,
            onChanged: disabled ? null : onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.grey[700],
            inactiveThumbColor: Colors.white70,
            inactiveTrackColor: Colors.white10,
          ),
        ),
      ),
    );
  }
}
