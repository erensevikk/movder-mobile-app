import 'package:flutter/material.dart';

import '../../../../core/base/base_state.dart';
import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../screens/settings/blocked_users_screen.dart';
import '../view_models/privacy_settings_view_model.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen>
    with
        ViewModelBindingMixin<PrivacySettingsScreen, PrivacySettingsViewModel>,
        ViewEffectListenerMixin<PrivacySettingsScreen,
            PrivacySettingsViewModel> {
  @override
  PrivacySettingsViewModel createViewModel() => PrivacySettingsViewModel();

  @override
  Widget buildWithViewModel(BuildContext context, PrivacySettingsViewModel vm) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text(
          'Gizlilik',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: switch (vm.status) {
        ViewStatus.loading => const LoadingView(),
        ViewStatus.error => ErrorView(
            message: vm.errorMessage ?? 'Gizlilik ayarlari alinamadi.',
            onRetry: vm.initialize,
          ),
        _ => ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: <Widget>[
              const _SectionHeader(title: 'Hesap Gorunurlugu'),
              _ChoiceCard(
                title: 'Aktif Izleme Durumu',
                subtitle: 'Izlediginiz filmi kimlerin gorecegini secin.',
                valueText: _watchingLabel(vm.settings.watchingVisibility),
                children: <Widget>[
                  _ChoiceOption(
                    title: 'Herkes',
                    subtitle: 'Profilinizi goren herkes gorebilir.',
                    selected: vm.settings.watchingVisibility == 'public',
                    onTap: () => vm.update(watchingVisibility: 'public'),
                  ),
                  _ChoiceOption(
                    title: 'Arkadaslar ve Eslesmeler',
                    subtitle: 'Varsayilan gorunurluk.',
                    selected:
                        vm.settings.watchingVisibility == 'friends_and_matches',
                    onTap: () => vm.update(
                      watchingVisibility: 'friends_and_matches',
                    ),
                  ),
                  _ChoiceOption(
                    title: 'Gizli',
                    subtitle: 'Aktif izleme durumunuz paylasilmaz.',
                    selected: vm.settings.watchingVisibility == 'hidden',
                    onTap: () => vm.update(watchingVisibility: 'hidden'),
                  ),
                ],
              ),
              _ChoiceCard(
                title: 'Profil ve Listeler',
                subtitle: 'Profil detaylarinizin kimlere acik olacagini secin.',
                valueText: _profileLabel(vm.settings.profileVisibility),
                children: <Widget>[
                  _ChoiceOption(
                    title: 'Herkese Acik',
                    subtitle: 'Profil detaylari herkese gorunur.',
                    selected: vm.settings.profileVisibility == 'public',
                    onTap: () => vm.update(profileVisibility: 'public'),
                  ),
                  _ChoiceOption(
                    title: 'Sadece Arkadaslar',
                    subtitle: 'Yalnizca arkadaslariniz gorebilir.',
                    selected: vm.settings.profileVisibility == 'friends_only',
                    onTap: () => vm.update(profileVisibility: 'friends_only'),
                  ),
                ],
              ),
              _SwitchItem(
                title: 'Aramada Gorun',
                subtitle: 'Kullanici aramalarinda hesabiniz gorunsun.',
                value: vm.settings.searchDiscoverable,
                onChanged: (value) => vm.update(searchDiscoverable: value),
              ),
              const _SectionHeader(title: 'Guvenlik ve Izinler'),
              _NavItem(
                icon: Icons.block_outlined,
                title: 'Engellenen Kullanicilar',
                subtitle: 'Engellediginiz kisileri yonetin.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BlockedUsersScreen(),
                  ),
                ),
              ),
            ],
          ),
      },
    );
  }
}

String _watchingLabel(String value) {
  switch (value) {
    case 'public':
      return 'Herkes';
    case 'hidden':
      return 'Gizli';
    default:
      return 'Arkadaslar ve Eslesmeler';
  }
}

String _profileLabel(String value) {
  return value == 'friends_only' ? 'Sadece Arkadaslar' : 'Herkese Acik';
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

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

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.valueText,
    required this.children,
  });

  final String title;
  final String subtitle;
  final String valueText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                valueText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ChoiceOption extends StatelessWidget {
  const _ChoiceOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? Colors.redAccent.withValues(alpha: 0.12)
                : const Color(0xFF181818),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Colors.redAccent.withValues(alpha: 0.45)
                  : Colors.white10,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? Colors.redAccent : Colors.white30,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchItem extends StatelessWidget {
  const _SwitchItem({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
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
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: Colors.grey[700],
          inactiveThumbColor: Colors.white70,
          inactiveTrackColor: Colors.white10,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}
