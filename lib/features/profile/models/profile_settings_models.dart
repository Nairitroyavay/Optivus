import 'package:cloud_firestore/cloud_firestore.dart';

enum ProfileConnectionStatus { connected, notConnected, notConfigured, error }

extension ProfileConnectionStatusLabel on ProfileConnectionStatus {
  String get label {
    return switch (this) {
      ProfileConnectionStatus.connected => 'Connected',
      ProfileConnectionStatus.notConnected => 'Not connected',
      ProfileConnectionStatus.notConfigured => 'Not configured',
      ProfileConnectionStatus.error => 'Error',
    };
  }
}

enum ProfilePermissionType {
  notifications,
  usageAccess,
  location,
  healthConnect,
  cameraPhotos,
  microphone,
}

extension ProfilePermissionTypeLabel on ProfilePermissionType {
  String get label {
    return switch (this) {
      ProfilePermissionType.notifications => 'Notifications',
      ProfilePermissionType.usageAccess => 'Usage Access',
      ProfilePermissionType.location => 'Location',
      ProfilePermissionType.healthConnect => 'Health Connect',
      ProfilePermissionType.cameraPhotos => 'Camera / Photos',
      ProfilePermissionType.microphone => 'Microphone',
    };
  }

  String get reason {
    return switch (this) {
      ProfilePermissionType.notifications =>
        'Needed for reminders, weekly reviews, proof prompts, and comeback nudges.',
      ProfilePermissionType.usageAccess =>
        'Needed for Screen Time Tracker, doom scrolling risk, and app usage insights.',
      ProfilePermissionType.location =>
        'Needed for walk/run route tracking and distance proof.',
      ProfilePermissionType.healthConnect =>
        'Needed for steps, sleep, calories, workouts, and heart rate.',
      ProfilePermissionType.cameraPhotos =>
        'Needed for profile photos, timetable uploads, meal-plan sheets, and skin care photos.',
      ProfilePermissionType.microphone => 'Needed for Coach voice input.',
    };
  }

  String get systems {
    return switch (this) {
      ProfilePermissionType.notifications =>
        'Routine, Goals, Tracker, Coach, Money System',
      ProfilePermissionType.usageAccess => 'Screen Time Tracker, Coach context',
      ProfilePermissionType.location => 'Fitness Center, Walk/Run maps',
      ProfilePermissionType.healthConnect =>
        'Fitness Center, Sleep/Nutrition later',
      ProfilePermissionType.cameraPhotos =>
        'Profile, Routine imports, Skin Care, future export previews',
      ProfilePermissionType.microphone => 'Coach voice input',
    };
  }

  String get primaryAction {
    return switch (this) {
      ProfilePermissionType.notifications =>
        'Open Android notification settings',
      ProfilePermissionType.usageAccess => 'Open Android Usage Access settings',
      ProfilePermissionType.location => 'Open Android location settings',
      ProfilePermissionType.healthConnect => 'Open Health Connect settings',
      ProfilePermissionType.cameraPhotos => 'Open Android media settings',
      ProfilePermissionType.microphone => 'Open Android microphone settings',
    };
  }
}

class PermissionStatusModel {
  final ProfilePermissionType type;
  final ProfileConnectionStatus status;
  final String lastChecked;
  final bool liveCheckCapable;
  final String sourceOfTruth;

  const PermissionStatusModel({
    required this.type,
    required this.status,
    required this.lastChecked,
    this.liveCheckCapable = true,
    this.sourceOfTruth = 'Last known status',
  });

  PermissionStatusModel copyWith({
    ProfileConnectionStatus? status,
    String? lastChecked,
  }) {
    return PermissionStatusModel(
      type: type,
      status: status ?? this.status,
      lastChecked: lastChecked ?? this.lastChecked,
      liveCheckCapable: liveCheckCapable,
      sourceOfTruth: sourceOfTruth,
    );
  }
}

