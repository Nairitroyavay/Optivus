import 'package:flutter/material.dart';
import 'package:optivus/core/liquid_ui/liquid_ui.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

class MeditationSessionTypeUiModel {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int inhaleSeconds;
  final int holdSeconds;
  final int exhaleSeconds;
  final Color accentToken;
  final String subtitle;

  const MeditationSessionTypeUiModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.inhaleSeconds,
    required this.holdSeconds,
    required this.exhaleSeconds,
    required this.accentToken,
    required this.subtitle,
  });
}

class MeditationSoundUiModel {
  final String id;
  final String title;
  final bool isAssetAvailable;

  const MeditationSoundUiModel({
    required this.id,
    required this.title,
    this.isAssetAvailable = false,
  });
}

class MeditationSessionUiModel {
  final String dateLabel;
  final String type;
  final int durationMinutes;
  final String status;

  const MeditationSessionUiModel({
    required this.dateLabel,
    required this.type,
    required this.durationMinutes,
    required this.status,
  });
}

const mockMeditationSessionTypes = [
  MeditationSessionTypeUiModel(
    id: 'calm',
    title: 'Calm',
    description: 'Reset your mind.',
    icon: '🧘',
    inhaleSeconds: 4,
    holdSeconds: 2,
    exhaleSeconds: 6,
    accentToken: kPurple,
    subtitle: 'Slow, steady breathing to center yourself.',
  ),
  MeditationSessionTypeUiModel(
    id: 'focus',
    title: 'Focus',
    description: 'Prepare for deep work.',
    icon: '🎯',
    inhaleSeconds: 4,
    holdSeconds: 2,
    exhaleSeconds: 4,
    accentToken: kBlue,
    subtitle: 'Alert but calm state for clear thinking.',
  ),
  MeditationSessionTypeUiModel(
    id: 'sleep',
    title: 'Sleep',
    description: 'Wind down gently.',
    icon: '😴',
    inhaleSeconds: 4,
    holdSeconds: 4,
    exhaleSeconds: 8,
    accentToken: OptivusColors.trackerAccent,
    subtitle: 'Deep relaxation to prepare for rest.',
  ),
  MeditationSessionTypeUiModel(
    id: 'anxiety',
    title: 'Anxiety',
    description: 'Slow down the body first.',
    icon: '🫂',
    inhaleSeconds: 3,
    holdSeconds: 2,
    exhaleSeconds: 6,
    accentToken: kRose,
    subtitle: 'Regulate your nervous system gently.',
  ),
];

const mockMeditationSounds = [
  MeditationSoundUiModel(id: 'silent', title: 'Silent', isAssetAvailable: true),
  MeditationSoundUiModel(id: 'rain', title: 'Rain'),
  MeditationSoundUiModel(id: 'ocean', title: 'Ocean Waves'),
  MeditationSoundUiModel(id: 'wind', title: 'Gentle Wind'),
  MeditationSoundUiModel(id: 'deep_calm', title: 'Deep Calm'),
  MeditationSoundUiModel(id: '432hz', title: '432 Hz Healing'),
];

const mockRecentSessions = [
  MeditationSessionUiModel(
    dateLabel: 'Today',
    type: 'Calm',
    durationMinutes: 5,
    status: 'Completed',
  ),
  MeditationSessionUiModel(
    dateLabel: 'Yesterday',
    type: 'Focus',
    durationMinutes: 10,
    status: 'Completed',
  ),
  MeditationSessionUiModel(
    dateLabel: 'May 27',
    type: 'Sleep',
    durationMinutes: 5,
    status: 'Completed',
  ),
  MeditationSessionUiModel(
    dateLabel: 'May 26',
    type: 'Anxiety',
    durationMinutes: 3,
    status: 'Partial',
  ),
];
