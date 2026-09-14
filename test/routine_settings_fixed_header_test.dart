import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/routine/routine_tab.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  group('LiquidDetailScaffold fixedHeader', () {
    testWidgets(
      'when fixedHeader is true, header position remains stationary on scroll',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LiquidDetailScaffold(
                fixedHeader: true,
                eyebrow: 'Routine',
                title: 'Test Header',
                subtitle: 'Subtitle',
                accentColor: OptivusColors.routineAccent,
                onBack: () {},
                children: List.generate(
                  20,
                  (i) => Container(
                    key: ValueKey('item_$i'),
                    height: 100,
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final initialHeaderPos = tester.getTopLeft(find.text('Test Header'));

        // Drag content up to scroll down
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pumpAndSettle();

        final scrolledHeaderPos = tester.getTopLeft(find.text('Test Header'));
        expect(scrolledHeaderPos.dy, equals(initialHeaderPos.dy));
      },
    );

    testWidgets('when fixedHeader is false, header scrolls with content', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiquidDetailScaffold(
              fixedHeader: false,
              eyebrow: 'Routine',
              title: 'Scrolling Header',
              subtitle: 'Subtitle',
              accentColor: OptivusColors.routineAccent,
              onBack: () {},
              children: List.generate(
                20,
                (i) => Container(
                  key: ValueKey('item_$i'),
                  height: 100,
                  margin: const EdgeInsets.only(bottom: 12),
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialHeaderFinder = find.text('Scrolling Header');
      expect(initialHeaderFinder, findsOneWidget);
      final initialHeaderPos = tester.getTopLeft(initialHeaderFinder);

      // Drag content up slightly (e.g. 50px) to scroll down
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -50));
      await tester.pump();

      final scrolledHeaderPos = tester.getTopLeft(
        find.text('Scrolling Header'),
      );
      // In non-fixed mode, header scrolls up with content
      expect(scrolledHeaderPos.dy, lessThan(initialHeaderPos.dy));
    });
  });

  group('RoutineTab Routine Settings fixed header', () {
    testWidgets(
      'header in routine settings is fixed while scrolling and back button returns to timeline',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) =>
                    UserProfileNotifier()
                      ..loadSeedData(UserProfile.empty(uid: 'user-1')),
              ),
              routineRepositoryProvider.overrideWithValue(
                FakeRoutineRepository(),
              ),
              routineHistoryRepositoryProvider.overrideWithValue(
                FakeRoutineHistoryRepository(),
              ),
              routineTransactionRepositoryProvider.overrideWithValue(
                FakeRoutineTransactionRepository(),
              ),
            ],
            child: const MaterialApp(home: RoutineTab()),
          ),
        );
        await tester.pumpAndSettle();

        // Open routine settings via settings pill in RoutineHeader
        final settingsIcon = find.byIcon(Icons.settings_rounded);
        expect(settingsIcon, findsOneWidget);
        await tester.tap(settingsIcon);
        await tester.pumpAndSettle();

        // Verify Routine Settings is displayed
        final titleFinder = find.text('Routine Settings');
        expect(titleFinder, findsOneWidget);

        final initialTitlePos = tester.getTopLeft(titleFinder);

        // Scroll settings content
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pumpAndSettle();

        // Header title position must NOT change (header is fixed!)
        final afterScrollTitlePos = tester.getTopLeft(titleFinder);
        expect(afterScrollTitlePos.dy, equals(initialTitlePos.dy));

        // Back button is still visible and interactive
        final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
        expect(backButton, findsOneWidget);

        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // Returns to routine timeline
        expect(find.text('Routine Settings'), findsNothing);
        expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
      },
    );
  });
}
