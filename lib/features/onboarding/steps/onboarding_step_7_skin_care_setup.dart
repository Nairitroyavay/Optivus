import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/ai/ai_generation_lifecycle.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_primary_action.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_controller.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_state.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_action_bar.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/timeline/onboarding_timeline.dart';
import 'package:optivus/features/uploads/models/upload_interaction_models.dart';
import 'package:optivus/features/uploads/providers/onboarding_upload_interaction_provider.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/auth_generation.dart';
import 'package:optivus/state/region_settings_provider.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/state/upload_state.dart';
import 'package:optivus/services/skin_care_ai_client.dart';
import 'package:optivus/features/onboarding/widgets/ai_thinking_card.dart';

part 'skin_care/skin_care_helpers.dart';
part 'skin_care/skin_care_shared_widgets.dart';
part 'skin_care/skin_care_choice_screen.dart';
part 'skin_care/has_products_screen.dart';
part 'skin_care/no_products_screen.dart';
part 'skin_care/skin_care_timeline_section.dart';

const String onboardingSkinCareGeneratedSource = 'ai_skin_care_setup';
const String onboarding7CompactPayloadFinalMessage =
    'AI read too much product detail. Try typing only your main products or upload a clearer single photo.';
const int _onboarding7SpecialCareNoteMaxLength = 180;
const String _onboarding7NoTypedProductsMessage =
    'Type one product per line, for example "Daily SPF 50 - sunscreen".';
const String _onboarding7AiEmptyMessage =
    'AI returned no usable routine. Try clearer product names or 2 times/day.';
const String _onboarding7NoProductsAiEmptyMessage =
    'AI returned no usable starter routine. Try again or choose 2 times/day.';
const String _onboarding7AiFewerRoutinesMessage =
    'AI returned fewer routines than requested. Try again or choose fewer times per day.';
const String _onboarding7PhotoUnreadableMessage =
    'AI could not read your products. Upload a clearer photo or use typed product names.';

class OnboardingStep7 extends ConsumerWidget {
  const OnboardingStep7({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    final base = draft.baseTimeline;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final hasActivePath =
        base.skinCareSetupPath == 'has_products' ||
        base.skinCareSetupPath == 'no_products' ||
        base.skinCareSetupPath == 'skip' ||
        base.skinCareSkipped;
    final isChoice = base.skinCareSetupStep <= 0 || !hasActivePath;
    // Keep the review subtree mounted while a retained routine is edited.
    // The edit is intentionally transactional: changing a selection makes the
    // fingerprint stale, but must not re-parent this stateful editor and lose
    // its pending rebuild state before a replacement succeeds or is cancelled.
    final hasRetainedRoutine = base.blocks.any(
      (block) => block.section == 'skin_care',
    );

    // Review mode is structurally parallel to Steps 4 and 5: the timeline
    // owns the onboarding body rather than living inside setup padding.
    if (hasRetainedRoutine && !isChoice) {
      return _SkinCareSelectedModeScreen(base: base);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!keyboardOpen) ...[
            const _SkinCareHeader(),
            const SizedBox(height: 18),
          ],
          Expanded(
            child: isChoice
                ? _SkinCareChoiceScreen(base: base)
                : _SkinCareSelectedModeScreen(base: base),
          ),
        ],
      ),
    );
  }
}

class _SkinCareSelectedModeScreen extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _SkinCareSelectedModeScreen({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (base.skinCareSkipped || base.skinCareSetupPath == 'skip') {
      return const _SkipModeScreen();
    }

    final blocks = base.confirmedBlocksForSection('skin_care');

    if (base.skinCareSetupPath == 'has_products') {
      return _HasProductsModeScreen(base: base, blocks: blocks);
    }

    return _NoProductsModeScreen(base: base, blocks: blocks);
  }
}

class _SkipModeScreen extends StatelessWidget {
  const _SkipModeScreen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingGlassCard(
          tint: OptivusColors.textSecondary.withValues(alpha: 0.08),
          child: const Row(
            children: [
              Icon(Icons.skip_next_rounded, color: OptivusColors.textSecondary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Skin care will be skipped for now.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
