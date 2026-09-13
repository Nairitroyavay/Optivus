import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_day_chips.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_current_setup_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_review_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_source_selection_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/class_timeline_card.dart';
import 'package:optivus/models/onboarding_draft.dart';

void main() {
  group('Base Timeline Family: Header Hierarchy & Actions', () {
    testWidgets(
      'Classes Current Setup header has 18px title, truthful snapshot summary, and top-right Change setup CTA',
      (tester) async {
        final setup = BaseTimelineSetup(
          uid: 'user-family-test',
          updatedAt: DateTime.now(),
          classLogicalAssetR2Key: 'test/classes.jpg',
          classBlocks: const [
            TimelineBlockDraft(
              id: 'c1',
              section: 'classes',
              title: 'Algorithms',
              startMinute: 600,
              endMinute: 690,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final blocks = <ClassRoutineBlock>[
          ClassRoutineBlock(
            id: 'c1',
            subject: 'Algorithms',
            startMinute: 600,
            endMinute: 690,
            repeatDays: [1],
          ),
        ];

        bool changedSetup = false;
        bool backPressed = false;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ClassesCurrentSetupView(
                  setup: setup,
                  routineBlocks: blocks,
                  selectedDay: 1,
                  onDayChanged: (_) {},
                  onBack: () => backPressed = true,
                  onChangeSetup: () => changedSetup = true,
                  onRemoveSetup: () {},
                ),
              ),
            ),
          ),
        );

        // Header Title 18px
        final titleFinder = find.text('Classes');
        expect(titleFinder, findsOneWidget);
        final titleText = tester.widget<Text>(titleFinder);
        expect(titleText.style?.fontSize, 18);
        expect(titleText.style?.fontWeight, FontWeight.w800);

        // Header Summary uses 'classes', not 'blocks'
        expect(find.text('Timetable photo · 1 classes'), findsOneWidget);

        // Top-right Change setup FilledButton.icon with Icons.edit_calendar_rounded
        final changeSetupFinder = find.widgetWithText(
          FilledButton,
          'Change setup',
        );
        expect(changeSetupFinder, findsOneWidget);
        expect(find.byIcon(Icons.edit_calendar_rounded), findsOneWidget);

        // Tap Change setup
        await tester.tap(changeSetupFinder);
        expect(changedSetup, isTrue);

        // Tap Back button
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        expect(backPressed, isTrue);

        // No bottom CTA button panel exists in Current Setup
        expect(find.text('Use this timetable'), findsNothing);
      },
    );

    testWidgets('Header responds to narrow width 360px and text scale 1.5', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final setup = BaseTimelineSetup(
        uid: 'user-scale-test',
        updatedAt: DateTime.now(),
        classLogicalAssetR2Key: 'test/classes.jpg',
        classBlocks: const [
          TimelineBlockDraft(
            id: 'c1',
            section: 'classes',
            title: 'Very Long Class Name For Testing Overflow Resilience',
            startMinute: 600,
            endMinute: 660,
            repeatDays: [1, 2, 3, 4, 5],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(1.5),
              ),
              child: Scaffold(
                body: ClassesCurrentSetupView(
                  setup: setup,
                  routineBlocks: const [],
                  selectedDay: 1,
                  onDayChanged: (_) {},
                  onBack: () {},
                  onChangeSetup: () {},
                  onRemoveSetup: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('Change setup'), findsOneWidget);
    });
  });

  group('Base Timeline Family: Geometry & Vertical Stacking Order', () {
    testWidgets(
      'Photo-backed Classes: Top Header < 140px Hero Photo < Weekday Chips < Timeline Viewport',
      (tester) async {
        final setup = BaseTimelineSetup(
          uid: 'user-photo-geometry',
          updatedAt: DateTime.now(),
          classLogicalAssetR2Key: 'test/photo.jpg',
          classBlocks: const [
            TimelineBlockDraft(
              id: 'c1',
              section: 'classes',
              title: 'Linear Algebra',
              startMinute: 540,
              endMinute: 600,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final blocks = <ClassRoutineBlock>[
          ClassRoutineBlock(
            id: 'c1',
            subject: 'Linear Algebra',
            startMinute: 540,
            endMinute: 600,
            repeatDays: [1],
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ClassesCurrentSetupView(
                  setup: setup,
                  routineBlocks: blocks,
                  selectedDay: 1,
                  onDayChanged: (_) {},
                  onBack: () {},
                  onChangeSetup: () {},
                  onRemoveSetup: () {},
                ),
              ),
            ),
          ),
        );

        // 1. Photo preview card exists and has height 140
        final photoFinder = find.byType(BaseTimelinePhotoPreviewCard);
        expect(photoFinder, findsOneWidget);
        final photoCard = tester.widget<BaseTimelinePhotoPreviewCard>(
          photoFinder,
        );
        expect(photoCard.height, 140.0);
        expect(photoCard.isCompactRow, isFalse);

        // 2. Weekday chips exist
        final chipsFinder = find.byType(TimelineDayChips);
        expect(chipsFinder, findsOneWidget);

        // 3. Vertical positions: Header top < Photo top < Chips top
        final headerTop = tester.getTopLeft(find.text('Classes')).dy;
        final photoTop = tester.getTopLeft(photoFinder).dy;
        final chipsTop = tester.getTopLeft(chipsFinder).dy;

        expect(headerTop, lessThan(photoTop));
        expect(photoTop, lessThan(chipsTop));
      },
    );

    testWidgets(
      'Manual Classes (no photo): Top Header < Weekday Chips < Timeline Viewport (no 140px photo card)',
      (tester) async {
        final setup = BaseTimelineSetup(
          uid: 'user-manual-geometry',
          updatedAt: DateTime.now(),
          classBlocks: const [
            TimelineBlockDraft(
              id: 'c1',
              section: 'classes',
              title: 'Discrete Math',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final blocks = <ClassRoutineBlock>[
          ClassRoutineBlock(
            id: 'c1',
            subject: 'Discrete Math',
            startMinute: 600,
            endMinute: 660,
            repeatDays: [1],
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ClassesCurrentSetupView(
                  setup: setup,
                  routineBlocks: blocks,
                  selectedDay: 1,
                  onDayChanged: (_) {},
                  onBack: () {},
                  onChangeSetup: () {},
                  onRemoveSetup: () {},
                ),
              ),
            ),
          ),
        );

        // No photo preview card rendered
        expect(find.byType(BaseTimelinePhotoPreviewCard), findsNothing);

        // Summary reflects manual setup with 'classes'
        expect(find.text('1 weekly classes'), findsOneWidget);

        // Chips render directly below header
        final chipsFinder = find.byType(TimelineDayChips);
        expect(chipsFinder, findsOneWidget);
        final headerTop = tester.getTopLeft(find.text('Classes')).dy;
        final chipsTop = tester.getTopLeft(chipsFinder).dy;
        expect(headerTop, lessThan(chipsTop));
      },
    );
  });

  group('Base Timeline Family: Card Iconography & Accessibility Semantics', () {
    testWidgets(
      'Medium class card renders leading Icons.school_rounded container',
      (tester) async {
        // 60 minutes -> 80px height -> isMedium
        final block = ClassRoutineBlock(
          id: 'cls_med',
          subject: 'Computer Networks',
          courseCode: 'CS302',
          section: 'Section B',
          startMinute: 600,
          endMinute: 660, // 60 min
          repeatDays: [1],
        );

        final entry = TimelineEntry(
          id: 'cls_med',
          sourceId: 'cls_med',
          startMinute: 600,
          endMinute: 660,
          repeatDays: const [1],
          title: 'Computer Networks',
          category: TimelineCategory.classes,
        );

        final positioned = PositionedTimelineEntry(
          entry: entry,
          top: 0,
          height: 80,
          left: 0,
          width: 300,
          column: 0,
          columnCount: 1,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ClassTimelineCard(
                positioned: positioned,
                block: block,
                isEditable: false,
                accent: OptivusColors.blueAccent,
              ),
            ),
          ),
        );

        // Verify Icons.school_rounded is present in medium card
        expect(find.byIcon(Icons.school_rounded), findsOneWidget);
        expect(find.text('Computer Networks'), findsOneWidget);
        expect(find.text('Section B'), findsOneWidget);
      },
    );

    testWidgets(
      'BaseTimelinePhotoPreviewCard wraps preview and fallback in Semantics',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          ProviderScope(
            child: const MaterialApp(
              home: Scaffold(
                body: BaseTimelinePhotoPreviewCard(
                  r2Key: 'test/key.jpg',
                  title: 'Timetable Photo',
                  height: 140,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Semantics finder for unavailable preview fallback
        final semanticsFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Timetable Photo. Preview unavailable.',
        );
        expect(semanticsFinder, findsOneWidget);

        handle.dispose();
      },
    );
  });

  group('Base Timeline Family: Source Selection & Review Truthfulness', () {
    testWidgets(
      'ClassesSourceSelectionView presents overflow menu and bottom button for Remove setup',
      (tester) async {
        final setup = BaseTimelineSetup(
          uid: 'user-source-test',
          updatedAt: DateTime.now(),
          classBlocks: const [
            TimelineBlockDraft(
              id: 'c1',
              section: 'classes',
              title: 'Physics',
              startMinute: 540,
              endMinute: 600,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        bool removeInvoked = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ClassesSourceSelectionView(
                setup: setup,
                onCancel: () {},
                onPickPhoto: (_) {},
                onManualSetup: () {},
                onEditCurrent: () {},
                onRemoveSetup: () => removeInvoked = true,
              ),
            ),
          ),
        );

        // 1. Top-right overflow menu
        final moreFinder = find.byIcon(Icons.more_vert_rounded);
        expect(moreFinder, findsOneWidget);
        await tester.tap(moreFinder);
        await tester.pumpAndSettle();

        expect(find.text('Remove setup'), findsOneWidget);
        await tester.tap(find.text('Remove setup'));
        await tester.pumpAndSettle();
        expect(removeInvoked, isTrue);

        // 2. Bottom subtle button also exists
        expect(find.text('Remove Classes setup'), findsOneWidget);
      },
    );

    testWidgets(
      'ClassesReviewView renders Change photo without hidden Scan Again hack',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ClassesReviewView(
                  workingBlocks: const [],
                  workingAssetId: null,
                  workingR2Key: null,
                  workingLocalPreviewPath: null,
                  selectedDay: 1,
                  onDayChanged: (_) {},
                  droppedCount: 0,
                  droppedExamples: const [],
                  errorMessage: null,
                  onClearError: () {},
                  isSaving: false,
                  onCancel: () {},
                  onScanAgain: () {},
                  onAddClass: () {},
                  onEditBlock: (_) {},
                  onSave: () {},
                ),
              ),
            ),
          ),
        );

        // Verify truthful label 'Change photo'
        expect(find.text('Change photo'), findsOneWidget);
        // Verify hidden compatibility hack is completely gone
        expect(find.text('Scan Again'), findsNothing);
      },
    );
  });
}
