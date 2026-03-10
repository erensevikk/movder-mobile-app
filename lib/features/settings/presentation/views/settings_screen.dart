import 'package:flutter/material.dart';

import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../view_models/settings_screen_view_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with
        ViewModelBindingMixin<SettingsScreen, SettingsScreenViewModel>,
        ViewEffectListenerMixin<SettingsScreen, SettingsScreenViewModel> {
  @override
  SettingsScreenViewModel createViewModel() => SettingsScreenViewModel();

  @override
  Widget buildWithViewModel(BuildContext context, SettingsScreenViewModel vm) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text(
          'Hesap Ayarlari',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: <Widget>[
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Kisisel Bilgiler',
            onTap: vm.openAccountInfo,
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Sifre Degistir',
            onTap: vm.openChangePassword,
          ),
          _SettingsTile(
            icon: Icons.delete_forever,
            title: 'Hesabi Sil',
            onTap: vm.confirmDeleteAccount,
            iconColor: Colors.redAccent,
            textColor: Colors.redAccent,
            hideArrow: true,
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor = Colors.white70,
    this.textColor = Colors.white,
    this.hideArrow = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color iconColor;
  final Color textColor;
  final bool hideArrow;

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
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: hideArrow
            ? null
            : const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}
