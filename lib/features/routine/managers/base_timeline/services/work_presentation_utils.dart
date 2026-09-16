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
  /// block.workContextType -> profile.lifeRole -> neutral fallback.
  static String editorTitle({
    required bool isNew,
    String? contextType,
    String? lifeRole,
  }) {
    final effectiveContext = contextType?.trim().isNotEmpty == true
        ? contextType!.trim().toLowerCase()
        : (lifeRole?.trim().toLowerCase());

    if (isNew) {
      switch (effectiveContext) {
        case 'business':
          return 'Add Business Block';
        case 'freelance':
          return 'Add Freelance Block';
        case 'startup':
          return 'Add Startup Block';
        case 'job':
        case 'working':
        default:
          return 'Add Work Block';
      }
    } else {
      switch (effectiveContext) {
        case 'business':
          return 'Edit Business Block';
        case 'freelance':
          return 'Edit Freelance Block';
        case 'startup':
          return 'Edit Startup Block';
        case 'job':
        case 'working':
        default:
          return 'Edit Work Block';
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Review & Current Setup view role-aware copy
  // ---------------------------------------------------------------------------

  /// Header title for the Review view.
  static String reviewTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Review Business Schedule';
    }
    return 'Review Work Schedule';
  }

  /// Button label for adding a block in Review view.
  static String addBlockButtonLabel(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Add Business Block';
    }
    return 'Add Work Block';
  }

  /// Bottom CTA label in Review view.
  static String useScheduleCtaLabel(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Use this business schedule';
    }
    return 'Use this work schedule';
  }

  /// Empty state title in Review view.
  static String noBlocksScheduledTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'No business blocks scheduled';
    }
    return 'No work blocks scheduled';
  }

  /// Empty day message on the timeline.
  static String emptyDayMessage(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'No business scheduled on this day.';
    }
    return 'No work scheduled on this day.';
  }

  /// Header title for Current Setup view.
  static String currentSetupHeaderTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Business Hours';
    }
    return 'Work Schedule';
  }

  /// Remove setup action label.
  static String removeSetupLabel(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Remove Business Setup';
    }
    return 'Remove Work Setup';
  }

  /// Title for the photo card preview.
  static String photoCardTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Business Schedule Photo';
    }
    return 'Work Schedule Photo';
  }

  /// Title for Source Selection view.
  static String sourceSelectionTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Update Business Hours';
    }
    return 'Update Work Schedule';
  }

  /// Subtitle for Source Selection view.
  static String sourceSelectionSubtitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Your current business hours stay active until you save new ones.';
    }
    return 'Your current setup stays active until you save a new one.';
  }

  /// Subtitle for manual setup action card in Source Selection view.
  static String sourceManualSubtitle({
    required bool isBusiness,
    String? businessMode,
  }) {
    if (!isBusiness) {
      return 'Add your work blocks day by day';
    }
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

  static String emptyReviewPrompt(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) {
      return 'Tap "Add Business Block" or scan another photo to get started.';
    }
    return 'Tap "Add Work Block" or scan another photo to get started.';
  }

  static String scheduledCount(int count, String? lifeRole) {
    final noun = isBusinessProfile(lifeRole)
        ? (count == 1 ? 'business block' : 'business blocks')
        : isWorkProfile(lifeRole)
        ? (count == 1 ? 'work block' : 'work blocks')
        : (count == 1 ? 'block' : 'blocks');
    return '$count $noun scheduled';
  }

  static String weeklyBlockCount(int count, String? lifeRole) {
    final noun = isBusinessProfile(lifeRole)
        ? (count == 1 ? 'business block' : 'business blocks')
        : (count == 1 ? 'work block' : 'work blocks');
    return '$count weekly $noun';
  }

  static String scanSheetTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) return 'Scan Business Schedule Photo';
    return 'Scan Work Schedule Photo';
  }

  static String extractionTitle(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) return 'Reading business schedule';
    return 'Reading work schedule';
  }

  static String extractionInitialMessage(String? lifeRole) {
    if (isBusinessProfile(lifeRole)) return 'Reading your business schedule';
    return 'Reading your work schedule';
  }

  static List<String> extractionProgressMessages(String? lifeRole) {
    final first = isBusinessProfile(lifeRole)
        ? 'Finding business and client blocks'
        : 'Finding work blocks';
    final last = isBusinessProfile(lifeRole)
        ? 'Building your business schedule'
        : 'Building your new work schedule';
    return [
      first,
      'Reading locations and roles',
      'Matching weekdays',
      'Checking exact hours',
      last,
    ];
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

    final isBusiness = lifeRole == LifeRoleDraft.businessKey;
    final isJob = lifeRole == LifeRoleDraft.workingKey;

    final String blockNoun;
    if (isBusiness) {
      blockNoun = count == 1 ? 'business block' : 'business blocks';
    } else if (isJob) {
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
