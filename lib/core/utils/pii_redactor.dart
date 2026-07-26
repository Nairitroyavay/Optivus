import 'dart:convert';

/// Client-side PII redactor filter for log outputs, diagnostic bundles, and telemetry data.
/// Redacts email addresses, phone numbers, auth tokens, passwords/secrets, and user names.
class PiiRedactor {
  PiiRedactor._();

  static final RegExp _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  static final RegExp _phoneRegex = RegExp(
    r'(\+?\d{1,4}[\s.-]?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}',
  );

  static final RegExp _bearerTokenRegex = RegExp(
    r'Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*',
    caseSensitive: false,
  );

  static final RegExp _authTokenRegex = RegExp(
    '(authToken|auth_token|accessToken|access_token|idToken|id_token|refreshToken|refresh_token|apiKey|api_key|secretKey|secret_key|password)\\s*[:=]\\s*["\']?[^"\'\\s,]+["\']?',
    caseSensitive: false,
  );

  /// Redacts PII patterns from [input].
  /// Optionally replaces occurrences of [userName] with `[REDACTED_NAME]`.
  static String redact(String input, {String? userName}) {
    if (input.isEmpty) return input;

    var redacted = input;

    // 1. Redact Auth tokens and API keys
    redacted = redacted.replaceAllMapped(_bearerTokenRegex, (match) {
      return 'Bearer [REDACTED_TOKEN]';
    });

    redacted = redacted.replaceAllMapped(_authTokenRegex, (match) {
      final fullMatch = match.group(0) ?? '';
      final keyMatch = match.group(1) ?? 'secret';
      final isJson = fullMatch.contains(':');
      final isQuoted = fullMatch.contains('"') || fullMatch.contains("'");
      final quoteChar = fullMatch.contains('"') ? '"' : "'";

      if (isJson && isQuoted) {
        return '$quoteChar$keyMatch$quoteChar: $quoteChar[REDACTED_SECRET]$quoteChar';
      } else if (isJson) {
        return '$keyMatch: [REDACTED_SECRET]';
      } else {
        return '$keyMatch=[REDACTED_SECRET]';
      }
    });

    // 2. Redact Email addresses
    redacted = redacted.replaceAll(_emailRegex, '[REDACTED_EMAIL]');

    // 3. Redact Phone numbers
    redacted = redacted.replaceAll(_phoneRegex, '[REDACTED_PHONE]');

    // 4. Redact User Name if provided
    if (userName != null && userName.trim().isNotEmpty) {
      final trimmedName = userName.trim();
      if (trimmedName.length >= 2) {
        final namePattern = RegExp(
          RegExp.escape(trimmedName),
          caseSensitive: false,
        );
        redacted = redacted.replaceAll(namePattern, '[REDACTED_NAME]');
      }
    }

    return redacted;
  }

  /// Redacts PII values within a JSON-compatible Map.
  static Map<String, dynamic> redactMap(
    Map<String, dynamic> map, {
    String? userName,
  }) {
    try {
      final jsonString = jsonEncode(map);
      final redactedJson = redact(jsonString, userName: userName);
      final decoded = jsonDecode(redactedJson);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return map;
    } catch (_) {
      return map;
    }
  }

  /// Format log output with PII redacted.
  static String redactLog(String message, {String? userName}) {
    return '[LOG] ${redact(message, userName: userName)}';
  }
}
