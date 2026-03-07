import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'blocked_users_screen.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  String _watchingVisibility = 'friends_and_matches';
  String _profileVisibility = 'public';
  bool _searchDiscoverable = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final settings = await ApiService.getPrivacySettings();
    if (!mounted) return;

    setState(() {
      _watchingVisibility =
          (settings?['watchingVisibility'] ?? 'friends_and_matches').toString();
      _profileVisibility =
          (settings?['profileVisibility'] ?? 'public').toString();
      _searchDiscoverable = settings?['searchDiscoverable'] != false;
      _isLoading = false;
    });
  }

  Future<void> _save({
    String? watchingVisibility,
    String? profileVisibility,
    bool? searchDiscoverable,
  }) async {
    setState(() => _isSaving = true);

    final updated = await ApiService.updatePrivacySettings(
      watchingVisibility: watchingVisibility,
      profileVisibility: profileVisibility,
      searchDiscoverable: searchDiscoverable,
    );
    if (!mounted) return;

    if (updated != null) {
      setState(() {
        _watchingVisibility =
            (updated['watchingVisibility'] ?? _watchingVisibility).toString();
        _profileVisibility =
            (updated['profileVisibility'] ?? _profileVisibility).toString();
        _searchDiscoverable = updated['searchDiscoverable'] == null
            ? _searchDiscoverable
            : updated['searchDiscoverable'] == true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gizlilik ayarları güncellenemedi.'),
        ),
      );
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildSectionHeader('Hesap Görünürlüğü'),
                _buildChoiceCard(
                  title: 'Aktif İzleme Durumu',
                  subtitle: 'İzlediğiniz filmi kimlerin görebileceğini seçin.',
                  valueText: _watchingLabel(_watchingVisibility),
                  children: [
                    _buildChoiceOption(
                      title: 'Herkes',
                      subtitle:
                          'Profilinizi gören herkes aktif izlemenizi görebilir.',
                      selected: _watchingVisibility == 'public',
                      onTap: _isSaving
                          ? null
                          : () => _save(watchingVisibility: 'public'),
                    ),
                    _buildChoiceOption(
                      title: 'Sadece Arkadaşlar ve Eşleşmeler',
                      subtitle:
                          'Varsayılan görünürlük. Sadece yakın çevrenize açık olur.',
                      selected: _watchingVisibility == 'friends_and_matches',
                      onTap: _isSaving
                          ? null
                          : () => _save(
                                watchingVisibility: 'friends_and_matches',
                              ),
                    ),
                    _buildChoiceOption(
                      title: 'Gizli (Hayalet Modu)',
                      subtitle: 'Aktif izleme durumunuz paylaşılmaz.',
                      selected: _watchingVisibility == 'hidden',
                      onTap: _isSaving
                          ? null
                          : () => _save(watchingVisibility: 'hidden'),
                    ),
                  ],
                ),
                _buildChoiceCard(
                  title: 'Profil ve Listeler',
                  subtitle:
                      'Profil detaylarınızın ve listelerinizin kimlere açık olacağını seçin.',
                  valueText: _profileLabel(_profileVisibility),
                  children: [
                    _buildChoiceOption(
                      title: 'Herkese Açık',
                      subtitle:
                          'Profil detaylarınız ve herkese açık listeleriniz görülebilir.',
                      selected: _profileVisibility == 'public',
                      onTap: _isSaving
                          ? null
                          : () => _save(profileVisibility: 'public'),
                    ),
                    _buildChoiceOption(
                      title: 'Sadece Arkadaşlar',
                      subtitle:
                          'Profil detaylarınızı yalnızca arkadaşlarınız görebilir.',
                      selected: _profileVisibility == 'friends_only',
                      onTap: _isSaving
                          ? null
                          : () => _save(profileVisibility: 'friends_only'),
                    ),
                  ],
                ),
                _buildSwitchItem(
                  title: 'Aramada Görün',
                  subtitle:
                      'Kullanıcı aramalarında hesabınızın bulunmasını açıp kapatın.',
                  value: _searchDiscoverable,
                  onChanged: _isSaving
                      ? null
                      : (value) => _save(searchDiscoverable: value),
                ),
                _buildSectionHeader('Güvenlik ve İzinler'),
                _buildNavItem(
                  icon: Icons.block_outlined,
                  title: 'Engellenen Kullanıcılar',
                  subtitle:
                      'Engellediğiniz kişileri görüntüleyin ve isterseniz engeli kaldırın.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BlockedUsersScreen(),
                    ),
                  ),
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

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required String valueText,
    required List<Widget> children,
  }) {
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
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
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

  Widget _buildChoiceOption({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback? onTap,
  }) {
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
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? Colors.redAccent : Colors.white30,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

  Widget _buildSwitchItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
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

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
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
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 13,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }

  String _watchingLabel(String value) {
    switch (value) {
      case 'public':
        return 'Herkes';
      case 'hidden':
        return 'Hayalet Modu';
      default:
        return 'Arkadaşlar ve Eşleşmeler';
    }
  }

  String _profileLabel(String value) {
    return value == 'friends_only' ? 'Sadece Arkadaşlar' : 'Herkese Açık';
  }
}
