import 'package:flutter/material.dart';

/// Centralized design constants for Optivus Auth screens.
///
/// Ensures strict visual consistency across Welcome, Auth Choice,
/// Create Account, Login, and Verify Email.
class AuthLayout {
  AuthLayout._();

  /// Canonical horizontal page padding across all auth screens.
  static const double horizontalPadding = 24.0;

  /// Canonical top inset from SafeArea for the back button.
  static const double backButtonTopInset = 16.0;

  /// Canonical bottom inset for top header / back button row.
  static const double backButtonBottomInset = 16.0;

  /// Canonical back button dimension (width & height).
  static const double backButtonSize = 32.0;

  /// Standard unified outer height for all auth text input fields.
  static const double standardFieldHeight = 50.0;

  /// Compact prefix icon container dimension inside AuthTextField.
  static const double iconContainerSize = 34.0;

  /// Standard gap between field label and input box.
  static const double labelToFieldGap = 5.0;

  /// Standard vertical gap between form fields in normal state.
  static const double fieldGap = 8.0;

  /// Form panel internal padding.
  static const EdgeInsets formPanelPadding = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 14.0,
  );

  /// Standard auth logo dimension.
  static const double standardLogoSize = 88.0;
}
