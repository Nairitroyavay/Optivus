import 'dart:io';

void main() {
  var file = File(
    'lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart',
  );
  var content = file.readAsStringSync();
  content = content.replaceFirst(
    "label: 'Rebuild',",
    "label: 'Rebuild / Edit',",
  );
  content = content.replaceAll(
    '''                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Routine built',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: OptivusColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '\${widget.base.skinCareDesiredApplicationsPerDay} routines per day',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: OptivusColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OnboardingActionPill(
                      label: 'Rebuild / Edit',
                      icon: Icons.refresh_rounded,
                      accent: OptivusColors.roseAccent,
                      compact: true,
                      onTap: () => updateBaseTimelineDraft(
                        ref,
                        onboardingSkinCareStepIndex,
                        (base) => base.copyWith(
                          blocks: base.blocks
                              .where((b) => b.section != 'skin_care')
                              .toList(),
                        ),
                      ),
                    ),''',
    '''                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Routine built',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: OptivusColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '\${widget.base.skinCareDesiredApplicationsPerDay} routines per day',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: OptivusColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          OnboardingActionPill(
                            label: 'Rebuild / Edit',
                            icon: Icons.refresh_rounded,
                            accent: OptivusColors.roseAccent,
                            compact: true,
                            onTap: () => updateBaseTimelineDraft(
                              ref,
                              onboardingSkinCareStepIndex,
                              (base) => base.copyWith(
                                blocks: base.blocks
                                    .where((b) => b.section != 'skin_care')
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),''',
  );
  file.writeAsStringSync(content);
}
