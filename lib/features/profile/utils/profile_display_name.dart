String resolveSafeProfileDisplayName({
  required String? profileName,
  required String? authDisplayName,
  required String? email,
}) {
  String clean(String? value) => (value ?? '').trim();

  bool isEmailLike(String value) {
    return value.contains('@') ||
        value.contains('.com') ||
        value.contains('.in') ||
        value.contains('.net') ||
        value.contains('.org') ||
        value.length > 28;
  }

  bool looksLikeEmailLocalPart(String value, String? email) {
    final cleanEmail = (email ?? '').trim();
    if (!cleanEmail.contains('@')) return false;
    final local = cleanEmail.split('@').first.trim().toLowerCase();
    return value.trim().toLowerCase() == local;
  }

  final candidates = [clean(profileName), clean(authDisplayName)];

  for (final candidate in candidates) {
    if (candidate.isEmpty) continue;
    if (isEmailLike(candidate)) continue;
    if (looksLikeEmailLocalPart(candidate, email)) continue;

    if (candidate.length > 22) {
      return '${candidate.substring(0, 22)}…';
    }

    return candidate;
  }

  return 'Profile';
}
