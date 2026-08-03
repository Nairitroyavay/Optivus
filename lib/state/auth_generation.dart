import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Monotonic fence for user-scoped asynchronous work.
///
/// Every sign-out/account reset increments this value. Long-running work must
/// capture it before starting and compare it, together with the owner UID,
/// before every persisted or local-state mutation after an await.
final authGenerationProvider = StateProvider<int>((ref) => 0);
