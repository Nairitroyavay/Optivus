import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/state/upload_state.dart';

enum UploadInteractionPhase {
  empty,
  selected,
  preparing,
  uploading,
  uploaded,
  processing,
  failed,
  restored,
}

enum UploadRequirementMode {
  required,
  optional,
}

enum UploadInputMode {
  imageOnly,
  imageAndNames,
}

class UploadSlotConfig {
  final String key;
  final String label;
  final String title;
  final IconData icon;
  final UploadedAssetPurpose purpose;
  final bool required;
  final bool allowCamera;
  final bool allowGallery;
  final String? placeholderPrompt;
  final String? helperText;

  const UploadSlotConfig({
    required this.key,
    required this.label,
    required this.title,
    required this.icon,
    required this.purpose,
    this.required = true,
    this.allowCamera = true,
    this.allowGallery = true,
    this.placeholderPrompt,
    this.helperText,
  });
}

class UploadShellConfig {
  final String title;
  final String? subtitle;
  final Color accentColor;
  final UploadRequirementMode requirementMode;
  final UploadInputMode inputMode;
  final List<UploadSlotConfig> slots;

  const UploadShellConfig({
    required this.title,
    this.subtitle,
    this.accentColor = OptivusColors.brandAccent,
    this.requirementMode = UploadRequirementMode.required,
    this.inputMode = UploadInputMode.imageOnly,
    required this.slots,
  });

  bool get isDualSlot => slots.length == 2;
  UploadSlotConfig? slotFor(String key) =>
      slots.where((s) => s.key == key).firstOrNull;
}

class UploadSlotRuntimeState {
  final String slotKey;
  final UploadedAssetPurpose purpose;
  final bool isHydrating;
  final UploadInteractionPhase phase;

  // Authoritative AH-F010 Durable Asset State
  final UploadedAsset? durableAsset;
  final UploadedAssetPreviewStatus previewStatus;
  final Uri? remotePreviewUri;

  // Transient Interaction Attempt State
  final XFile? transientFile;
  final PreparedUploadImage? preparedImage;
  final String? attemptError;
  final int operationGeneration;

  const UploadSlotRuntimeState({
    required this.slotKey,
    required this.purpose,
    this.isHydrating = false,
    this.phase = UploadInteractionPhase.empty,
    this.durableAsset,
    this.previewStatus = UploadedAssetPreviewStatus.unavailable,
    this.remotePreviewUri,
    this.transientFile,
    this.preparedImage,
    this.attemptError,
    this.operationGeneration = 0,
  });

  bool get hasDurableAsset => durableAsset != null;

  bool get isBusy {
    return switch (phase) {
      UploadInteractionPhase.preparing ||
      UploadInteractionPhase.uploading ||
      UploadInteractionPhase.processing => true,
      _ => false,
    };
  }

  /// True ONLY when hydration is complete, no durable asset exists, and slot is empty.
  /// Strictly impossible when [isHydrating] is true.
  bool get isActionableEmpty =>
      !isHydrating && !hasDurableAsset && phase == UploadInteractionPhase.empty;

  UploadedAsset? get effectiveAsset => durableAsset;

  String? get usablePreviewPath => durableAsset != null
      ? usableUploadedAssetLocalPreviewPath(durableAsset!)
      : (preparedImage?.localPreviewPath ?? transientFile?.path);

  UploadSlotRuntimeState copyWith({
    String? slotKey,
    UploadedAssetPurpose? purpose,
    bool? isHydrating,
    UploadInteractionPhase? phase,
    UploadedAsset? durableAsset,
    UploadedAssetPreviewStatus? previewStatus,
    Uri? remotePreviewUri,
    XFile? transientFile,
    PreparedUploadImage? preparedImage,
    String? attemptError,
    int? operationGeneration,
    bool clearDurableAsset = false,
    bool clearTransientFile = false,
    bool clearPreparedImage = false,
    bool clearAttemptError = false,
    bool clearRemotePreviewUri = false,
  }) {
    return UploadSlotRuntimeState(
      slotKey: slotKey ?? this.slotKey,
      purpose: purpose ?? this.purpose,
      isHydrating: isHydrating ?? this.isHydrating,
      phase: phase ?? this.phase,
      durableAsset: clearDurableAsset ? null : (durableAsset ?? this.durableAsset),
      previewStatus: previewStatus ?? this.previewStatus,
      remotePreviewUri: clearRemotePreviewUri
          ? null
          : (remotePreviewUri ?? this.remotePreviewUri),
      transientFile: clearTransientFile
          ? null
          : (transientFile ?? this.transientFile),
      preparedImage: clearPreparedImage
          ? null
          : (preparedImage ?? this.preparedImage),
      attemptError: clearAttemptError ? null : (attemptError ?? this.attemptError),
      operationGeneration: operationGeneration ?? this.operationGeneration,
    );
  }
}
