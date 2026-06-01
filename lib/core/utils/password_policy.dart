class PasswordRule {
  final String label;
  final bool Function(String password) check;

  const PasswordRule({required this.label, required this.check});
}

final optivusPasswordRules = [
  PasswordRule(
    label: 'At least 8 characters',
    check: (password) => password.length >= 8,
  ),
  PasswordRule(
    label: 'Contains one capital letter',
    check: (password) => password.contains(RegExp(r'[A-Z]')),
  ),
  PasswordRule(
    label: 'Contains one number',
    check: (password) => password.contains(RegExp(r'[0-9]')),
  ),
  PasswordRule(
    label: 'Contains one special character (@, #, \$, etc.)',
    check: (password) =>
        password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]')),
  ),
];

bool isOptivusPasswordValid(String password) {
  return optivusPasswordRules.every((rule) => rule.check(password));
}
