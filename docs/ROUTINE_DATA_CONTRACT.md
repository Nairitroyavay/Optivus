# Optivus Routine Data Contract

Status date: 2026-09-05

Schema version: 1

Scope: Routine Production Closure preparation after the Auth/Onboarding source freeze

This document is the authoritative persistence contract for Routine. If a
Routine model, repository, screen, onboarding snapshot, or older document
disagrees with this contract, the canonical Firestore codecs and this document
control new durable writes.

Routine is not classified as **Live** yet. The Firebase-capable implementation,
collection-specific rules, Firestore emulator rules tests, and local automated
tests exist, but deployed Firebase verification, physical-device restoration,
another-device acceptance, and full Routine UX acceptance are still required.

## 1. Ownership

`routineNotifierProvider` is the one active in-app owner of Routine templates,
their loaded occurrence records, loading/refresh state, mutations, and retry
state. It loads and writes through `RoutineRepository`,
`RoutineHistoryRepository`, and `RoutineTransactionRepository`.

`mockRoutineProvider` remains only as a fake-development compatibility store.
Firebase mode does not put onboarding or import output into it, and Profile
compatibility reads now use `routineNotifierProvider`. The onboarding
completion bundle is a bootstrap snapshot; it is not a live Routine store.

The authenticated Firebase UID is passed explicitly to repository methods and
retained by `RoutineNotifier.loadForOwner`. Firebase Routine writes never
derive identity from `userProfileProvider`.

`habitSystemsRepositoryProvider` is the owner boundary for Routine Habit
Systems. Firebase mode selects `FirestoreHabitSystemsRepository`, while fake
mode selects `FakeHabitSystemsRepository`. The older
`habitRepositoryProvider` is still an overlapping compatibility/debt surface:
in Firebase mode it returns `UnavailableFirebaseHabitRepository` rather than a
production store. Routine Production Closure must either remove or retire that
legacy abstraction from active paths before Habit Systems can be considered
fully accepted.

Routine still has one known cross-feature ownership debt: some Routine-driven
money/tracker launch or completion paths directly touch `mockTrackerProvider`.
That is not durable Tracker ownership. Routine Production Closure must close or
isolate that boundary before Routine can be accepted as a production feature;
Tracker production persistence itself remains owned by the later Tracker phase.

## 2. Two kinds of Routine data

### 2.1 Routine template

A template is the recurring or one-time schedule definition, such as “Gym
every Monday at 7:00 AM.” It is stored at:

```text
users/{uid}/routineItems/{routineItemId}
```

Templates own schedule content: title, category, block type, time, repeat
policy, optional local date range, tracker-link configuration, notes, and
user-visible steps/details.

A template does **not** own a dated completion, skip, miss, move, active
session, conflict projection, or subtask-completion state. Absence of an
occurrence record means that the template is planned for an eligible date.

### 2.2 Routine occurrence/history record

An occurrence record is the state of one template on one local calendar date,
such as “Gym on 2026-07-23 — completed.” The existing owner-scoped history path
is used:

```text
users/{uid}/routineHistory/{occurrenceId}
```

There is one stable document per owner, template, and scheduled start-date key.
Updates to that dated occurrence replace the same document instead of
appending duplicate events. This makes completion retry-safe while retaining
the current history path.

The durable statuses are:

- `active`
- `inTracker`
- `completed`
- `skipped`
- `missed`
- `moved`

No record is required for `planned`; planned is derived from a matching
template with no occurrence record.

## 3. Schedule semantics

### Repeating days

`repeatDays` uses ISO weekday integers: Monday is `1` and Sunday is `7`.
Values must be unique and between 1 and 7. A recurring template is
materialized only when its repeat policy and repeat days include the selected
local day.

Completing one occurrence changes only its dated occurrence document. It never
sets `completed`, `isCompleted`, or another daily status on the repeating
template, so a later matching weekday remains planned.

### One-time items and date ranges

A one-time item uses:

- `repeatRule: "once"`
- an empty `repeatDays`
- required `dateKey`

`dateKey` and optional `endDateKey` are local date-only strings. An end date
cannot precede its start date. Date-range policy is schedule metadata; it does
not authorize daily status on the template. For a recurring template,
`dateKey` and `endDateKey` are inclusive materialization boundaries; the
repeat rule still decides which days inside the range appear. The current
materializer supports one-time dates and bounded weekly/day rules. Richer
range recurrence editing belongs to the later Routine CRUD step.

### Overnight blocks