enum ConnectedServiceType {
  cloudflareR2,
  mapbox,
  healthConnect,
  androidUsageAccess,
  cloudflareWorkers,
}

extension ConnectedServiceTypeLabel on ConnectedServiceType {
  String get label {
    return switch (this) {
      ConnectedServiceType.cloudflareR2 => 'Cloudflare R2 Uploads',
      ConnectedServiceType.mapbox => 'Mapbox',
      ConnectedServiceType.healthConnect => 'Health Connect',
      ConnectedServiceType.androidUsageAccess => 'Android Usage Access',
      ConnectedServiceType.cloudflareWorkers => 'Cloudflare Workers',
    };
  }

  String get powers {
    return switch (this) {
      ConnectedServiceType.cloudflareR2 =>
        'Profile photos, timetable uploads, meal-plan sheets, skin care photos, and future exported files.',
      ConnectedServiceType.mapbox =>
        'Walk/Run maps, route tracking, and map style selection.',
      ConnectedServiceType.healthConnect =>
        'Steps, sleep, calories, workouts, heart rate, and health aggregates.',
      ConnectedServiceType.androidUsageAccess =>
        'Screen Time Tracker, top apps, focus-loss windows, and doom scrolling risk.',
      ConnectedServiceType.cloudflareWorkers =>
        'Coach AI, Routine import AI, and future export generation jobs.',
    };
  }
}

class ConnectedServiceStatusModel {
  final ConnectedServiceType type;
  final ProfileConnectionStatus status;
  final String lastChecked;
  final String? selectedStyle;

  const ConnectedServiceStatusModel({
    required this.type,
    required this.status,
    required this.lastChecked,
    this.selectedStyle,
  });

  ConnectedServiceStatusModel copyWith({
    ProfileConnectionStatus? status,
    String? lastChecked,
    String? selectedStyle,
  }) {
    return ConnectedServiceStatusModel(
      type: type,
      status: status ?? this.status,
      lastChecked: lastChecked ?? this.lastChecked,
      selectedStyle: selectedStyle ?? this.selectedStyle,
    );
  }
}

class UserProfileSettings {
  final String name;
  final String username;
  final String bio;
  final bool customIdentityDisplay;
  final String photoState;

  const UserProfileSettings({
    this.name = '',
    this.username = '',
    this.bio = '',
    this.customIdentityDisplay = false,
    this.photoState = 'No photo uploaded',
  });

  UserProfileSettings copyWith({
    String? name,
    String? username,
    String? bio,
    bool? customIdentityDisplay,
    String? photoState,
  }) {
    return UserProfileSettings(
      name: name ?? this.name,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      customIdentityDisplay:
          customIdentityDisplay ?? this.customIdentityDisplay,
      photoState: photoState ?? this.photoState,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'username': username,
      'bio': bio,
      'customIdentityDisplay': customIdentityDisplay,
      'photoState': photoState,
    };
  }

  Map<String, Object?> toFirestoreMap() => toMap();

  factory UserProfileSettings.fromMap(Map<String, dynamic> map) {
    return UserProfileSettings(
      name: map['name'] as String? ?? '',
      username: map['username'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      customIdentityDisplay: map['customIdentityDisplay'] as bool? ?? false,
      photoState: map['photoState'] as String? ?? 'No photo uploaded',
    );
  }

  factory UserProfileSettings.fromFirestoreMap(Map<String, dynamic> map) {
    return UserProfileSettings.fromMap(map);
  }
}

class NotificationSettingsModel {
  final Map<String, bool> reminderTypes;
  final String intensity;
  final bool quietAfter11;
  final bool quietDuringHardBlocks;
  final bool quietDuringSleep;
  final ProfileConnectionStatus permissionStatus;

  const NotificationSettingsModel({
    required this.reminderTypes,
    this.intensity = 'Medium',
    this.quietAfter11 = true,
    this.quietDuringHardBlocks = true,
    this.quietDuringSleep = true,
    this.permissionStatus = ProfileConnectionStatus.notConnected,
  });

