import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_outbox_event.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';

class OnboardingOutboxProjector {
  final FirebaseFirestore _firestore;
  final RoutineTemplateFirestoreCodec _routineCodec;

  OnboardingOutboxProjector(this._firestore, this._routineCodec);

  Future<void> runProjection(OnboardingCompletionBundle bundle) async {
    final plan = RoutineOnboardingProjection.build(bundle);
    final uid = bundle.uid;
    
    // Write outbox events in chunks (e.g. 100 at a time) to avoid limits
    // Then process outbox items.
    // For now, this is a skeleton implementation.
    
    // In a full implementation:
    // 1. Generate OnboardingOutboxEvent for each item in plan.items
    // 2. Write them to FirestoreUserPaths.onboardingOutboxEvent(uid, event.id)
    // 3. Start a worker to read pending events and execute them.
  }
}

final onboardingOutboxProjectorProvider = Provider((ref) {
  return OnboardingOutboxProjector(
    FirebaseFirestore.instance,
    const RoutineTemplateFirestoreCodec(),
  );
});
