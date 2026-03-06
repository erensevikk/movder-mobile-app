import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _isLoading = true;

  // Backend'den gelen ayarlar
  bool _pushEnabled = true;
  bool _matchAlerts = true;
  bool _messageAlerts = true;
  bool _friendAlerts = true;

  // Cihaz hafızasındaki lokal ayarlar (SharedPreferences)
  bool _inAppSounds = true;
  bool _vibration = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      // 1. Lokal ayarları yükle
      final prefs = await SharedPreferences.getInstance();
      _inAppSounds = prefs.getBool('inAppSounds') ?? true;
      _vibration = prefs.getBool('vibration') ?? true;

      // 2. Sunucu ayarlarını yükle
      final response = await ApiService.get('/api/account/notifications');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final backendSettings = data['notificationSettings'] ?? {};

        _pushEnabled = backendSettings['pushEnabled'] ?? true;
        _matchAlerts = backendSettings['matchAlerts'] ?? true;
        _messageAlerts = backendSettings['messageAlerts'] ?? true;
        _friendAlerts = backendSettings['friendAlerts'] ?? true;
      }
    } catch (e) {
      debugPrint('Bildirim ayarları yüklenemedi: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateBackendSettings() async {
    try {
      await ApiService.put('/api/account/notifications', {
        'pushEnabled': _pushEnabled,
        'matchAlerts': _matchAlerts,
        'messageAlerts': _messageAlerts,
        'friendAlerts': _friendAlerts,
      });
    } catch (e) {
      debugPrint('Bildirim ayarları güncellenemedi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ayarlar kaydedilirken ağ hatası oluştu.')),
        );
      }
    }
  }

  Future<void> _updateLocalSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Bildirimler',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildSectionHeader('Anlık Bildirimler'),
                _buildSwitchItem(
                  title: 'Bildirimlere İzin Ver',
                  subtitle: 'Tüm anlık bildirimleri kapatır veya açar.',
                  value: _pushEnabled,
                  onChanged: (val) {
                    setState(() => _pushEnabled = val);
                    _updateBackendSettings();
                  },
                  isMaster: true,
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('Detaylı Bildirimler'),
                _buildSwitchItem(
                  title: 'Yeni Eşleşmeler',
                  subtitle: 'Biriyle eşleştiğinde bildirim al.',
                  value: _matchAlerts,
                  disabled: !_pushEnabled,
                  onChanged: (val) {
                    setState(() => _matchAlerts = val);
                    _updateBackendSettings();
                  },
                ),
                _buildSwitchItem(
                  title: 'Yeni Mesajlar',
                  subtitle: 'Eşleştiğin kişilerden gelen mesajlar.',
                  value: _messageAlerts,
                  disabled: !_pushEnabled,
                  onChanged: (val) {
                    setState(() => _messageAlerts = val);
                    _updateBackendSettings();
                  },
                ),
                _buildSwitchItem(
                  title: 'Arkadaşlık İstekleri',
                  subtitle: 'Birisi seni eklemek istediğinde.',
                  value: _friendAlerts,
                  disabled: !_pushEnabled,
                  onChanged: (val) {
                    setState(() => _friendAlerts = val);
                    _updateBackendSettings();
                  },
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('Uygulama İçi Tercihler'),
                _buildSwitchItem(
                  title: 'Uygulama İçi Sesler',
                  subtitle: 'Uygulama kullanımındayken çalınan efekt sesleri.',
                  value: _inAppSounds,
                  onChanged: (val) {
                    setState(() => _inAppSounds = val);
                    _updateLocalSetting('inAppSounds', val);
                  },
                ),
                _buildSwitchItem(
                  title: 'Titreşim',
                  subtitle:
                      'Eşleşme veya mesaj bildiriminde telefon titreşimi.',
                  value: _vibration,
                  onChanged: (val) {
                    setState(() => _vibration = val);
                    _updateLocalSetting('vibration', val);
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
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

  Widget _buildSwitchItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool disabled = false,
    bool isMaster = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Opacity(
        opacity: disabled ? 0.4 : 1.0,
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
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          trailing: SizedBox(
            width: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  value ? 'Açık' : 'Kapalı',
                  style: TextStyle(
                    color: value ? Colors.white70 : Colors.white38,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: value,
                  onChanged: disabled ? null : onChanged,
                  activeColor: Colors.white,
                  activeTrackColor: Colors.grey[700],
                  inactiveThumbColor: Colors.white70,
                  inactiveTrackColor: Colors.white10,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
