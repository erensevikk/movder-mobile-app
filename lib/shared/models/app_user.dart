class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    this.email,
    this.city,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String? email;
  final String? city;
  final String? avatarUrl;
}