An overnight template has `crossesMidnight` or `endsNextDay` set and an end
minute earlier than its start minute. It is one logical template, not two
stored templates. The next-day segment is derived for presentation.

Its occurrence is keyed by the local date on which the block starts. A
next-day continuation therefore reads the previous start date’s occurrence.
A daily overnight schedule can show the previous night’s continuation and the
new night’s start on the same calendar day; those are distinct dated
occurrences even though they reference the same template.

### Moves

A moved occurrence keeps its original `occurrenceDateKey` and stores
`movedToDateKey`, `movedStartMinute`, and `movedEndMinute`. The projector hides
it from the original day and derives it on the target day. Moving one
occurrence does not edit the repeating template.

## 4. Calendar, timestamp, and timezone policy

`dateKey`, `endDateKey`, `occurrenceDateKey`, and `movedToDateKey` use the
stable format:

```text
YYYY-MM-DD
```

These keys represent a wall-calendar date, not a UTC instant. Flutter creates
them from the device-local calendar at the time of the command. Firestore
`createdAt`, `updatedAt`, and projection completion timestamps are audit
instants and are stored as Firestore timestamps.

Firestore repositories use server timestamps for create/update/completion
writes. The standalone codec emits `Timestamp` values so it can be validated
and tested; repositories replace those audit values with server timestamps at
the transaction boundary. Fake repositories use UTC `DateTime` values.

Current limitations:

- templates do not store an IANA timezone identifier;
- travel or a device timezone change does not reinterpret old date keys;
- daylight-saving transitions use the device’s wall-clock calendar and minute
  fields, not a timezone-aware recurrence engine.

A future timezone migration must add a new schema version rather than silently
changing version 1 date meaning.

## 5. Stable identifiers

All document IDs are non-empty, trimmed, at most 128 characters, and cannot
contain `/`, `.` as a whole ID, or `..` as a whole ID.

### Onboarding template IDs

Initial onboarding template IDs are deterministic:

```text
onb_{first 40 hex characters of SHA-256(
  "routine-onboarding-v1" + owner UID + source item identity
)}
```

The owner UID is part of the input, so two users receive different document
IDs even when their source schedules are identical. Rebuilding the same
completion bundle produces the same IDs.

### Occurrence IDs

Occurrence IDs are deterministic:

```text
occ_{first 40 hex characters of SHA-256(
  "routine-occurrence-v1" + owner UID + template ID + occurrenceDateKey
)}
```

The document ID plus `operationKey` makes repeated status delivery
idempotent. The `operationKey` is generated as a collision-resistant UUID v4
for each new user action. When a write fails and enters the retry state,
the exact same `operationKey` is re-sent.

### Undo to Planned

Undo is supported ONLY when the occurrence was previously in the `planned` state,
meaning there was no prior persisted occurrence override. When a new occurrence
override is created from `planned`, it persists `undoToPlannedAllowed = true`.
Calling `undo` deletes the occurrence override (`deleteHistory()`), returning the
item to the `planned` state. If an earlier explicit state exists (e.g. going
from `completed` to `skipped`), `undoToPlannedAllowed` is `false` and undo is not allowed.

### Provider Ownership

In Firebase production mode, `routineNotifierProvider` is the sole authoritative
owner of the Routine state (templates, occurrences, loading, refresh, mutations,
and offline retry). `mockRoutineProvider` is strictly excluded from production
use and is only permitted in `OptivusBackendMode.fake` or test environments.

### Projection ID

The initial setup receipt uses the fixed slot:

```text
onboarding-initial-v1
```

The receipt contains the full bundle fingerprint. A different bundle does not
silently become an implicit rebuild after initial projection. A future
user-confirmed rebuild requires a separate command and receipt design.

## 6. Template Firestore document

Required version 1 fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | string | Must equal `{routineItemId}` |
| `ownerUid` | string | Must equal authenticated/path UID |
| `title` | string | Trimmed, 1–200 characters |
| `category` | string enum | A `RoutineCategory` name |
| `source` | string enum | A `RoutineSource` name |
| `blockType` | string enum | A `RoutineBlockType` name |
| `priority` | string enum | `mustDo` or `goodToDo` |
| `startMinute` | integer | 0–1439 |
| `endMinute` | integer | 0–1440 and a valid range |
| `repeatRule` | string enum | `once`, `daily`, `weekly`, `weekdays`, or `weekends` |
| `repeatDays` | integer list | Unique values 1–7 |
| `crossesMidnight` | boolean | Overnight indicator |
| `endsNextDay` | boolean | Overnight indicator |
| `isTrackerLinked` | boolean | Template tracker-link configuration |
| `trackerType` | string enum | A `TrackerType` name |
| `hardBlock` | boolean | User-owned block configuration |
| `allowOverlap` | boolean | Explicit user overlap decision |
| `createdAt` | Firestore timestamp | Creation audit instant |
| `updatedAt` | Firestore timestamp | Last-write audit instant |
| `schemaVersion` | integer | `1` |

