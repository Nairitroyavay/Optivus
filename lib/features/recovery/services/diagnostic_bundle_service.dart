import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/repositories/routine_repository.dart';

typedef OptivusProviderReader = T Function<T>(ProviderListenable<T> provider);

class DiagnosticBundleService {
  const DiagnosticBundleService();

  static final RegExp _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  static String redactPii(String input, {String? userName}) {
    var redacted = input.replaceAll(_emailRegex, '[REDACTED_EMAIL]');
    if (userName != null && userName.trim().isNotEmpty) {
      final namePattern = RegExp(
        RegExp.escape(userName.trim()),
        caseSensitive: false,
      );
      redacted = redacted.replaceAll(namePattern, '[REDACTED_NAME]');
    }
    return redacted;
  }

  Future<Map<String, dynamic>> generateDiagnosticBundle({
    required OptivusProviderReader read,
  }) async {
    final authState = read(authProvider);
    final userProfile = read(mockUserProfileProvider);
    final uid = authState.user?.uid ?? userProfile.uid;
    final email = authState.user?.email ?? userProfile.email;
    final displayName = authState.user?.displayName ?? userProfile.displayName;

    String? receiptStatus;
    try {
      final routineRepo = read(routineRepositoryProvider);
      final receipt = await routineRepo.fetchProjectionReceipt(
        uid,
        'onboarding-initial-v1',
      );
      receiptStatus = receipt?.status ?? 'none';
    } catch (_) {
      receiptStatus = 'error_fetching_receipt';
    }

    final rawData = {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'uid': uid,
      'userEmail': email,
      'userName': displayName,
      'systemMetadata': {
        'platform': 'flutter',
        'appVersion': '1.0.0',
        'backendMode': 'active',
      },
      'jobStage': {
        'authStatus': authState.status.name,
        'onboardingProjectionStatus': userProfile.onboardingProjectionStatus,
        'onboardingCompleted': userProfile.onboardingCompleted,
        'onboardingInputCompleted': userProfile.onboardingInputCompleted,
      },
      'receiptStatus': receiptStatus,
      'errorLogs': {
        'errorMessage': authState.errorMessage ?? 'None',
        'onboardingFailureReason':
            authState.onboardingFailureReason?.name ?? 'None',
        'failureReason': authState.failureReason?.name ?? 'None',
      },
    };

    final jsonString = jsonEncode(rawData);
    final redactedJsonString = redactPii(jsonString, userName: displayName);
    final Map<String, dynamic> bundle = jsonDecode(redactedJsonString);
    return bundle;
  }

  Future<String> exportDiagnosticBundleJson({
    required OptivusProviderReader read,
  }) async {
    final bundle = await generateDiagnosticBundle(read: read);
    return const JsonEncoder.withIndent('  ').convert(bundle);
  }
}

final diagnosticBundleServiceProvider = Provider(
  (ref) => const DiagnosticBundleService(),
);
