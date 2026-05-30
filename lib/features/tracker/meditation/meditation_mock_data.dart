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

class MeditationCategoryUiModel {
  final String id;
  final String label;

  const MeditationCategoryUiModel({
    required this.id,
    required this.label,
  });
}

class MeditationSubCategoryUiModel {
  final String id;
  final String categoryId;
  final String label;

  const MeditationSubCategoryUiModel({
    required this.id,
    required this.categoryId,
    required this.label,
  });
}

class MeditationSoundUiModel {
  final String id;
  final String title;
  final String durationLabel;
  final String categoryId;
  final String subCategoryId;
  final String icon;
  final int sortOrder;
  final bool isActive;
  final bool isAssetAvailable;

  const MeditationSoundUiModel({
    required this.id,
    required this.title,
    this.durationLabel = '10 min',
    this.categoryId = '',
    this.subCategoryId = '',
    this.icon = '🎵',
    this.sortOrder = 0,
    this.isActive = true,
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

const mockMeditationCategories = [
  MeditationCategoryUiModel(id: 'healing_432hz', label: 'Healing 432 Hz'),
  MeditationCategoryUiModel(id: 'nature_sounds', label: 'Nature Sounds'),
  MeditationCategoryUiModel(id: 'ambient_atmospheric', label: 'Ambient & Atmospheric'),
];

const mockMeditationSubCategories = [
  MeditationSubCategoryUiModel(id: 'deep_healing', categoryId: 'healing_432hz', label: 'Deep Healing'),
  MeditationSubCategoryUiModel(id: 'om_mantra', categoryId: 'healing_432hz', label: 'Om Mantra'),
  MeditationSubCategoryUiModel(id: 'rain_sounds', categoryId: 'nature_sounds', label: 'Rain Sounds'),
  MeditationSubCategoryUiModel(id: 'ocean_water', categoryId: 'nature_sounds', label: 'Ocean Water'),
  MeditationSubCategoryUiModel(id: 'forest_wind_birds', categoryId: 'nature_sounds', label: 'Forest Wind & Birds'),
  MeditationSubCategoryUiModel(id: 'ambient_meditation', categoryId: 'ambient_atmospheric', label: 'Ambient Meditation'),
  MeditationSubCategoryUiModel(id: 'deep_space_meditation', categoryId: 'ambient_atmospheric', label: 'Deep Space Meditation'),
  MeditationSubCategoryUiModel(id: 'piano_meditation', categoryId: 'ambient_atmospheric', label: 'Piano Meditation'),
];

const mockMeditationSounds = [
  MeditationSoundUiModel(
    id: 'silent', 
    title: 'Silent', 
    durationLabel: '∞', 
    categoryId: 'none', 
    subCategoryId: 'none',
    icon: '🤫',
    isAssetAvailable: true,
  ),
  MeditationSoundUiModel(
    id: 'deep_healing_1',
    title: '432 Hz Deep Healing',
    durationLabel: '30 min',
    categoryId: 'healing_432hz',
    subCategoryId: 'deep_healing',
    icon: '✨',
    sortOrder: 1,
  ),
  MeditationSoundUiModel(
    id: 'deep_healing_2',
    title: 'Cellular Restoration',
    durationLabel: '45 min',
    categoryId: 'healing_432hz',
    subCategoryId: 'deep_healing',
    icon: '🧬',
    sortOrder: 2,
  ),
  MeditationSoundUiModel(
    id: 'om_chant_1',
    title: 'Morning Om Chants',
    durationLabel: '20 min',
    categoryId: 'healing_432hz',
    subCategoryId: 'om_mantra',
    icon: '🕉️',
    sortOrder: 1,
  ),
  MeditationSoundUiModel(
    id: 'rain_1',
    title: 'Heavy Rain & Thunder',
    durationLabel: '60 min',
    categoryId: 'nature_sounds',
    subCategoryId: 'rain_sounds',
    icon: '🌧️',
    sortOrder: 1,
  ),
  MeditationSoundUiModel(
    id: 'rain_2',
    title: 'Light Rain on Window',
    durationLabel: '40 min',
    categoryId: 'nature_sounds',
    subCategoryId: 'rain_sounds',
    icon: '💧',
    sortOrder: 2,
  ),
  MeditationSoundUiModel(
    id: 'ocean_1',
    title: 'Gentle Ocean Waves',
    durationLabel: '30 min',
    categoryId: 'nature_sounds',
    subCategoryId: 'ocean_water',
    icon: '🌊',
    sortOrder: 1,
  ),
  MeditationSoundUiModel(
    id: 'forest_1',
    title: 'Deep Forest Morning',
    durationLabel: '45 min',
    categoryId: 'nature_sounds',
    subCategoryId: 'forest_wind_birds',
    icon: '🌲',
    sortOrder: 1,
  ),
  MeditationSoundUiModel(
    id: 'ambient_1',
    title: 'Ethereal Calm',
    durationLabel: '20 min',
    categoryId: 'ambient_atmospheric',
    subCategoryId: 'ambient_meditation',
    icon: '☁️',
    sortOrder: 1,
  ),
  MeditationSoundUiModel(
    id: 'space_1',
    title: 'Deep Space Void',
    durationLabel: '60 min',
    categoryId: 'ambient_atmospheric',
    subCategoryId: 'deep_space_meditation',
    icon: '🌌',
    sortOrder: 1,
  ),
  MeditationSoundUiModel(
    id: 'piano_1',
    title: 'Soft Piano Melancholy',
    durationLabel: '15 min',
    categoryId: 'ambient_atmospheric',
    subCategoryId: 'piano_meditation',
    icon: '🎹',
    sortOrder: 1,
  ),
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
