import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/auth_layout.dart';
import 'package:optivus/core/utils/focus_utils.dart';

const Color _kAmber = Color(0xFFFFB830);
const Color _kInk = Color(0xFF1E202A);

/// Canonical unified compact liquid-glass text field used across all
/// Optivus Auth screens (Signup, Login, Forgot Password, Reset, etc.).
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final FocusNode? next;
  final Widget? suffix;
  final void Function(String)? onSubmit;
  final Iterable<String>? autofillHints;
  final String? semanticLabel;
  final TextInputAction? textInputAction;
  final double height;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.next,
    this.suffix,
    this.onSubmit,
    this.autofillHints,
    this.semanticLabel,
    this.textInputAction,
    this.height = AuthLayout.standardFieldHeight,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_handleFocusChanged);
  }

  void _handleFocusChanged() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveInputAction =
        widget.textInputAction ??
        (widget.next != null ? TextInputAction.next : TextInputAction.done);

    return Semantics(
      label: widget.semanticLabel ?? widget.hint,
      textField: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _focused ? 0.28 : 0.18),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: _focused
                ? _kAmber.withValues(alpha: 0.70)
                : Colors.white.withValues(alpha: 0.85),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _focused
                  ? _kAmber.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: _focused ? 18 : 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.50),
              blurRadius: 16,
              spreadRadius: -2,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.5),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Top-left specular rim
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28.5),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.0, 0.15, 0.4, 1.0],
                        colors: [
                          Colors.white.withValues(alpha: 0.95),
                          Colors.white.withValues(alpha: 0.40),
                          Colors.white.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.03),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    obscureText: widget.obscure,
                    keyboardType: widget.keyboardType,
                    autofillHints: widget.autofillHints,
                    scrollPadding: EdgeInsets.zero,
                    onTapOutside: dismissPrimaryFocusOnTapOutside,
                    textInputAction: effectiveInputAction,
                    textAlignVertical: TextAlignVertical.center,
                    onSubmitted:
                        widget.onSubmit ??
                        (_) {
                          if (widget.next != null) {
                            FocusScope.of(context).requestFocus(widget.next);
                          } else {
                            FocusManager.instance.primaryFocus?.unfocus();
                          }
                        },
                    style: const TextStyle(
                      color: _kInk,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                    cursorColor: _kAmber,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: AuthLayout.standardFieldHeight,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 7, right: 7),
                        child: Container(
                          width: AuthLayout.iconContainerSize,
                          height: AuthLayout.iconContainerSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            color: Colors.white.withValues(alpha: 0.25),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                offset: const Offset(1.5, 1.5),
                                blurRadius: 4,
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.6),
                                offset: const Offset(-1.5, -1.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.icon,
                            color: _focused ? _kAmber : _kInk,
                            size: 18,
                          ),
                        ),
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: AuthLayout.standardFieldHeight,
                      ),
                      suffixIcon: widget.suffix,
                      hintText: widget.hint,
                      hintStyle: TextStyle(
                        color: _kInk.withValues(alpha: 0.40),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                      border: InputBorder.none,
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

/// Compact eye toggle button designed specifically for AuthTextField.
class AuthEyeButton extends StatelessWidget {
  final bool obscure;
  final VoidCallback onToggle;

  const AuthEyeButton({
    super.key,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: obscure ? 'Show password' : 'Hide password',
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: IconButton(
          iconSize: 19,
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey.shade600,
          ),
          tooltip: obscure ? 'Show password' : 'Hide password',
          onPressed: onToggle,
        ),
      ),
    );
  }
}