Allowed optional fields:

| Field | Type |
| --- | --- |
| `dateKey`, `endDateKey` | local date string |
| `location`, `notes`, `bestTime`, `mealCategory` | string |
| `subtasks`, `steps`, `dishes` | string list |
| `caloriesEstimate`, `proteinEstimate` | number |
| `onboardingProjectionId`, `onboardingSourceItemId` | string |

The canonical document never writes:

- `status`, `isCompleted`, `isMissed`, or `subtasksCompleted`;
- `hasConflict` or `conflictMessage`;
- `isContinuation`;
- selected filters, loading/error state, current-time state, or launch intents;
- local image bytes, byte arrays, preview paths, file paths, or local asset
  paths; or
- compatibility-only `skincareProducts` (its user-visible content is written
  through `steps`).

## 7. Occurrence Firestore document

Required version 1 fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | string | Must equal `{occurrenceId}` |
| `ownerUid` | string | Must equal authenticated/path UID |
| `routineItemId` | string | Canonical template ID |
| `occurrenceDateKey` | local date string | Scheduled start date |
| `status` | string enum | Durable occurrence status |
| `source` | string enum | `routine`, `tracker`, `checkIn`, `money`, or `system` |
| `action` | string enum | The command that produced the current state |
| `operationKey` | string | Stable retry/idempotency key (UUID v4) |
| `completedSubtaskIndexes` | integer list | Dated subtask completion |
| `undoToPlannedAllowed` | boolean | True if this occurrence overrides a planned state |
| `createdAt`, `updatedAt` | Firestore timestamp | Audit instants |
| `schemaVersion` | integer | `1` |

Allowed optional fields are move fields, `note`, and
`displayTitleOverride`. A `moved` record requires all three move fields and a
valid same-day time range.

## 8. Projection receipt document

Receipts are stored at:

```text
users/{uid}/routineProjections/onboarding-initial-v1
```

Fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | `onboarding-initial-v1` | Must equal the projection document ID |
| `ownerUid` | string | Must equal authenticated/path UID |
| `slot` | `onboarding-initial` | Projection slot family |
| `revision` | integer | Slot revision; current value is `1` |
| `source` | `onboarding` | Projection source |
| `sourceBundleSchemaVersion` | integer | Completion bundle schema version |
| `sourceBundleId` | stable string | Source completion bundle ID |
| `sourceBundleFingerprint` | 64-character SHA-256 hex string | Canonical source fingerprint |
| `expectedItemIds` | list of canonical Routine template IDs | All item IDs expected from the bundle |
| `createdItemIds` | list of canonical Routine template IDs | Items newly created by this projection |
| `existingItemIds` | list of canonical Routine template IDs | Existing valid items preserved |
| `repairedItemIds` | list of canonical Routine template IDs | Items repaired by an explicit recovery path |
| `failedItemIds` | list of canonical Routine template IDs | Items not applied during a partial/retry state |
| `projectedItemIds` | list of canonical Routine template IDs | Backward-compatible applied item list |
| `eventSchemaVersion` | integer | Projection event schema version; current value is `1` |
| `totalCount` | integer | Count of expected or applied projection items |
| `cursor` | integer | Progress cursor; completed receipts have `cursor == totalCount` |
| `status` | `pending` or `completed` | Projection status |
| `createdAt`, `updatedAt` | Firestore timestamp | Audit instants |
| `completedAt` | Firestore timestamp | Required when `status == completed` |
| `lastSafeError` | string | Optional sanitized retry/error message |
| `schemaVersion` | `1` | Receipt schema version |

The receipt is create-only. Normal clients cannot update or delete it.

## 9. Onboarding projection algorithm

Firebase onboarding completion uses one Firestore transaction:

1. Validate that draft UID, bundle UID, and authenticated owner agree.
2. Normalize every `routineItemsForApp` item, strip daily/derived state, and
   generate deterministic IDs and a canonical SHA-256 fingerprint.
3. Read `onboarding-initial-v1`.
4. If the receipt exists, return a truthful `noOp` result without rewriting
   the bundle, templates, profile, or receipt.
