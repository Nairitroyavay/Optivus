import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

class BaseTimelineFormSheet extends StatelessWidget {
  final String title;
  final bool isEdit;
  final Widget content;
  final VoidCallback onSave;
  final VoidCallback? onDelete;

  const BaseTimelineFormSheet({
    super.key,
    required this.title,
    required this.isEdit,
    required this.content,
    required this.onSave,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
          decoration: const BoxDecoration(
            color: OptivusColors.routineBgBottom,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + media.padding.bottom),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isEdit && onDelete != null)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: OptivusColors.danger,
                        ),
                        onPressed: onDelete,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                content,
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OptivusColors.routineAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: onSave,
                    child: Text(
                      isEdit ? 'Save Changes' : 'Add Block',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
