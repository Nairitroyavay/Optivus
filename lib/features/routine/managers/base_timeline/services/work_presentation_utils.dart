import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/models/onboarding_draft.dart';

/// Centralized presentation and formatting utilities for Base Timeline Work / Business.
class WorkPresentationUtils {
  const WorkPresentationUtils._();

  static bool isBusinessProfile(String? lifeRole) =>
      lifeRole?.trim().toLowerCase() == LifeRoleDraft.businessKey;

  static bool isWorkProfile(String? lifeRole) {
    final role = lifeRole?.trim().toLowerCase();
    return role == LifeRoleDraft.workingKey ||
        role == LifeRoleDraft.studentWorkingKey;
  }

  static String? defaultContextForProfile(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) return 'business';
    if (isWorkProfile(lifeRole)) return 'job';
    return null;
  }

  static String? defaultModeForProfile(String? workingExtra) {
    return switch (workingExtra?.trim().toLowerCase()) {
      'remote' => 'remote',
      'hybrid' => 'hybrid',
      _ => null,
    };
  }

  static String? defaultBlockKindForProfile(String? workingExtra) {
    return switch (workingExtra?.trim().toLowerCase()) {
      'shift' => 'shift',
      'full_time' || 'part_time' => 'work_hours',
      _ => null,
    };
  }

  // ---------------------------------------------------------------------------
  // 1. Enum formatting (Context, Mode, Kind)
  // ---------------------------------------------------------------------------

  /// Formats raw [context] (e.g. 'job', 'business', 'startup', 'freelance', 'other')
  /// into human-readable text.
  static String formatContext(String? context) {
    if (context == null || context.trim().isEmpty) return '';
    final normalized = context.trim().toLowerCase().replaceAll('-', '_');
    switch (normalized) {
      case 'job':
        return 'Job';
      case 'business':
        return 'Business';
      case 'startup':
        return 'Startup';
      case 'freelance':
        return 'Freelance';
      case 'other':
        return 'Other';
      default:
        return _humanizeSnakeCase(normalized);
    }
  }

  /// Formats raw [mode] (e.g. 'in_person', 'remote', 'hybrid', 'field', 'mixed')
  /// into human-readable text.
  static String formatMode(String? mode) {
    if (mode == null || mode.trim().isEmpty) return '';
    final normalized = mode.trim().toLowerCase().replaceAll('-', '_');
    switch (normalized) {
      case 'in_person':
        return 'In-person';
      case 'remote':
        return 'Remote';
      case 'hybrid':
        return 'Hybrid';
      case 'field':
        return 'Field';
      case 'mixed':
        return 'Mixed';
      default:
        return _humanizeSnakeCase(normalized);
    }
  }

  /// Formats raw [kind] (e.g. 'work_hours', 'deep_work', 'shift', 'meeting', etc.)
  /// into human-readable text.
  static String formatBlockKind(String? kind) {
    if (kind == null || kind.trim().isEmpty) return '';
    final normalized = kind.trim().toLowerCase().replaceAll('-', '_');
    switch (normalized) {
      case 'work_hours':
        return 'Work Hours';
      case 'deep_work':
        return 'Deep Work';
      case 'shift':
        return 'Shift';
      case 'meeting':
        return 'Meeting';
      case 'client_call':
        return 'Client Call';
      case 'project_work':
        return 'Project Work';
      case 'team_sync':
        return 'Team Sync';
      case 'training':
        return 'Training';
      case 'commute':
        return 'Commute';
      case 'break':
        return 'Break';
      case 'business_hours':
        return 'Business Hours';
      case 'admin':
        return 'Admin';
      case 'other':
        return 'Other';
      default:
        return _humanizeSnakeCase(normalized);
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Editor & Detail Sheet dynamic labels
  // ---------------------------------------------------------------------------

  /// Field label for professional / business role in the editor.
  static String roleEditorLabel(String? contextType) {
    final normalized = contextType?.trim().toLowerCase();
    switch (normalized) {
      case 'job':
        return 'ROLE / POSITION';
      case 'business':
      case 'startup':
      case 'freelance':
        return 'YOUR ROLE';
      default:
        return 'ROLE';
    }
  }

  /// Hint text for the role field in the editor.
  static String roleEditorHint(String? contextType) {
    final normalized = contextType?.trim().toLowerCase();
    switch (normalized) {
      case 'job':
        return 'e.g. Software Engineer, Operations Lead, Designer';
      case 'business':
        return 'e.g. Founder, Owner, Director, Operator';
      case 'startup':
        return 'e.g. Founder, Co-founder, Product Lead';
      case 'freelance':
        return 'e.g. Developer, Designer, Consultant';
      default:
        return 'e.g. Software Engineer, Owner, Consultant';
    }
  }

  /// Label for role in read-only sheets (e.g. WorkDetailSheet).
  static String roleDetailLabel(String? contextType) {
    return 'Role';
  }

  /// Field label for company / business / client in the editor.
  static String organizationEditorLabel(String? contextType) {
    final normalized = contextType?.trim().toLowerCase();
    switch (normalized) {
      case 'job':
        return 'COMPANY / ORGANIZATION';
      case 'business':
        return 'BUSINESS NAME';
      case 'startup':
        return 'STARTUP / ORGANIZATION';
      case 'freelance':
        return 'CLIENT / ORGANIZATION';
      default:
        return 'ORGANIZATION';
    }
  }

  /// Hint text for company / business / client in the editor.
  static String organizationEditorHint(String? contextType) {
    final normalized = contextType?.trim().toLowerCase();
    switch (normalized) {
      case 'job':
        return 'e.g. Acme Corp, Optivus, Studio X';
      case 'business':
        return 'e.g. Roy Enterprises, Main Store';
      case 'startup':
        return 'e.g. Nova Labs, Stealth Co.';
      case 'freelance':
        return 'e.g. Studio X, Client ABC';
      default:
        return 'e.g. Organization, Workplace';
    }
  }

  /// Label for organization in read-only sheets.
  static String organizationDetailLabel(String? contextType) {
    final normalized = contextType?.trim().toLowerCase();
    switch (normalized) {
      case 'job':
        return 'Company';
      case 'business':
        return 'Business Name';
      case 'startup':
        return 'Startup';
      case 'freelance':
        return 'Client / Organization';
      default:
        return 'Organization';
    }
  }

  /// Field label for department / team / project in the editor.
  static String departmentEditorLabel(String? contextType) {
    final normalized = contextType?.trim().toLowerCase();
    switch (normalized) {
      case 'job':
        return 'DEPARTMENT / TEAM (OPTIONAL)';
      case 'business':
        return 'BUSINESS AREA / PROJECT (OPTIONAL)';
      case 'startup':
        return 'TEAM / PROJECT (OPTIONAL)';
      case 'freelance':
        return 'PROJECT (OPTIONAL)';
      default:
        return 'TEAM / PROJECT (OPTIONAL)';
    }
  }

  /// Hint text for department / team / project in the editor.
  static String departmentEditorHint(String? contextType) {
    final normalized = contextType?.trim().toLowerCase();
    switch (normalized) {
      case 'job':
        return 'e.g. Engineering, Mobile Team';
      case 'business':
        return 'e.g. Operations, Inventory, Q3 Launch';
      case 'startup':
        return 'e.g. Product, Mobile Team, AI Infrastructure';
      case 'freelance':
        return 'e.g. Commerce App, Rebrand, Web Portal';
      default:
        return 'e.g. Engineering, Client Consulting, Q3 Launch';
    }
  }

  /// Label for department / project in read-only sheets.
  static String departmentDetailLabel(String? contextType) {
    final normalized = contextType?.trim().toLowerCase();
    switch (normalized) {
      case 'job':
        return 'Department / Team';
      case 'business':
        return 'Business Area / Project';
      case 'startup':
        return 'Team / Project';
      case 'freelance':
        return 'Project';
      default:
        return 'Team / Project';
    }
  }

  /// Role-aware editor sheet title based on context priority:
  /// 1. Explicit block.workContextType
  /// 2. Profile category from isBusinessProfile / isWorkProfile
  /// 3. Neutral fallback.
  static String editorTitle({
    required bool isNew,
    String? contextType,
    String? lifeRole,
  }) {
    if (contextType != null && contextType.trim().isNotEmpty) {
      final ctx = contextType.trim().toLowerCase();
      switch (ctx) {
        case 'business':
          return isNew ? 'Add Business Block' : 'Edit Business Block';
        case 'startup':
          return isNew ? 'Add Startup Block' : 'Edit Startup Block';
        case 'freelance':
          return isNew ? 'Add Freelance Block' : 'Edit Freelance Block';
        case 'job':
          return isNew ? 'Add Work Block' : 'Edit Work Block';
        case 'other':
          if (isBusinessProfile(lifeRole)) {
            return isNew ? 'Add Business Block' : 'Edit Business Block';
          }
          if (isWorkProfile(lifeRole)) {
            return isNew ? 'Add Work Block' : 'Edit Work Block';
          }
          return isNew
              ? 'Add Work / Business Block'
              : 'Edit Work / Business Block';
      }
    }

    if (isBusinessProfile(lifeRole)) {
      return isNew ? 'Add Business Block' : 'Edit Business Block';
    }
    if (isWorkProfile(lifeRole)) {
      return isNew ? 'Add Work Block' : 'Edit Work Block';
    }
    return isNew ? 'Add Work / Business Block' : 'Edit Work / Business Block';
  }

  // ---------------------------------------------------------------------------
  // 3. Review & Current Setup view role-aware copy
  // ---------------------------------------------------------------------------

  /// Header title for the Review view.
  static String reviewTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Review Business Schedule';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Review Work Schedule';
    }
    return 'Review Work / Business';
  }

  /// Button label for adding a block in Review view.
  static String addBlockButtonLabel(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Add Business Block';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Add Work Block';
    }
    return 'Add Work / Business Block';
  }

  /// Bottom CTA label in Review view.
  static String useScheduleCtaLabel(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Use this business schedule';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Use this work schedule';
    }
    return 'Use this schedule';
  }

  /// Empty state title in Review view.
  static String noBlocksScheduledTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'No business blocks scheduled';
    }
    if (isWorkProfile(lifeRole)) {
      return 'No work blocks scheduled';
    }
    return 'No Work / Business blocks scheduled';
  }

  /// Empty day message on the timeline.
  static String emptyDayMessage(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'No business scheduled on this day.';
    }
    if (isWorkProfile(lifeRole)) {
      return 'No work scheduled on this day.';
    }
    return 'No scheduled Work / Business blocks on this day.';
  }

  /// Header title for Current Setup view.
  static String currentSetupHeaderTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Business Hours';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Work Schedule';
    }
    return 'Work / Business';
  }

  /// Remove setup action label.
  static String removeSetupLabel(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Remove Business Setup';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Remove Work Setup';
    }
    return 'Remove Work / Business Setup';
  }

  /// Confirmation dialog title when removing the entire setup.
  static String removeSetupConfirmTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Remove Business Setup?';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Remove Work Setup?';
    }
    return 'Remove Setup?';
  }

  /// Dialog content when confirming removal of the entire setup.
  static String removeSetupConfirmContent(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'This will remove all business blocks from your Base Timeline. This action cannot be undone.';
    }
    return 'This will remove all work and business blocks from your Base Timeline. This action cannot be undone.';
  }

  /// Label for removing a single block in editor.
  static String removeBlockLabel(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Remove business block';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Remove work block';
    }
    return 'Remove block';
  }

  /// Confirmation dialog title when deleting a block.
  static String removeBlockConfirmTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Remove this business block?';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Remove this work block?';
    }
    return 'Remove this block?';
  }

  /// Title for the photo card preview.
  static String photoCardTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Business Schedule Photo';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Work Schedule Photo';
    }
    return 'Schedule Photo';
  }

  /// Title for Source Selection view.
  static String sourceSelectionTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Update Business Hours';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Update Work Schedule';
    }
    return 'Update Work / Business';
  }

  /// Subtitle for Source Selection view.
  static String sourceSelectionSubtitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Your current business hours stay active until you save new ones.';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Your current setup stays active until you save a new one.';
    }
    return 'Your current setup stays active until you save a new one.';
  }

  /// Subtitle for manual setup action card in Source Selection view.
  static String sourceManualSubtitle({
    bool? isBusiness,
    String? lifeRole,
    String? businessMode,
  }) {
    final business = isBusiness ?? isBusinessProfile(lifeRole);
    if (business) {
      switch (businessMode?.trim().toLowerCase()) {
        case 'fixed_business':
          return 'Add your regular business hours and recurring operations.';
        case 'flexible_business':
          return 'Add the business blocks you want anchored to specific times.';
        case 'mixed_business':
          return 'Add your fixed business hours and scheduled client or operating blocks.';
        default:
          return 'Add your business and client blocks day by day';
      }
    }
    if (isWorkProfile(lifeRole)) {
      return 'Add your work blocks day by day';
    }
    return 'Add your schedule blocks day by day';
  }

  /// Title for manual action card in Source Selection view when unconfigured.
  static String sourceManualTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Set up business hours manually';
    }
    return 'Set up manually';
  }

  /// Subtitle for camera card in Source Selection view.
  static String sourceCameraSubtitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Capture store hours, operational plan, or screen';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Capture a printed shift roster, rota, or screen';
    }
    return 'Capture a printed schedule, contract, or screen';
  }

  /// Title for edit current setup card in Source Selection view.
  static String sourceEditCurrentTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Edit current business hours';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Edit current work schedule';
    }
    return 'Edit current schedule';
  }

  /// Subtitle for edit current setup card in Source Selection view.
  static String sourceEditCurrentSubtitle({
    required bool hasSourcePhoto,
    String? lifeRole,
  }) {
    if (hasSourcePhoto) {
      return 'Keep schedule photo and adjust blocks';
    }
    if (isBusinessProfile(lifeRole)) {
      return 'Keep your current business blocks and adjust them manually';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Keep your current blocks and adjust them manually';
    }
    return 'Keep your current blocks and adjust them manually';
  }

  /// Empty review view prompt.
  static String emptyReviewPrompt(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Tap "Add Business Block" or scan another photo to get started.';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Tap "Add Work Block" or scan another photo to get started.';
    }
    return 'Tap "Add Work / Business Block" or scan another photo to get started.';
  }

  /// Scheduled block count headline in Review view.
  static String scheduledCount(int count, [String? lifeRole]) {
    return '$count ${count == 1 ? 'block' : 'blocks'} scheduled';
  }

  /// Weekly block count subtitle for photo previews.
  static String weeklyBlockCount(int count, String? lifeRole) {
    final noun = isBusinessProfile(lifeRole)
        ? (count == 1 ? 'business block' : 'business blocks')
        : isWorkProfile(lifeRole)
        ? (count == 1 ? 'work block' : 'work blocks')
        : (count == 1 ? 'block' : 'blocks');
    return '$count weekly $noun';
  }

  /// Modal sheet title for scanning a schedule photo again.
  static String scanSheetTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) return 'Scan Business Schedule Photo';
    if (isWorkProfile(lifeRole)) return 'Scan Work Schedule Photo';
    return 'Scan Schedule Photo';
  }

  /// Uploading progress title.
  static String uploadingTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) return 'Updating business hours';
    if (isWorkProfile(lifeRole)) return 'Updating work schedule';
    return 'Updating schedule';
  }

  /// AI extraction stage header title.
  static String extractionTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) return 'Reading business schedule';
    if (isWorkProfile(lifeRole)) return 'Reading work schedule';
    return 'Reading schedule';
  }

  /// AI thinking initial greeting message.
  static String extractionInitialMessage(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) return 'Reading your business schedule';
    if (isWorkProfile(lifeRole)) return 'Reading your work schedule';
    return 'Reading your schedule';
  }

  /// AI thinking progress sequence messages.
  static List<String> extractionProgressMessages(String? lifeRole) {
    final first = isBusinessProfile(lifeRole)
        ? 'Finding business and client blocks'
        : isWorkProfile(lifeRole)
        ? 'Finding work blocks'
        : 'Finding schedule blocks';
    final last = isBusinessProfile(lifeRole)
        ? 'Building your business schedule'
        : isWorkProfile(lifeRole)
        ? 'Building your new work schedule'
        : 'Building your new schedule';
    return [
      first,
      'Reading locations and roles',
      'Matching weekdays',
      'Checking exact hours',
      last,
    ];
  }

  /// Primary button label for Current Setup view.
  static String currentSetupPrimaryButtonLabel({
    required bool isConfigured,
    String? lifeRole,
  }) {
    if (isConfigured) return 'Change setup';
    if (isBusinessProfile(lifeRole)) return 'Set up Business';
    if (isWorkProfile(lifeRole)) return 'Set up Work';
    return 'Set up Work / Business';
  }

  /// Empty state title in Current Setup view.
  static String currentSetupEmptyTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'No business hours yet';
    }
    if (isWorkProfile(lifeRole)) {
      return 'No work schedule yet';
    }
    return 'No Work / Business schedule yet';
  }

  /// Empty state subtitle in Current Setup view.
  static String currentSetupEmptySubtitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Add business hours, client syncs, or scan an operational schedule to keep your routine aligned.';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Add shifts, work hours, or scan a schedule photo to keep your routine aligned.';
    }
    return 'Add work or business hours, shifts, or scan a schedule photo to keep your routine aligned.';
  }

  /// Dialog content text when discarding unsaved edits.
  static String discardDialogContent(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return "Your current business setup won't be affected.";
    }
    if (isWorkProfile(lifeRole)) {
      return "Your current work setup won't be affected.";
    }
    return "Your current setup won't be affected.";
  }

  /// SnackBar message when setup is successfully removed.
  static String removeSuccessMessage({
    required bool refreshPending,
    String? lifeRole,
  }) {
    if (isBusinessProfile(lifeRole)) {
      return refreshPending
          ? 'Business setup removed. Routine update is pending.'
          : 'Business setup removed.';
    }
    if (isWorkProfile(lifeRole)) {
      return refreshPending
          ? 'Work setup removed. Routine update is pending.'
          : 'Work setup removed.';
    }
    return refreshPending
        ? 'Setup removed. Routine update is pending.'
        : 'Setup removed.';
  }

  /// SnackBar message when removing setup fails.
  static String removeFailureMessage(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Failed to remove business setup. Please try again.';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Failed to remove work setup. Please try again.';
    }
    return 'Failed to remove setup. Please try again.';
  }

  /// Loading message in skeleton view.
  static String loadingScheduleMessage(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) return 'Loading business hours...';
    if (isWorkProfile(lifeRole)) return 'Loading work schedule...';
    return 'Loading schedule...';
  }

  /// Title when initial setup loading fails.
  static String failedToLoadTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) return 'Failed to load business schedule';
    if (isWorkProfile(lifeRole)) return 'Failed to load work schedule';
    return 'Failed to load schedule';
  }

  /// Title when canonical setup is temporarily unavailable.
  static String temporarilyUnavailableTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Business schedule temporarily unavailable';
    }
    if (isWorkProfile(lifeRole)) {
      return 'Work schedule temporarily unavailable';
    }
    return 'Schedule temporarily unavailable';
  }

  /// Error view title based on errorKind and role context.
  static String errorTitle({
    required String? errorKindString,
    String? lifeRole,
  }) {
    switch (errorKindString) {
      case 'upload':
        return 'Photo Upload Issue';
      case 'extraction':
        return 'Schedule Analysis Issue';
      case 'concurrency':
        return 'Schedule Conflict';
      case 'save':
        if (isBusinessProfile(lifeRole)) {
          return 'Failed to Save Business Schedule';
        }
        if (isWorkProfile(lifeRole)) {
          return 'Failed to Save Work Schedule';
        }
        return 'Failed to Save Schedule';
      case 'remove':
        if (isBusinessProfile(lifeRole)) {
          return 'Failed to Remove Business Setup';
        }
        if (isWorkProfile(lifeRole)) {
          return 'Failed to Remove Work Setup';
        }
        return 'Failed to Remove Setup';
      case 'load':
      default:
        if (isBusinessProfile(lifeRole)) {
          return 'Business Schedule Processing Issue';
        }
        if (isWorkProfile(lifeRole)) {
          return 'Work Schedule Processing Issue';
        }
        return 'Schedule Processing Issue';
    }
  }

  /// Success message on the save success screen.
  static String saveSuccessTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) return 'Business schedule saved!';
    if (isWorkProfile(lifeRole)) return 'Work schedule saved!';
    return 'Schedule saved!';
  }

  /// Grammatically correct, role-aware summary string for Current Setup header.
  static String setupSummary({
    required BaseTimelineSectionSnapshot snapshot,
    required List<TimelineBlockDraft> blocks,
    String? lifeRole,
  }) {
    final count = blocks.length;
    if (!snapshot.isConfigured && blocks.isEmpty) {
      return 'Not set up';
    }

    final String blockNoun;
    if (isBusinessProfile(lifeRole)) {
      blockNoun = count == 1 ? 'business block' : 'business blocks';
    } else if (isWorkProfile(lifeRole)) {
      blockNoun = count == 1 ? 'work block' : 'work blocks';
    } else {
      blockNoun = count == 1 ? 'block' : 'blocks';
    }

    if (snapshot.origin == BaseSetupOrigin.photo) {
      return 'Schedule photo · $count $blockNoun';
    }

    return '$count weekly $blockNoun';
  }

  /// Optional secondary summary line when metadata across blocks is consistent.
  /// E.g. 'Software Engineer · Optivus · Hybrid'
  static String? secondarySetupSummary(List<TimelineBlockDraft> blocks) {
    if (blocks.isEmpty) return null;

    final roles = blocks
        .map((b) => b.workRole?.trim())
        .where((r) => r != null && r.isNotEmpty)
        .toSet();
    final orgs = blocks
        .map((b) => b.workOrganization?.trim())
        .where((o) => o != null && o.isNotEmpty)
        .toSet();
    final modes = blocks
        .map((b) => b.workMode?.trim())
        .where((m) => m != null && m.isNotEmpty)
        .toSet();

    final parts = <String>[];
    if (roles.length == 1) parts.add(roles.first!);
    if (orgs.length == 1) parts.add(orgs.first!);
    if (modes.length == 1) parts.add(formatMode(modes.first!));

    if (parts.length >= 2) {
      return parts.join(' · ');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 4. Intelligent de-duplication helpers
  // ---------------------------------------------------------------------------

  /// Checks if [role] provides distinct information from [title].
  static bool shouldShowRole({required String? title, required String? role}) {
    if (role == null || role.trim().isEmpty) return false;
    final cleanRole = role.trim().toLowerCase();
    final cleanTitle = title?.trim().toLowerCase() ?? '';
    return cleanRole != cleanTitle;
  }

  /// Checks if [kind] provides distinct information from [title].
  static bool shouldShowKind({required String? title, required String? kind}) {
    if (kind == null || kind.trim().isEmpty) return false;
    final formattedKind = formatBlockKind(kind).toLowerCase();
    final cleanTitle = title?.trim().toLowerCase() ?? '';
    return formattedKind != cleanTitle;
  }

  /// Checks if [context] provides distinct information from [title].
  static bool shouldShowContext({
    required String? title,
    required String? context,
  }) {
    if (context == null || context.trim().isEmpty) return false;
    final formatted = formatContext(context).toLowerCase();
    final cleanTitle = title?.trim().toLowerCase() ?? '';
    return formatted != cleanTitle;
  }

  /// Combines role and organization into a single subtitle line (e.g. 'Software Engineer · Optivus'),
  /// intelligent about title deduplication and empty values.
  static String formatRoleOrgLine({
    String? role,
    String? org,
    required String title,
  }) {
    final showRole = shouldShowRole(title: title, role: role);
    final cleanRole = role?.trim() ?? '';
    final cleanOrg = org?.trim() ?? '';

    if (showRole && cleanOrg.isNotEmpty) {
      return '$cleanRole · $cleanOrg';
    }
    if (showRole) {
      return cleanRole;
    }
    return cleanOrg;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static String _humanizeSnakeCase(String text) {
    return text
        .split(RegExp(r'[_\s]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}
