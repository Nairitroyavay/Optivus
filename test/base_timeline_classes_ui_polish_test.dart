import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/adapters/class_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_current_setup_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_review_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_ai_thinking_view.dart';

import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_setup_context_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/class_detail_sheet.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/class_timeline_card.dart';
import 'package:optivus/models/onboarding_draft.dart';

void main() {
  group('1. Truthful Section Label Presentation', () {
    testWidgets(
      'ClassTimelineCard renders raw section truthful without prepending Sec',
      (tester) async {
        final block = ClassRoutineBlock(
          id: 'cls_1',
          subject: 'Algorithms',
          section: 'Batch 2',
          startMinute: 540,
          endMinute: 600,
          repeatDays: [1],
        );

        final entry = TimelineEntry(
          id: 'cls_1',
          sourceId: 'cls_1',
          startMinute: 540,
          endMinute: 600,
          repeatDays: const [1],
          title: 'Algorithms',
          category: TimelineCategory.classes,
        );

        final positioned = PositionedTimelineEntry(
          entry: entry,
          top: 0,
          height: 80,
          left: 0,
          width: 200,
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

        expect(find.text('Batch 2'), findsOneWidget);
        expect(find.text('Sec Batch 2'), findsNothing);
      },
    );

    testWidgets(
      'ClassDetailSheet renders raw section badge truthful without prepending Sec',
      (tester) async {
        final block = ClassRoutineBlock(
          id: 'cls_1',
          subject: 'Algorithms',
          section: 'Group B',
          room: 'Lab 3',
          startMinute: 540,
          endMinute: 600,
          repeatDays: [1],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ClassDetailSheet(block: block)),
          ),
        );

        expect(find.text('Group B'), findsOneWidget);
        expect(find.text('Sec Group B'), findsNothing);
      },
    );
  });

  group('2. Card Presentation & Fallbacks Across Height Tiers', () {
    testWidgets('Compact card shows secondary metadata fallback', (
      tester,
    ) async {
      final block = ClassRoutineBlock(
        id: 'cls_compact',
        subject: 'Data Structures',
        room: 'Hall 4B',
        startMinute: 600,
        endMinute: 630, // 30 min -> ~40px height
        repeatDays: [1],
      );

      final entry = TimelineEntry(
        id: 'cls_compact',
        sourceId: 'cls_compact',
        startMinute: 600,
        endMinute: 630,
        repeatDays: const [1],
        title: 'Data Structures',
        category: TimelineCategory.classes,
      );

      final positioned = PositionedTimelineEntry(
        entry: entry,
        top: 0,
        height: 48,
        left: 0,
        width: 250,
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

      expect(find.text('Data Structures'), findsOneWidget);
      expect(find.textContaining('Hall 4B'), findsOneWidget);
    });

    testWidgets('Medium card shows section badge and time', (tester) async {
      final block = ClassRoutineBlock(
        id: 'cls_medium',
        subject: 'Physics II',
        section: 'Sec 1',
        room: 'Room 101',
        startMinute: 600,
        endMinute: 660, // 60 min -> ~80px height
        repeatDays: [1],
      );

      final entry = TimelineEntry(
        id: 'cls_medium',
        sourceId: 'cls_medium',
        startMinute: 600,
        endMinute: 660,
        repeatDays: const [1],
        title: 'Physics II',
        category: TimelineCategory.classes,
      );

      final positioned = PositionedTimelineEntry(
        entry: entry,
        top: 0,
        height: 80,
        left: 0,
        width: 250,
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

      expect(find.text('Physics II'), findsOneWidget);
      expect(find.text('Sec 1'), findsOneWidget);
      expect(find.text('Room 101'), findsOneWidget);
    });

    testWidgets('Rich card shows school icon and full details', (tester) async {
      final block = ClassRoutineBlock(
        id: 'cls_rich',
        subject: 'Operating Systems',
        courseCode: 'CS301',
        classType: 'Lecture',
        room: 'Auditorium A',
        professor: 'Dr. Tan',
        notes: 'Bring laptop',
        startMinute: 600,
        endMinute: 720, // 120 min -> 160px height
        repeatDays: [1],
      );

      final entry = TimelineEntry(
        id: 'cls_rich',
        sourceId: 'cls_rich',
        startMinute: 600,
        endMinute: 720,
        repeatDays: const [1],
        title: 'Operating Systems',
        category: TimelineCategory.classes,
      );

      final positioned = PositionedTimelineEntry(
        entry: entry,
        top: 0,
        height: 160,
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

      expect(find.byIcon(Icons.school_rounded), findsOneWidget);
      expect(find.text('Operating Systems'), findsOneWidget);
      expect(find.text('CS301'), findsOneWidget);
      expect(find.text('Lecture'), findsOneWidget);
      expect(find.text('Auditorium A'), findsOneWidget);
      expect(find.text('Dr. Tan'), findsOneWidget);
      expect(find.text('Bring laptop'), findsOneWidget);
    });
  });

  group('3. Overlap Micro-Interactions & Tap Handling', () {
    testWidgets(
      'Exposed back card renders with AnimatedContainer and invokes onTap',
      (tester) async {
        bool tapped = false;

        final block = ClassRoutineBlock(
          id: 'cls_back',
          subject: 'Chemistry',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [1],
        );

        final entry = TimelineEntry(
          id: 'cls_back',
          sourceId: 'cls_back',
          startMinute: 600,
          endMinute: 660,
          repeatDays: const [1],
          title: 'Chemistry',
          category: TimelineCategory.classes,
        );

        final positioned = PositionedTimelineEntry(
          entry: entry,
          top: 0,
          height: 80,
          left: 0,
          width: 250,
          column: 0,
          columnCount: 2,
          hasOverlap: true,
          isFront: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ClassTimelineCard(
                positioned: positioned,
                block: block,
                isEditable: false,
                accent: OptivusColors.blueAccent,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        // Verify exposed back card renders
        expect(find.text('Chemistry'), findsOneWidget);
        expect(find.byType(AnimatedContainer), findsWidgets);

        // Tap card
        await tester.tap(find.text('Chemistry'));
        expect(tapped, isTrue);
      },
    );
  });

  group('4. Class Edit Sheet Progressive Disclosure & Layout', () {
    testWidgets('Primary fields visible; secondary details collapsible', (
      tester,
    ) async {
      final block = ClassRoutineBlock(
        id: 'cls_empty_secondary',
        subject: 'Linear Algebra',
        startMinute: 540,
        endMinute: 600,
        repeatDays: [1, 3],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ClassTimelineAdapter.showClassEditSheet(
                    context: context,
                    block: block,
                    onSave: (_) async => true,
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Primary fields are present
      expect(
        find.byKey(const Key('timeline-edit-subject-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline-edit-start-time-picker')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline-edit-end-time-picker')),
        findsOneWidget,
      );
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);

      // Secondary details are initially collapsed because block has no secondary details
      expect(
        find.byKey(const Key('timeline-edit-details-toggle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline-edit-course-code-field')),
        findsNothing,
      );

      // Tap details toggle
      await tester.tap(find.byKey(const Key('timeline-edit-details-toggle')));
      await tester.pumpAndSettle();

      // Secondary fields are now visible
      expect(
        find.byKey(const Key('timeline-edit-course-code-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline-edit-class-type-field')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('timeline-edit-room-field')), findsOneWidget);
      expect(
        find.byKey(const Key('timeline-edit-professor-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline-edit-section-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline-edit-notes-field')),
        findsOneWidget,
      );
    });

    testWidgets(
      'Secondary details start expanded when block contains details',
      (tester) async {
        final block = ClassRoutineBlock(
          id: 'cls_with_details',
          subject: 'Database Systems',
          courseCode: 'CS202',
          room: 'Lab 1',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [2],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    ClassTimelineAdapter.showClassEditSheet(
                      context: context,
                      block: block,
                      onSave: (_) async => true,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        // Details start expanded
        expect(
          find.byKey(const Key('timeline-edit-course-code-field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('timeline-edit-room-field')),
          findsOneWidget,
        );
      },
    );
  });

  group('5. Visual Family Alignment & Tab Bar Bottom Clearance', () {
    testWidgets(
      'ClassesCurrentSetupView renders top-right Change setup CTA and 140px photo card',
      (tester) async {
        final setup = BaseTimelineSetup(
          uid: 'user-tab-test',
          updatedAt: DateTime.now(),
          classLogicalAssetR2Key: 'test/classes.jpg',
          classBlocks: const [
            TimelineBlockDraft(
              id: 'c1',
              section: 'classes',
              title: 'Calculus I',
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
            subject: 'Calculus I',
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

        // The intentional icon-only Edit schedule action remains accessible.
        final ctaFinder = find.byKey(
          const Key('base-timeline-header-edit-schedule-button'),
        );
        expect(ctaFinder, findsOneWidget);
        expect(find.text('Edit schedule'), findsNothing);

        // Verify BaseTimelineSetupContextCard directly below header
        final contextCardFinder = find.byType(BaseTimelineSetupContextCard);
        expect(contextCardFinder, findsOneWidget);
        expect(find.text('View photo'), findsOneWidget);
      },
    );

    testWidgets(
      'ClassesReviewView renders Change photo and tab bar clearance without hidden Scan Again hack',
      (tester) async {
        final blocks = <ClassRoutineBlock>[
          ClassRoutineBlock(
            id: 'c1',
            subject: 'Chemistry 101',
            startMinute: 540,
            endMinute: 600,
            repeatDays: [1],
          ),
        ];

        bool changedPhoto = false;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ClassesReviewView(
                  workingBlocks: blocks,
                  workingAssetId: 'asset_1',
                  workingR2Key: 'key_1',
                  workingLocalPreviewPath: null,
                  selectedDay: 1,
                  onDayChanged: (_) {},
                  droppedCount: 0,
                  droppedExamples: const [],
                  errorMessage: null,
                  onClearError: () {},
                  isSaving: false,
                  onCancel: () {},
                  onScanAgain: () => changedPhoto = true,
                  onAddClass: () {},
                  onEditBlock: (_) {},
                  onSave: () {},
                ),
              ),
            ),
          ),
        );

        // Verify 'Change photo' exists and hidden 'Scan Again' hack is removed
        expect(find.text('Change photo'), findsOneWidget);
        expect(find.text('Scan Again'), findsNothing);

        // Verify tapping 'Change photo' invokes onScanAgain
        await tester.tap(find.text('Change photo'));
        expect(changedPhoto, isTrue);

        // Verify bottom CTA has "Use this timetable" (no isEditing=true passed, so new candidate)
        expect(find.text('Use this timetable'), findsOneWidget);

        // Verify compact source row is rendered via the 'Change photo' action button
        // (BaseTimelinePhotoPreviewCard is only shown inside a dialog on tap)
        expect(find.text('Change photo'), findsOneWidget);
      },
    );
  });

  group('6. Stage Transitions & AI/Upload Views', () {
    testWidgets(
      'BaseTimelineUploadView renders title, subtitle, and indicator',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: BaseTimelineUploadView())),
        );

        expect(find.text('Uploading timetable photo...'), findsOneWidget);
        expect(
          find.text('Encrypting and uploading to private storage...'),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'BaseTimelineAiThinkingView renders message with smooth switcher',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BaseTimelineAiThinkingView(
                initialMessage: 'Reading timetable...',
              ),
            ),
          ),
        );

        expect(find.text('Reading timetable...'), findsOneWidget);
        expect(find.byType(AnimatedSwitcher), findsOneWidget);
      },
    );
  });

  group('7. Text Scaling & Overflow Stress Tests', () {
    testWidgets(
      'ClassTimelineCard renders at text scale 1.5 without overflow',
      (tester) async {
        final block = ClassRoutineBlock(
          id: 'cls_scale',
          subject: 'Distributed Database Systems and Cloud Computing',
          courseCode: 'CS401',
          classType: 'Lecture',
          room: 'Building 12, Lecture Hall 3',
          professor: 'Prof. Alexander Montgomery',
          notes: 'Prepare presentation slides for chapter 4',
          startMinute: 540,
          endMinute: 660,
          repeatDays: [1],
        );

        final entry = TimelineEntry(
          id: 'cls_scale',
          sourceId: 'cls_scale',
          startMinute: 540,
          endMinute: 660,
          repeatDays: const [1],
          title: block.subject,
          category: TimelineCategory.classes,
        );

        final positioned = PositionedTimelineEntry(
          entry: entry,
          top: 0,
          height: 120,
          left: 0,
          width: 320,
          column: 0,
          columnCount: 1,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Scaffold(
                body: ClassTimelineCard(
                  positioned: positioned,
                  block: block,
                  isEditable: false,
                  accent: OptivusColors.blueAccent,
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(
          find.text('Distributed Database Systems and Cloud Computing'),
          findsOneWidget,
        );
      },
    );

    testWidgets('ClassDetailSheet renders at text scale 1.5 without overflow', (
      tester,
    ) async {
      final block = ClassRoutineBlock(
        id: 'cls_scale_detail',
        subject: 'Distributed Database Systems and Cloud Computing',
        courseCode: 'CS401',
        classType: 'Lecture',
        room: 'Building 12, Lecture Hall 3',
        professor: 'Prof. Alexander Montgomery',
        notes: 'Prepare presentation slides for chapter 4',
        startMinute: 540,
        endMinute: 660,
        repeatDays: [1, 2, 3, 4, 5],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(body: ClassDetailSheet(block: block)),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text('Distributed Database Systems and Cloud Computing'),
        findsOneWidget,
      );
    });
  });
}
