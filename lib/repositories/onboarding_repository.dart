import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';

abstract class OnboardingRepository {
  Future<OnboardingDraft?> fetchDraft(String uid);
  Future<void> saveDraft(OnboardingDraft draft);
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle);
}

class FakeOnboardingRepository implements OnboardingRepository {
  final Map<String, OnboardingDraft> _drafts = {};
  final Map<String, OnboardingCompletionBundle> _bundles = {};

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _drafts[uid];
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    await Future.delayed(const Duration(milliseconds: 600));
    _drafts[draft.uid] = draft;
  }

  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _bundles[bundle.uid] = bundle;
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return FakeOnboardingRepository();
});
