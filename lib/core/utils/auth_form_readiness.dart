import 'package:optivus/core/utils/password_policy.dart';

final RegExp _basicEmailPattern = RegExp(
  r'^[\w\.\+\-]+@[\w\-]+\.[a-z]{2,}$',
  caseSensitive: false,
);

bool isBasicEmailFormatValid(String value) {
  return _basicEmailPattern.hasMatch(value.trim());
}

bool isLoginFormReady({required String email, required String password}) {
  return isBasicEmailFormatValid(email) && password.isNotEmpty;
}

bool isSignupFormReady({
  required String name,
  required String email,
  required String password,
  required String confirmation,
}) {
  return name.trim().length >= 2 &&
      isBasicEmailFormatValid(email) &&
      isOptivusPasswordValid(password) &&
      confirmation == password;
}