  factory NotificationSettingsModel.defaults() {
    return const NotificationSettingsModel(
      reminderTypes: {
        'Morning start': true,
        'Next task': true,
        'Eating': true,
        'Bad habit check-in': true,
        'Savings': true,
        'Night reflection': false,
        'Goal proof pending': true,
        'Weekly review': true,
        'Coach comeback reminder': true,
      },
    );
  }

  NotificationSettingsModel copyWith({
    Map<String, bool>? reminderTypes,
    String? intensity,
    bool? quietAfter11,
    bool? quietDuringHardBlocks,
    bool? quietDuringSleep,
    ProfileConnectionStatus? permissionStatus,
  }) {
    return NotificationSettingsModel(
      reminderTypes: reminderTypes ?? this.reminderTypes,
      intensity: intensity ?? this.intensity,
      quietAfter11: quietAfter11 ?? this.quietAfter11,
      quietDuringHardBlocks:
          quietDuringHardBlocks ?? this.quietDuringHardBlocks,
      quietDuringSleep: quietDuringSleep ?? this.quietDuringSleep,
      permissionStatus: permissionStatus ?? this.permissionStatus,
    );
  }
}

class UserPreferences {
  final String id;
  final String bio;
  final String avatarUrl;
  final String theme;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool haptics;
  final bool autoCorrect;
  final String themeMode;
  final String accentColor;
  final String bottomTabLayout;
  final String timelineDisplay;
  final String coachVoice;

  const UserPreferences({
    this.id = 'main',
    this.bio = '',
    this.avatarUrl = '',
    this.theme = 'system',
    this.createdAt,
    this.updatedAt,
    this.haptics = true,
    this.autoCorrect = true,
    this.themeMode = 'System',
    this.accentColor = 'Yellow',
    this.bottomTabLayout = 'Icons',
    this.timelineDisplay = 'Timeline',
    this.coachVoice = 'Text first',
  });

  UserPreferences copyWith({
    String? id,
    String? bio,
    String? avatarUrl,
    String? theme,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? haptics,
    bool? autoCorrect,
    String? themeMode,
    String? accentColor,
    String? bottomTabLayout,
    String? timelineDisplay,
    String? coachVoice,
  }) {
    return UserPreferences(
      id: id ?? this.id,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      theme: theme ?? this.theme,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      haptics: haptics ?? this.haptics,
      autoCorrect: autoCorrect ?? this.autoCorrect,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      bottomTabLayout: bottomTabLayout ?? this.bottomTabLayout,
      timelineDisplay: timelineDisplay ?? this.timelineDisplay,
      coachVoice: coachVoice ?? this.coachVoice,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'theme': theme,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      'haptics': haptics,
      'autoCorrect': autoCorrect,
      'themeMode': themeMode,
      'accentColor': accentColor,
      'bottomTabLayout': bottomTabLayout,
      'timelineDisplay': timelineDisplay,
      'coachVoice': coachVoice,
    };
  }

