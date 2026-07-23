import 'dart:io';

void main() {
  var file = File(
    'lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart',
  );
  var content = file.readAsStringSync();
  content = content.replaceFirst(
    "label: 'Rebuild / Edit',",
    "label: 'Rebuild',",
  );
  file.writeAsStringSync(content);
}
