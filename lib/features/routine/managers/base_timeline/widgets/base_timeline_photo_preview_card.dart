import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/upload_state.dart';

/// Card component to display the source photo for a Base Timeline section.
///
/// Priority:
/// 1. If a valid [localPreviewPath] exists on the local filesystem, renders it
///    immediately without awaiting network or presigned token resolution.
/// 2. Resolves [r2Key] presigned URL asynchronously via [UploadedAssetPreviewResolver].
/// 3. Falls back gracefully to a calm placeholder if preview is unavailable.
class BaseTimelinePhotoPreviewCard extends ConsumerStatefulWidget {
  final String? r2Key;
  final String? assetId;
  final String? localPreviewPath;
  final String title;
  final String? subtitle;
  final double height;

  const BaseTimelinePhotoPreviewCard({
    super.key,
    this.r2Key,
    this.assetId,
    this.localPreviewPath,
    this.title = 'Source Photo',
    this.subtitle,
    this.height = 180,
  });

  @override
  ConsumerState<BaseTimelinePhotoPreviewCard> createState() =>
      _BaseTimelinePhotoPreviewCardState();
}

class _BaseTimelinePhotoPreviewCardState
    extends ConsumerState<BaseTimelinePhotoPreviewCard> {
  Uri? _previewUri;
  bool _loading = false;
  bool _failed = false;

  bool get _hasValidLocalPreview {
    final path = widget.localPreviewPath?.trim();
    if (path == null || path.isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (!_hasValidLocalPreview) {
      _loadPreview();
    }
  }

  @override
  void didUpdateWidget(covariant BaseTimelinePhotoPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localPreviewPath != widget.localPreviewPath ||
        oldWidget.r2Key != widget.r2Key ||
        oldWidget.assetId != widget.assetId) {
      if (!_hasValidLocalPreview) {
        _loadPreview();
      } else {
        setState(() {
          _previewUri = null;
          _loading = false;
          _failed = false;
        });
      }
    }
  }

  Future<void> _loadPreview() async {
    final key = widget.r2Key?.trim();
    final assetId = widget.assetId?.trim();
    if ((key == null || key.isEmpty) && (assetId == null || assetId.isEmpty)) {
      if (mounted) {
        setState(() {
          _previewUri = null;
          _loading = false;
          _failed = false;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _failed = false;
    });

    final uid = ref.read(userProfileProvider).uid;
    String? resolvedKey = key;

    if (resolvedKey == null || resolvedKey.isEmpty) {
      if (assetId != null && assetId.isNotEmpty) {
        try {
          final assetRepo = ref.read(uploadedAssetRepositoryProvider);
          final asset = await assetRepo.fetchAsset(uid: uid, assetId: assetId);
          if (asset != null && asset.r2Key.isNotEmpty) {
            resolvedKey = asset.r2Key;
          }
        } catch (_) {}
      }
    }

    if (resolvedKey == null || resolvedKey.isEmpty) {
      if (mounted) {
        setState(() {
          _previewUri = null;
          _loading = false;
          _failed = true;
        });
      }
      return;
    }

    final resolver = ref.read(uploadedAssetPreviewResolverProvider);

    try {
      final uri = await resolver.resolveKey(uid: uid, objectKey: resolvedKey);
      if (mounted) {
        setState(() {
          _previewUri = uri;
          _loading = false;
          _failed = uri == null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _showFullImage(
    BuildContext context, {
    Uri? networkUri,
    String? localPath,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: localPath != null
                  ? Image.file(
                      File(localPath),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                    )
                  : Image.network(
                      networkUri.toString(),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.6),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLocal = _hasValidLocalPreview;
    final key = widget.r2Key?.trim();
    final assetId = widget.assetId?.trim();
    if (!hasLocal &&
        (key == null || key.isEmpty) &&
        (assetId == null || assetId.isEmpty)) {
      return const SizedBox.shrink();
    }

    final radius = BorderRadius.circular(18);

    return Container(
      height: widget.height,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black.withValues(alpha: 0.25)),

            if (hasLocal)
              GestureDetector(
                onTap: () => _showFullImage(
                  context,
                  localPath: widget.localPreviewPath!,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(widget.localPreviewPath!),
                      fit: BoxFit.cover,
                      cacheWidth: 800,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackContent(),
                    ),
                    _buildOverlayBar(),
                  ],
                ),
              )
            else if (_loading)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Loading ${widget.title.toLowerCase()}...',
                      style: const TextStyle(
                        fontSize: 12,
                        color: OptivusColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else if (_previewUri != null && !_failed)
              GestureDetector(
                onTap: () => _showFullImage(context, networkUri: _previewUri!),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      _previewUri.toString(),
                      fit: BoxFit.cover,
                      cacheWidth: 800,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackContent(),
                    ),
                    _buildOverlayBar(),
                  ],
                ),
              )
            else
              _buildFallbackContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 54,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            const Icon(
              Icons.photo_size_select_actual_outlined,
              color: Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.subtitle != null &&
                      widget.subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      widget.subtitle!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.fullscreen_rounded,
              color: Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 4),
            const Text(
              'Tap to view',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackContent() {
    final isCompact = widget.height < 120;
    final isPhotoSavedUnavailable =
        widget.assetId != null && (widget.r2Key == null || _failed);

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isCompact ? 6 : 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              color: OptivusColors.textSecondary.withValues(alpha: 0.7),
              size: isCompact ? 24 : 32,
            ),
            SizedBox(height: isCompact ? 4 : 8),
            Text(
              widget.title,
              style: const TextStyle(
                color: OptivusColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isPhotoSavedUnavailable
                  ? (widget.subtitle != null &&
                            widget.subtitle!.trim().isNotEmpty
                        ? 'Preview unavailable · ${widget.subtitle!.trim()}'
                        : 'Timetable photo saved · Preview unavailable')
                  : (widget.subtitle != null &&
                            widget.subtitle!.trim().isNotEmpty
                        ? widget.subtitle!.trim()
                        : (_failed
                              ? 'Preview unavailable'
                              : 'Secure cloud storage')),
              style: const TextStyle(
                color: OptivusColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
