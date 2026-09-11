import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/services/uploads/authenticated_r2_preview_resolver.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/upload_state.dart';

class BaseTimelinePhotoPreviewCard extends ConsumerStatefulWidget {
  final String? r2Key;
  final String? assetId;
  final String title;
  final double height;

  const BaseTimelinePhotoPreviewCard({
    super.key,
    this.r2Key,
    this.assetId,
    this.title = 'Source Photo',
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

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(covariant BaseTimelinePhotoPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.r2Key != widget.r2Key ||
        oldWidget.assetId != widget.assetId) {
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    final key = widget.r2Key?.trim();
    if (key == null || key.isEmpty) {
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

    final resolver = ref.read(uploadedAssetPreviewResolverProvider);
    final uid = ref.read(userProfileProvider).uid;

    try {
      Uri? uri;
      if (resolver is AuthenticatedR2PreviewResolver) {
        uri = await resolver.resolveR2Key(uid: uid, r2Key: key);
      }
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

  void _showFullImage(BuildContext context, Uri uri) {
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
              child: Image.network(
                uri.toString(),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
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
    final key = widget.r2Key?.trim();
    if (key == null || key.isEmpty) {
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
            // Background blur / base
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ),

            if (_loading)
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
            else if (_previewUri != null)
              GestureDetector(
                onTap: () => _showFullImage(context, _previewUri!),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      _previewUri.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallbackContent(),
                    ),
                    // Gradient overlay
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 54,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.75),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.photo_size_select_actual_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Text(
                              'Tap to expand',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

  Widget _buildFallbackContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              color: OptivusColors.textSecondary.withValues(alpha: 0.7),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              widget.title,
              style: const TextStyle(
                color: OptivusColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Secure cloud storage',
              style: TextStyle(
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