5. Read the deterministic template documents before any transaction write.
6. Write the final draft, completion bundle, profile completion patch, only
   absent normalized template documents, and the completed receipt.
7. Commit all writes together.

Transaction failure leaves no completed profile, bundle, Routine templates, or
receipt from that attempt. The fake repository stages and swaps all equivalent
in-memory records together and has an injected-failure regression test.
Transaction failure exposes `RoutineProjectionOutcome.retryRequired` through a
typed retry-required exception; a successful first commit returns `projected`
and an existing receipt returns `noOp`.

No onboarding occurrence/history record is created by this projection. The
completion bundle already normalizes class, work, eating, fixed, skin-care,
approved habit, identity-system, money, and check-in schedule items into
`routineItemsForApp`; only the eligible Routine templates in that list are
projected.

Habit System projection is handled by the Habit Systems owner boundary through
`HabitSystemsRepository.reconcileProjectedSystems`, which uses owner-scoped
documents and a projection receipt. Tracker, Goals, Coach, and Home owner
projection remains outside this contract and belongs to their later feature
phases; current local hydration into those areas is not durable production
ownership.

## 10. Protection of user edits and deletion

Projection creates absent deterministic documents only. It never uses
`merge: true` over an existing Routine template.

After initial projection:

- edits use per-document writes and preserve creation time and onboarding
  provenance;
- deletion removes the template document but leaves the completed projection
  receipt;
- sign-in loads current canonical documents and therefore keeps deleted items
  absent;
- sign-in never replays the completion bundle;
- retry sees the receipt and returns `noOp`; and
- even a changed completion snapshot cannot use the initial slot as an
  implicit rebuild.

Legacy completed accounts with a missing or mismatched receipt are held at the
truthful backend-restore error gate. They are not silently routed into an empty
Routine and are not automatically reprojected. An explicit legacy recovery or
rebuild command is later Phase 4 work.

## 11. Repository and restore contract

`RoutineRepository` supports:

- fetch owner-scoped templates;
- save one template;
- create a bounded set only when each ID is absent;
- delete one template; and
- fetch a projection receipt.

It has no whole-list replacement operation.

`RoutineHistoryRepository` fetches and idempotently upserts owner-scoped
occurrences.

`RoutineTransactionRepository` owns multi-record Routine transactions such as
template/history/projection operations that must commit atomically.

`HabitSystemsRepository` owns Habit System create/update/archive/restore,
owner-scoped reads, projection reconciliation, and watch streams.

Firebase mode selects the Firestore implementations. Fake mode selects
in-memory implementations and keeps seeded/test behavior available.

Completed Firebase restoration is:

1. load authenticated profile and completion bundle;
2. derive the expected initial projection fingerprint;
3. require the matching completed receipt;
4. load canonical templates and occurrences into
   `routineNotifierProvider`;
5. hydrate still-local non-Routine features from their bootstrap snapshot; and
6. leave `mockRoutineProvider` empty.

Automatic sign-in repair no longer reapplies accepted Routine imports.
Explicit missing-import recovery remains available from the review flow; this
prevents normal authentication from treating a user deletion as corruption.

## 12. Backward compatibility and migration

Version 1 canonical reads are strict: malformed enum values, repeat days,
owner IDs, document IDs, time ranges, or required fields are rejected.

Legacy documents without `schemaVersion` may use:

- `userId` instead of `ownerUid`;
- ISO date/time strings or `DateTime` values;
- legacy `date`/`endDate` values;
- `calories`/`protein`;
- `skincareProducts`; and
- missing enum fields.

Legacy unknown enums fall back to safe display values, and legacy daily status
fields are discarded rather than promoted into a template. After a valid user
write, the document is emitted as strict schema version 1.

Future incompatible changes increment `schemaVersion`, add an idempotent
migration, retain fixtures for supported older versions, and fail safely for
unknown newer versions.

## 13. Security and verification status

Collection-specific rules exist for templates, occurrences, and projection
receipts, plus Habit Systems. They enforce verified authenticated ownership,
path/data ID agreement, expected keys, enum/type/time/repeat constraints,
immutable creation identity on updates, and exclusion from the broad
development catch-all.

A checked-in Firebase emulator/Jest harness now exercises Firestore rules
locally. On 2026-09-05, `firebase emulators:exec --only firestore "npm test"`
passed 130 tests. That closes the former "no emulator harness" gap for local
rules coverage, but it does not prove deployed Firebase configuration,
physical-device restoration, another-device acceptance, CI execution, or full
Routine UX acceptance. Those remain open Routine Production Closure gates
before any Live claim.
