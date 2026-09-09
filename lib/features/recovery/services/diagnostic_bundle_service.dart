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

  static final RegExp _systemPathRegex = RegExp(
    r'(?:file://)?(?:/Users|/data|/home|[a-zA-Z]:\\Users|[a-zA-Z]:\\Documents and Settings)/[A-Za-z0-9_.\-/]+',
    caseSensitive: false,
  );

  static final RegExp _jwtTokenRegex = RegExp(
    r'eyJ[A-Za-z0-9\-_]+\.eyJ[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_%]+',
  );

  static final RegExp _bearerTokenRegex = RegExp(
    r'Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*',
    caseSensitive: false,
  );

  static final RegExp _jsonTokenKeyRegex = RegExp(
    r'"(authToken|accessToken|idToken|refreshToken|token|apiKey|secret)":\s*"[^"]+"',
    caseSensitive: false,
  );

  static String redactPii(String input, {String? userName}) {
    var redacted = input.replaceAll(_emailRegex, '[REDACTED_EMAIL]');
    redacted = redacted.replaceAll(_systemPathRegex, '[REDACTED_PATH]');
    redacted = redacted.replaceAll(_jwtTokenRegex, '[REDACTED_TOKEN]');
    redacted = redacted.replaceAllMapped(
      _bearerTokenRegex,
      (m) => 'Bearer [REDACTED_TOKEN]',
    );
    redacted = redacted.replaceAllMapped(
      _jsonTokenKeyRegex,
      (m) => '"${m[1]}": "[REDACTED_TOKEN]"',
    );
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
    final userProfile = read(userProfileProvider);
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
        'errorCategory': authState.error?.category.name ?? 'None',
        'diagnosticCode': authState.error?.diagnosticCode ?? 'None',
        'retryAction': authState.error?.retryAction.name ?? 'None',
        'retrySafe': authState.error?.retrySafe ?? false,
        'blocking': authState.error?.isBlocking ?? false,
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
