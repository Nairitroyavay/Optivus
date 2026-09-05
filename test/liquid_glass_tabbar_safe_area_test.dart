import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/widgets/liquid_glass_tabbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpTabBar(
    WidgetTester tester, {
    required double bottomViewPadding,
  }) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(393, 873),
            viewPadding: EdgeInsets.only(bottom: bottomViewPadding),
          ),
          child: Scaffold(
            extendBody: true,
            body: const SizedBox.expand(),
            bottomNavigationBar: LiquidGlassTabBar(
              currentIndex: 0,
              onTap: (_) {},
              activeColor: Colors.blue,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('glass frame keeps an intentional gap above bottom safe region', (
    tester,
  ) async {
    await pumpTabBar(tester, bottomViewPadding: 0);

    final zeroInsetRect = tester.getRect(
      find.byKey(const ValueKey('liquid-glass-tabbar-frame')),
    );
    expect(zeroInsetRect.height, 72);
    expect(zeroInsetRect.bottom, 873 - 10);

    await pumpTabBar(tester, bottomViewPadding: 32);

    final androidInsetRect = tester.getRect(
      find.byKey(const ValueKey('liquid-glass-tabbar-frame')),
    );
    expect(androidInsetRect.height, 72);
    expect(androidInsetRect.bottom, 873 - 32 - 10);
  });
}
