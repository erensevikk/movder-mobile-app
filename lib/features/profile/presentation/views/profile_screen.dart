import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/base/base_state.dart';
import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../view_models/profile_screen_view_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen>
    with
        ViewModelBindingMixin<ProfileScreen, ProfileScreenViewModel>,
        ViewEffectListenerMixin<ProfileScreen, ProfileScreenViewModel> {
  @override
  ProfileScreenViewModel createViewModel() => ProfileScreenViewModel();

  Future<void> refreshProfile() => viewModel.refresh();

  @override
  Widget buildWithViewModel(BuildContext context, ProfileScreenViewModel vm) {
    if (vm.status == ViewStatus.loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: LoadingView(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ClipRect(
          child: vm.isLoggedIn
              ? RefreshIndicator(
                  color: Colors.redAccent,
                  onRefresh: vm.refresh,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _ProfileHeader(vm: vm)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPrimaryActions(vm),
                              const SizedBox(height: 16),
                              _buildLetterboxdSyncButton(vm),
                              const SizedBox(height: 28),
                              const Text(
                                'AYARLAR',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _SettingsItem(
                                icon: Icons.person_outline,
                                title: 'Hesap Ayarları',
                                onTap: vm.openSettings,
                              ),
                              _SettingsItem(
                                icon: Icons.notifications_none,
                                title: 'Bildirimler',
                                onTap: vm.openNotificationSettings,
                              ),
                              _SettingsItem(
                                icon: Icons.lock_outline,
                                title: 'Gizlilik',
                                onTap: vm.openPrivacySettings,
                              ),
                              _SettingsItem(
                                icon: Icons.help_outline,
                                title: 'Yardım ve Destek',
                                onTap: vm.openHelp,
                              ),
                              const SizedBox(height: 24),
                              _buildLogoutButton(vm),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : _GuestProfile(vm: vm),
        ),
      ),
    );
  }

  Widget _buildPrimaryActions(ProfileScreenViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PROFİL',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: vm.openProfileDetails,
            icon: const Icon(Icons.person_search_rounded, color: Colors.white),
            label: const Text(
              'Profilimi Görüntüle',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLetterboxdSyncButton(ProfileScreenViewModel vm) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: vm.openImport,
        icon: const Icon(Icons.sync_rounded, color: Color(0xFF40BCF4)),
        label: const Text(
          'Letterboxd Verilerini İçe Aktar',
          style: TextStyle(
            color: Color(0xFF40BCF4),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF2C3440)),
          backgroundColor: const Color(0xFF141A1F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(ProfileScreenViewModel vm) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: vm.logout,
        icon: const Icon(Icons.logout, color: Colors.redAccent),
        label: const Text(
          'Çıkış Yap',
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.vm});

  final ProfileScreenViewModel vm;

  @override
  Widget build(BuildContext context) {
    const double coverHeight = 135.0;
    const double avatarSize = 90.0;
    final profile = vm.profile!;
    final isWatching = vm.watchStatus != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            const SizedBox(
              width: double.infinity,
              height: coverHeight + (avatarSize / 2),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: coverHeight,
              child: vm.coverImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: vm.coverImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: const Color(0xFF1E1E1E)),
                      errorWidget: (_, __, ___) =>
                          Container(color: const Color(0xFF1E1E1E)),
                    )
                  : Container(color: const Color(0xFF1E1E1E)),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: coverHeight,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 7,
              bottom: 0,
              child: Stack(
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E1E1E),
                      border:
                          Border.all(color: const Color(0xFF0F0F0F), width: 4),
                      image: profile.avatarUrl.isNotEmpty
                          ? DecorationImage(
                              image:
                                  CachedNetworkImageProvider(profile.avatarUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: profile.avatarUrl.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white54,
                          )
                        : null,
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isWatching
                            ? Colors.redAccent
                            : const Color(0xFF4CAF50),
                        border: Border.all(
                            color: const Color(0xFF0F0F0F), width: 4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              _buildStatusBadge(isWatching, vm.watchStatus?.movieName,
                  vm.watchStatus?.watchingFor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(
      bool isWatching, String? movieName, String? watchingFor) {
    if (!isWatching || movieName == null) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2318),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1A4A2E)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Çevrimiçi',
              style: TextStyle(
                color: Color(0xFF81C784),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$movieName izliyor — $watchingFor',
              style: TextStyle(
                color: Colors.redAccent.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestProfile extends StatelessWidget {
  const _GuestProfile({required this.vm});

  final ProfileScreenViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        CachedNetworkImage(
          imageUrl:
              'https://image.tmdb.org/t/p/w780/xbiycuc84TrieEWwkkuH2hoEa9S.jpg',
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: const Color(0xFF0F0F0F)),
          errorWidget: (_, __, ___) =>
              Container(color: const Color(0xFF0F0F0F)),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 12),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.redAccent,
                          Colors.redAccent.shade700,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.movie_filter_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Movder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yalniz izleme devri bitti.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Text(
                      'Movder, aynı anda aynı filmi izleyen insanları '
                      'anlık olarak eşleştirerek bir sosyal sinema platformudur. '
                      'Bir film açtığında, o filmi izleyen başka biriyle '
                      'saniyeler içinde buluş ve birlikte keyfini çıkar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: <Widget>[
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.bolt_rounded,
                          title: 'Anlık Eşleşme',
                          subtitle: 'Aynı filmi izleyenle saniyede buluş',
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.chat_bubble_rounded,
                          title: 'Canlı Sohbet',
                          subtitle: 'Film hakkında anında tartış',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: <Widget>[
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.people_rounded,
                          title: 'Arkadaşlık',
                          subtitle: 'Film zevkine uygun kişileri keşfet',
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.movie_creation_rounded,
                          title: 'Film Profili',
                          subtitle: 'İzleme geçmişini sergile',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: vm.openLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 8,
                        shadowColor: Colors.redAccent.withValues(alpha: 0.4),
                      ),
                      child: const Text(
                        'Giriş Yap',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: vm.openRegister,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Kayıt Ol',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 200),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: Colors.redAccent, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
