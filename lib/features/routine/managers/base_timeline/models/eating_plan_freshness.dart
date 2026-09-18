import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_domain_engine.dart';
import 'package:optivus/models/user_profile.dart';

/// Represents the freshness status of an AI-generated meal plan.
enum EatingPlanFreshness {
  /// The plan matches the current user profile and preferences.
  current,

  /// The plan's fingerprint differs from current inputs (profile/preferences drifted).
  stale,

  /// Freshness could not be verified (e.g. incomplete Body Basics or invalid inputs).
  unknown;

  bool get isStale => this == EatingPlanFreshness.stale;
  bool get isUnknown => this == EatingPlanFreshness.unknown;
  bool get isCurrent => this == EatingPlanFreshness.current;

  /// Evaluates freshness for a [setup] given [profile] and [engine].
  static EatingPlanFreshness evaluate({
    required BaseTimelineSetup setup,
    required UserProfile profile,
    required EatingDomainEngine engine,
  }) {
    if (setup.eatingSetupPath != 'create') {
      return EatingPlanFreshness.current;
    }
    final savedFingerprint = setup.eatingGeneratedInputFingerprint;
    if (savedFingerprint == null || savedFingerprint.isEmpty) {
      return EatingPlanFreshness.current;
    }

    try {
      final targets = engine.calculateTargets(profile: profile, setup: setup);
      final currentInputs = engine.buildInputs(
        profile: profile,
        setup: setup,
        targets: targets,
      );
      final currentFingerprint = currentInputs.computeFingerprint();
      return currentFingerprint == savedFingerprint
          ? EatingPlanFreshness.current
          : EatingPlanFreshness.stale;
    } catch (_) {
      // Failure to calculate targets or build inputs (e.g. missing height/weight/age)
      // must NOT falsely report that the plan is current.
      return EatingPlanFreshness.unknown;
    }
  }
}
