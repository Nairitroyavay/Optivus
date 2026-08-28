import 'package:flutter/widgets.dart';

void dismissPrimaryFocusOnTapOutside(PointerDownEvent _) {
  FocusManager.instance.primaryFocus?.unfocus();
}
