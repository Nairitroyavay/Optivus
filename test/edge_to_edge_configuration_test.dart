import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/views/screens/auth_choice_screen.dart';

void main() {
  group('Android edge-to-edge configuration', () {
    test('uses edge-to-edge and never requests immersive fullscreen', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      final appSource = File('lib/app/optivus_app.dart').readAsStringSync();
      final themeSource = File(
        'lib/core/theme/optivus_theme.dart',
      ).readAsStringSync();
      final styleSources = [
        File('android/app/src/main/res/values/styles.xml').readAsStringSync(),
        File(
          'android/app/src/main/res/values-night/styles.xml',
        ).readAsStringSync(),
      ].join();

      expect(mainSource, contains('SystemUiMode.edgeToEdge'));
      expect(mainSource, isNot(contains('SystemUiMode.immersive')));
      expect(appSource, contains('AnnotatedRegion<SystemUiOverlayStyle>'));
      expect(
        themeSource,
        contains('systemNavigationBarColor: Color(0xFFFCF8EE)'),
      );
      expect(styleSources, isNot(contains('windowFullscreen')));
      expect(styleSources, contains('windowDrawsSystemBarBackgrounds'));
      expect(
        styleSources,
        contains(
          '<item name="android:statusBarColor">'
          '@color/optivus_cream</item>',
        ),
      );
    });

    testWidgets('background fills the window while content respects insets', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const topInset = 115 / 3;
      const bottomInset = 132 / 3;
      const media = MediaQueryData(
        size: Size(360, 800),
        padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
        viewPadding: EdgeInsets.only(top: topInset, bottom: bottomInset),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(data: media, child: AuthChoiceScreen()),
        ),
      );

      final background = find.byKey(const Key('auth-choice-background'));
      final safeContent = find.byKey(const Key('auth-choice-safe-content'));

      expect(tester.getTopLeft(background), Offset.zero);
      expect(tester.getSize(background), const Size(360, 800));
      expect(tester.getTopLeft(safeContent).dy, closeTo(topInset, 0.01));
      expect(
        tester.getBottomRight(safeContent).dy,
        closeTo(800 - bottomInset, 0.01),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
