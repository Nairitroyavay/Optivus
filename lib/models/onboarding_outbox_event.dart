import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:optivus/models/routine_item.dart';

part 'onboarding_outbox_event.freezed.dart';
part 'onboarding_outbox_event.g.dart';

@freezed
class OnboardingOutboxEvent with _$OnboardingOutboxEvent {
  const factory OnboardingOutboxEvent({
    required String id,
    required String uid,
    required String projectionId,
    required RoutineItem item,
    required OnboardingOutboxEventStatus status,
    DateTime? createdAt,
    DateTime? processedAt,
    String? error,
  }) = _OnboardingOutboxEvent;

  factory OnboardingOutboxEvent.fromJson(Map<String, dynamic> json) =>
      _$OnboardingOutboxEventFromJson(json);
}

enum OnboardingOutboxEventStatus {
  pending,
  completed,
  failed,
}