  Map<String, Object?> toFirestoreMap() {
    return {
      'id': id,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'theme': theme,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'haptics': haptics,
      'autoCorrect': autoCorrect,
      'themeMode': themeMode,
      'accentColor': accentColor,
      'bottomTabLayout': bottomTabLayout,
      'timelineDisplay': timelineDisplay,
      'coachVoice': coachVoice,
      'schemaVersion': 1,
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      id: map['id'] as String? ?? 'main',
      bio: map['bio'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String? ?? '',
      theme: map['theme'] as String? ?? map['themeMode'] as String? ?? 'system',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : (map['createdAt'] is String
                ? DateTime.tryParse(map['createdAt'] as String)
                : null),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : (map['updatedAt'] is String
                ? DateTime.tryParse(map['updatedAt'] as String)
                : null),
      haptics: map['haptics'] as bool? ?? true,
      autoCorrect: map['autoCorrect'] as bool? ?? true,
      themeMode: map['themeMode'] as String? ?? 'System',
      accentColor: map['accentColor'] as String? ?? 'Yellow',
      bottomTabLayout: map['bottomTabLayout'] as String? ?? 'Icons',
      timelineDisplay: map['timelineDisplay'] as String? ?? 'Timeline',
      coachVoice: map['coachVoice'] as String? ?? 'Text first',
    );
  }

  factory UserPreferences.fromFirestoreMap(Map<String, dynamic> map) {
    return UserPreferences.fromMap(map);
  }
}

class PrivacySettings {
  final bool appLock;
  final bool hideMindPreviews;
  final bool lockMindNotebook;
  final bool coachRoutine;
  final bool coachTracker;
  final bool coachGoals;
  final bool coachScreenTime;
  final bool coachMoney;
  final bool coachSelectedNotesOnly;
  final String screenTimePrivacyMode;

  const PrivacySettings({
    this.appLock = false,
    this.hideMindPreviews = true,
    this.lockMindNotebook = false,
    this.coachRoutine = true,
    this.coachTracker = true,
    this.coachGoals = true,
    this.coachScreenTime = false,
    this.coachMoney = true,
    this.coachSelectedNotesOnly = true,
    this.screenTimePrivacyMode = 'Show app names',
  });

  PrivacySettings copyWith({
    bool? appLock,
    bool? hideMindPreviews,
    bool? lockMindNotebook,
    bool? coachRoutine,
    bool? coachTracker,
    bool? coachGoals,
    bool? coachScreenTime,
    bool? coachMoney,
    bool? coachSelectedNotesOnly,
    String? screenTimePrivacyMode,
  }) {
    return PrivacySettings(
      appLock: appLock ?? this.appLock,
      hideMindPreviews: hideMindPreviews ?? this.hideMindPreviews,
      lockMindNotebook: lockMindNotebook ?? this.lockMindNotebook,
      coachRoutine: coachRoutine ?? this.coachRoutine,
      coachTracker: coachTracker ?? this.coachTracker,
      coachGoals: coachGoals ?? this.coachGoals,
      coachScreenTime: coachScreenTime ?? this.coachScreenTime,
      coachMoney: coachMoney ?? this.coachMoney,
      coachSelectedNotesOnly:
          coachSelectedNotesOnly ?? this.coachSelectedNotesOnly,
      screenTimePrivacyMode:
          screenTimePrivacyMode ?? this.screenTimePrivacyMode,
    );
  }
}

enum DataExportStatus { none, requested, processing, ready, failed, expired }

extension DataExportStatusLabel on DataExportStatus {
  String get label {
    return switch (this) {
      DataExportStatus.none => 'No request',
      DataExportStatus.requested => 'Requested',
      DataExportStatus.processing => 'Processing',
      DataExportStatus.ready => 'Ready',
      DataExportStatus.failed => 'Failed',
      DataExportStatus.expired => 'Expired',
    };
  }
}

class DataExportRequestModel {
  final String id;
  final Set<String> scopes;
  final String format;
  final DataExportStatus status;
  final DateTime requestedAt;
  final DateTime? expiresAt;

  const DataExportRequestModel({
    required this.id,
    required this.scopes,
    required this.format,
    required this.status,
    required this.requestedAt,
    this.expiresAt,
  });

  DataExportRequestModel copyWith({
    Set<String>? scopes,
    String? format,
    DataExportStatus? status,
    DateTime? expiresAt,
  }) {
    return DataExportRequestModel(
      id: id,
      scopes: scopes ?? this.scopes,
      format: format ?? this.format,
      status: status ?? this.status,
      requestedAt: requestedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

class DeletionRequestModel {
  final bool pending;
  final DateTime? requestedAt;
  final DateTime? cancellationDeadline;

  const DeletionRequestModel({
    this.pending = false,
    this.requestedAt,
    this.cancellationDeadline,
  });
}
