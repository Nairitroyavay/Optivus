
const { assertFails, assertSucceeds, initializeTestEnvironment } = require("@firebase/rules-unit-testing");
const { serverTimestamp } = require("firebase/firestore");
const fs = require("fs");

let testEnv;
const createdAt = new Date("2026-07-24T00:00:00.000Z");
const updatedAt = new Date("2026-07-24T00:05:00.000Z");
const completedAt = new Date("2026-07-24T00:10:00.000Z");

function ownerDb(uid = "user123", verified = true) {
  return testEnv
    .authenticatedContext(uid, { email_verified: verified })
    .firestore();
}

function routineItemData(uid = "user123", id = "routine-item-1", overrides = {}) {
  return {
    id,
    ownerUid: uid,
    title: "Morning focus",
    category: "fixed",
    source: "manual",
    blockType: "flexibleTask",
    priority: "goodToDo",
    startMinute: 600,
    endMinute: 660,
    repeatRule: "weekly",
    repeatDays: [1, 2, 3, 4, 5],
    crossesMidnight: false,
    endsNextDay: false,
    isTrackerLinked: false,
    trackerType: "none",
    hardBlock: false,
    allowedConflicts: [],
    createdAt,
    updatedAt,
    schemaVersion: 1,
    ...overrides,
  };
}

function validAllowance(overrides = {}) {
  return {
    schemaVersion: 1,
    canonicalPairId: "routine-item-1_routine-item-2",
    conflictType: "timeOverlap",
    evaluatedDateKey: "2026-07-24",
    scheduleFingerprint: "v1|timeOverlap|routine-item-1:600:660:false:false:::1,2,3,4,5:weekly|routine-item-2:630:690:false:false:::1,2,3,4,5:weekly",
    ...overrides,
  };
}

function occurrenceData(uid = "user123", id = "occurrence-1", overrides = {}) {
  return {
    id,
    ownerUid: uid,
    routineItemId: "routine-item-1",
    occurrenceDateKey: "2026-07-24",
    status: "moved",
    source: "routine",
    action: "reschedule",
    operationKey: "occurrence-operation-1",
    movedToDateKey: "2026-07-25",
    movedStartMinute: 700,
    movedEndMinute: 760,
    completedSubtaskIndexes: [],
    undoToPlannedAllowed: true,
    createdAt,
    updatedAt,
    schemaVersion: 1,
    ...overrides,
  };
}

function eventSnapshot(overrides = {}) {
  return {
    id: "routine-item-1",
    title: "Morning focus",
    startMinute: 600,
    durationMinutes: 60,
    blockType: "flexibleTask",
    trackerTaskType: "none",
    hardBlock: false,
    ...overrides,
  };
}

function eventData(uid = "user123", id = "event-1", overrides = {}) {
  return {
    schemaVersion: 1,
    eventId: id,
    ownerUid: uid,
    routineItemId: "routine-item-1",
    eventType: "created",
    operationKey: "routine-operation-1",
    source: "app",
    occurredAt: createdAt,
    itemSnapshot: eventSnapshot(),
    ...overrides,
  };
}

function projectionData(uid = "user123", overrides = {}) {
  return {
    id: "onboarding-initial-v1",
    ownerUid: uid,
    slot: "onboarding-initial",
    revision: 1,
    source: "onboarding",
    sourceBundleSchemaVersion: 1,
    sourceBundleId: "bundle-1",
    sourceBundleFingerprint:
      "0000000000000000000000000000000000000000000000000000000000000000",
    projectedItemIds: ["routine-item-1", "routine-item-2"],
    eventSchemaVersion: 1,
    totalCount: 2,
    cursor: 0,
    status: "pending",
    createdAt,
    updatedAt,
    schemaVersion: 1,
    ...overrides,
  };
}

function habitSystemData(uid = "user123", id = "habitsys-1", overrides = {}) {
  return {
    systemId: id,
    ownerUid: uid,
    title: "Daily Meditation",
    description: "10m morning mindfulness",
    category: "meditation",
    systemType: "goodHabit",
    status: "active",
    linkedRoutineIds: ["routine-item-1"],
    source: "user",
    createdAt,
    updatedAt,
    schemaVersion: 1,
    version: 1,
    ...overrides,
  };
}

function userData(uid = "user123", overrides = {}) {
  return {
    uid,
    schemaVersion: 1,
    displayName: "Test User",
    email: "user@example.com",
    onboardingCompleted: false,
    createdAt,
    updatedAt,
    ...overrides,
  };
}

const fingerprint =
  "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
const canonicalRunId = `run_${"1".repeat(40)}`;
const verifiableRunId = `run_${fingerprint}`;
const replacementFingerprint = "f".repeat(64);
const replacementRunId = `run_${replacementFingerprint}`;
const canonicalProjectionId = `onboarding-${canonicalRunId}-v1`;
const canonicalAcceptanceId = `ca_${"a".repeat(40)}`;

const completionBundleRequiredKeys = [
  "uid",
  "runId",
  "schemaVersion",
  "source",
  "sourceFingerprint",
  "draftRevision",
  "createdAt",
  "updatedAt",
  "onboardingCompleted",
  "userProfilePatch",
  "baseTimelineBlocks",
  "finalTimelineItems",
  "routineItemsForApp",
  "goodHabitTemplates",
  "badHabitCheckIns",
  "identityGoalSystems",
  "notificationPreferences",
  "coachPreferences",
  "uploadedAssetReferences",
  "warnings",
  "duplicateSystemKeysMerged",
  "expectedRoutineIds",
  "expectedHistoryIds",
  "expectedHabitIds",
  "acceptedSourceIds",
  "generatedSourceIds",
  "conflictAcceptances",
  "expectedAcceptanceIds",
  "unscheduledRoutineSuggestions",
];

function profileSettingsData(uid = "user123", overrides = {}) {
  return {
    uid,
    schemaVersion: 1,
    name: "Test User",
    username: "test_user",
    bio: "",
    customIdentityDisplay: false,
    photoState: "none",
    displayName: "Test User",
    createdAt,
    updatedAt,
    ...overrides,
  };
}

function regionData(uid = "user123", overrides = {}) {
  return {
    userId: uid,
    schemaVersion: 1,
    countryCode: "IN",
    countryName: "India",
    timezone: "Asia/Kolkata",
    languageCode: "en",
    currencyCode: "INR",
    currencySymbol: "₹",
    measurementSystem: "metric",
    heightUnit: "cm",
    weightUnit: "kg",
    distanceUnit: "km",
    temperatureUnit: "celsius",
    timeFormat: "12h",
    dateFormat: "dd/MM/yyyy",
    weekStartDay: "monday",
    foodVocabularyMode: "international",
    paymentRegion: "IN",
    source: "userSaved",
    createdAt,
    updatedAt,
    ...overrides,
  };
}

function appPreferencesData(uid = "user123", overrides = {}) {
  return {
    uid,
    schemaVersion: 1,
    haptics: true,
    autoCorrect: false,
    themeMode: "dark",
    accentColor: "teal",
    bottomTabLayout: "standard",
    timelineDisplay: "compact",
    coachVoice: "direct",
    createdAt,
    updatedAt,
    ...overrides,
  };
}

function onboardingDraftData(uid = "user123", overrides = {}) {
  return {
    uid,
    schemaVersion: 4,
    source: "onboarding",
    revision: 7,
    sourceFingerprint: fingerprint,
    timezoneId: "Asia/Kolkata",
    currentStep: 2,
    stepCompleted: [true, true, false, false, false, false, false, false, false, false, false, false, false, false, false],
    stepCompletionContractVersions: Array(15).fill(1),
    stepDirty: Array(15).fill(false),
    stepLoading: Array(15).fill(false),
    onboardingCompleted: false,
    welcomeSaved: true,
    patiencePledgeAccepted: true,
    badHabitsNotNow: true,
    badHabits: [],
    goodHabitsNotNow: true,
    goodHabits: [],
    identityGoals: [],
    lifeRole: {},
    bodyBasics: {},
    baseTimeline: {},
    coachSetup: {},
    notifications: {},
    createdAt,
    updatedAt,
    ...overrides,
  };
}

function completedOnboardingDraftData(uid = "user123", overrides = {}) {
  return onboardingDraftData(uid, {
    currentStep: 14,
    stepCompleted: Array(15).fill(true),
    onboardingCompleted: true,
    ...overrides,
  });
}

function completionBundleData(uid = "user123", overrides = {}) {
  return {
    uid,
    runId: canonicalRunId,
    schemaVersion: 2,
    source: "onboarding",
    sourceFingerprint: fingerprint,
    draftRevision: 7,
    onboardingCompleted: true,
    userProfilePatch: { uid, onboardingCompleted: false },
    baseTimelineBlocks: [],
    finalTimelineItems: [],
    routineItemsForApp: [],
    goodHabitTemplates: [],
    badHabitCheckIns: [],
    identityGoalSystems: [],
    notificationPreferences: {},
    coachPreferences: {},
    uploadedAssetReferences: [],
    warnings: [],
    duplicateSystemKeysMerged: [],
    expectedRoutineIds: [],
    expectedHistoryIds: [],
    expectedHabitIds: [],
    acceptedSourceIds: [],
    generatedSourceIds: [],
    conflictAcceptances: [],
    expectedAcceptanceIds: [],
    unscheduledRoutineSuggestions: [],
    createdAt,
    updatedAt,
    ...overrides,
  };
}

function completionBundleConflictAcceptanceData(uid = "user123") {
  return {
    acceptanceId: canonicalAcceptanceId,
    ownerUid: uid,
    canonicalPairHash: "b".repeat(64),
    firstSourceBlockId: "class-source-1",
    secondSourceBlockId: "breakfast-source-1",
    firstProjectedRoutineId: "onb_class_1",
    secondProjectedRoutineId: "onb_breakfast_1",
    conflictType: "compatibleOverlap",
    scope: "recurringWeekdays",
    dateKey: "",
    applicableWeekdays: [1, 3, 5],
    timezoneId: "Asia/Calcutta",
    firstScheduleFingerprint: "c".repeat(64),
    secondScheduleFingerprint: "d".repeat(64),
    combinedScheduleFingerprint: "e".repeat(64),
    sourceBundleFingerprint: fingerprint,
    projectionId: `onboarding-${canonicalRunId}`,
    acceptedAt: createdAt.toISOString(),
    acceptedFrom: "onboarding",
    status: "active",
    invalidatedAt: null,
    invalidationReason: null,
    schemaVersion: 2,
  };
}

function unscheduledRoutineSuggestionData() {
  return {
    id: "suggestion-1",
    sourceItemId: "source-1",
    title: "Review schedule",
    reason: "No conflict-free slot",
    repeatDays: [1, 3, 5],
    durationMinutes: 30,
    schemaVersion: 1,
  };
}

function onboardingJobData(uid = "user123", overrides = {}) {
  return {
    jobId: "current",
    ownerUid: uid,
    stage: "validateInput",
    status: "pending",
    stagesCompleted: {},
    sourceFingerprint: fingerprint,
    draftRevision: 7,
    retryCount: 0,
    failedEntityIds: [],
    expectedRoutineIds: [],
    createdRoutineIds: [],
    existingRoutineIds: [],
    repairedRoutineIds: [],
    failedRoutineIds: [],
    expectedHistoryIds: [],
    appliedHistoryIds: [],
    existingHistoryIds: [],
    repairedHistoryIds: [],
    failedHistoryIds: [],
    expectedHabitIds: [],
    createdHabitIds: [],
    existingHabitIds: [],
    repairedHabitIds: [],
    failedHabitIds: [],
    createdAt,
    updatedAt,
    schemaVersion: 2,
    ...overrides,
  };
}

function onboardingRunData(uid = "user123", runId = "run-001", overrides = {}) {
  return {
    jobId: runId,
    ownerUid: uid,
    stage: "validateInput",
    status: "running",
    stagesCompleted: {},
    sourceFingerprint: fingerprint,
    draftRevision: 7,
    retryCount: 0,
    failedEntityIds: [],
    expectedRoutineIds: [],
    createdRoutineIds: [],
    existingRoutineIds: [],
    repairedRoutineIds: [],
    failedRoutineIds: [],
    expectedHistoryIds: [],
    appliedHistoryIds: [],
    existingHistoryIds: [],
    repairedHistoryIds: [],
    failedHistoryIds: [],
    expectedHabitIds: [],
    createdHabitIds: [],
    existingHabitIds: [],
    repairedHabitIds: [],
    failedHabitIds: [],
    expectedAcceptanceIds: [],
    appliedAcceptanceIds: [],
    existingAcceptanceIds: [],
    repairedAcceptanceIds: [],
    failedAcceptanceIds: [],
    createdAt,
    updatedAt,
    schemaVersion: 3,
    ...overrides,
  };
}

function failedOnboardingRunData(uid = "user123", runId = "run-001", overrides = {}) {
  return onboardingRunData(uid, runId, {
    status: "retryableFailure",
    retryCount: 1,
    failureCode: "persist_bundle_failed",
    failureStage: "persistBundle",
    retryable: true,
    publicMessageKey: "error_persist_bundle",
    diagnosticCategory: "transient_failure",
    safeCauseType: "FirebaseException",
    failureOccurredAt: completedAt,
    ...overrides,
  });
}

function currentRunData(uid = "user123", runId = "run-001", overrides = {}) {
  return {
    ownerUid: uid,
    currentRunId: runId,
    sourceFingerprint: fingerprint,
    draftRevision: 7,
    status: "active",
    updatedAt,
    schemaVersion: 1,
    ...overrides,
  };
}

const acceptanceId = `ca_${"a".repeat(40)}`;

function conflictAcceptanceData(uid = "user123", overrides = {}) {
  return {
    acceptanceId,
    ownerUid: uid,
    canonicalPairHash: "b".repeat(64),
    firstSourceBlockId: "class-source-1",
    secondSourceBlockId: "breakfast-source-1",
    firstProjectedRoutineId: "onb_class_1",
    secondProjectedRoutineId: "onb_breakfast_1",
    conflictType: "compatibleOverlap",
    scope: "recurringWeekdays",
    dateKey: "",
    applicableWeekdays: [1, 3, 5],
    timezoneId: "Asia/Calcutta",
    firstScheduleFingerprint: "c".repeat(64),
    secondScheduleFingerprint: "d".repeat(64),
    combinedScheduleFingerprint: "e".repeat(64),
    sourceBundleFingerprint: fingerprint,
    projectionId: "onboarding-run-001-v1",
    acceptedAt: createdAt,
    acceptedFrom: "onboarding",
    status: "active",
    invalidatedAt: null,
    invalidationReason: null,
    schemaVersion: 2,
    ...overrides,
  };
}

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "optivus-lifeos",
    firestore: {
      rules: fs.readFileSync("firestore.rules", "utf8"),
    },
  });
}, 30000);

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe("Firestore Rules for syncAllowances and syncEvents", () => {
  it("should allow a verified owner to create a syncAllowance", async () => {
    const db = testEnv.authenticatedContext("user123", { email_verified: true }).firestore();
    const docRef = db.collection("users").doc("user123").collection("syncAllowances").doc("allowance1");
    
    await assertSucceeds(docRef.set({
      id: "allowance1",
      ownerUid: "user123",
      schemaVersion: 1,
      pair: "device1:device2",
      conflictType: "overwrite",
      dateKey: "2026-07-24",
      fingerprint: "0000000000000000000000000000000000000000000000000000000000000000",
      createdAt,
      updatedAt
    }));
  });

  it("should fail if conflictType is invalid in syncAllowance", async () => {
    const db = testEnv.authenticatedContext("user123", { email_verified: true }).firestore();
    const docRef = db.collection("users").doc("user123").collection("syncAllowances").doc("allowance1");
    
    await assertFails(docRef.set({
      id: "allowance1",
      ownerUid: "user123",
      schemaVersion: 1,
      pair: "device1:device2",
      conflictType: "invalidType",
      dateKey: "2026-07-24",
      fingerprint: "0000000000000000000000000000000000000000000000000000000000000000",
      createdAt,
      updatedAt
    }));
  });

  it("should allow a verified owner to create a syncEvent", async () => {
    const db = testEnv.authenticatedContext("user123", { email_verified: true }).firestore();
    const docRef = db.collection("users").doc("user123").collection("syncEvents").doc("event1");
    
    await assertSucceeds(docRef.set({
      id: "event1",
      ownerUid: "user123",
      source: "client",
      snapshotKeys: ["key1"],
      snapshotStrings: ["string1"],
      snapshotLists: ["list1"],
      createdAt
    }));
  });

  it("should prevent updating syncEvents (append-only)", async () => {
    const db = testEnv.authenticatedContext("user123", { email_verified: true }).firestore();
    const docRef = db.collection("users").doc("user123").collection("syncEvents").doc("event1");
    
    await assertSucceeds(docRef.set({
      id: "event1",
      ownerUid: "user123",
      source: "client",
      snapshotKeys: [],
      snapshotStrings: [],
      snapshotLists: [],
      createdAt
    }));

    await assertFails(docRef.update({
      source: "server"
    }));
  });

  it("should prevent cross-user writes", async () => {
    const db = testEnv.authenticatedContext("user123", { email_verified: true }).firestore();
    const docRef = db.collection("users").doc("otherUser").collection("syncEvents").doc("event1");
    
    await assertFails(docRef.set({
      id: "event1",
      ownerUid: "otherUser",
      source: "client",
      snapshotKeys: [],
      snapshotStrings: [],
      snapshotLists: [],
      createdAt
    }));
  });
});

describe("Firestore Rules for Routine durability", () => {
  it("allows only canonical run-scoped onboarding projection IDs", async () => {
    const db = ownerDb();
    const projections = db
      .collection("users")
      .doc("user123")
      .collection("routineProjections");

    await assertSucceeds(
      projections
        .doc(canonicalProjectionId)
        .set(
          projectionData("user123", {
            id: canonicalProjectionId,
            slot: `onboarding-${canonicalRunId}`,
          })
        )
    );
    await assertFails(
      projections
        .doc("onboarding-run_not-canonical-v1")
        .set(projectionData("user123", { id: "onboarding-run_not-canonical-v1" }))
    );
    await assertFails(
      projections
        .doc(canonicalProjectionId)
        .set(projectionData("user123", { id: "onboarding-initial-v1" }))
    );
    await assertFails(
      projections.doc(canonicalProjectionId).set(
        projectionData("user123", {
          id: canonicalProjectionId,
          slot: "onboarding-initial",
        })
      )
    );
    await assertFails(
      projections.doc(canonicalProjectionId).set(
        projectionData("user123", {
          id: canonicalProjectionId,
          slot: `onboarding-${canonicalRunId}`,
          revision: 2,
        })
      )
    );
  });

  it("allows the full onboarding reconcile write-set atomically", async () => {
    const db = ownerDb();
    const user = db.collection("users").doc("user123");
    await assertSucceeds(user.set(userData()));

    const batch = db.batch();
    batch.set(
      user.collection("onboarding").doc("draft"),
      onboardingDraftData("user123", {
        currentStep: 14,
        stepCompleted: Array(15).fill(true),
        onboardingCompleted: true,
      })
    );
    batch.set(
      user.collection("onboarding").doc("completionBundle"),
      completionBundleData()
    );
    batch.set(
      user,
      {
        schemaVersion: 1,
        onboardingInputCompleted: true,
        onboardingProjectionStatus: "pending",
        onboardingCompleted: false,
        updatedAt,
      },
      { merge: true }
    );
    for (let index = 0; index < 53; index += 1) {
      const itemId = `onb_${index.toString(16).padStart(40, "0")}`;
      batch.set(
        user.collection("routineItems").doc(itemId),
        routineItemData("user123", itemId, {
          source: "onboarding",
          onboardingProjectionId: canonicalProjectionId,
          onboardingSourceItemId: `source-${index}`,
        })
      );
    }
    for (let index = 0; index < 17; index += 1) {
      const id = `ca_${(index + 1).toString(16).padStart(40, "0")}`;
      batch.set(
        user.collection("conflictAcceptances").doc(id),
        conflictAcceptanceData("user123", {
          acceptanceId: id,
          projectionId: canonicalProjectionId,
        })
      );
    }
    batch.set(
      user.collection("routineProjections").doc(canonicalProjectionId),
      projectionData("user123", {
        id: canonicalProjectionId,
        slot: `onboarding-${canonicalRunId}`,
        projectedItemIds: Array.from(
          { length: 53 },
          (_, index) => `onb_${index.toString(16).padStart(40, "0")}`
        ),
        totalCount: 53,
      })
    );

    await assertSucceeds(batch.commit());
  });

  it("allows verified owner Routine template reads and writes", async () => {
    const db = ownerDb();
    const docRef = db.collection("users").doc("user123").collection("routineItems").doc("routine-item-1");

    await assertSucceeds(docRef.set(routineItemData()));
    await assertSucceeds(docRef.get());
  });

  it("rejects cross-user and unverified Routine access", async () => {
    const owner = ownerDb();
    const crossUser = ownerDb("user456");
    const unverified = ownerDb("user123", false);
    const docRef = owner.collection("users").doc("user123").collection("routineItems").doc("routine-item-1");

    await assertSucceeds(docRef.set(routineItemData()));
    await assertFails(crossUser.collection("users").doc("user123").collection("routineItems").doc("routine-item-1").get());
    await assertFails(unverified.collection("users").doc("user123").collection("routineItems").doc("routine-item-1").get());
  });

  it("rejects malformed templates and legacy allowOverlap bypass attempts", async () => {
    const db = ownerDb();
    const docRef = db.collection("users").doc("user123").collection("routineItems").doc("routine-item-1");

    await assertFails(docRef.set(routineItemData("user123", "routine-item-1", {
      endMinute: 600,
    })));

    await assertFails(docRef.set({
      ...routineItemData(),
      allowOverlap: true,
    }));
  });

  it("validates Routine conflict allowances strictly", async () => {
    const db = ownerDb();
    const docRef = db.collection("users").doc("user123").collection("routineItems").doc("routine-item-1");

    await assertSucceeds(docRef.set(routineItemData("user123", "routine-item-1", {
      allowedConflicts: [validAllowance()],
    })));

    await assertFails(docRef.set(routineItemData("user123", "routine-item-1", {
      allowedConflicts: [validAllowance({ scheduleFingerprint: "" })],
    })));
  });

  it("supports valid reschedule occurrences and rejects malformed occurrences", async () => {
    const db = ownerDb();
    const docRef = db.collection("users").doc("user123").collection("routineHistory").doc("occurrence-1");

    await assertSucceeds(docRef.set(occurrenceData()));
    await assertFails(docRef.set(occurrenceData("user123", "occurrence-1", {
      action: "teleport",
    })));
    await assertFails(docRef.set(occurrenceData("user123", "occurrence-1", {
      undoToPlannedAllowed: "yes",
    })));
  });

  it("requires strict append-only Routine events", async () => {
    const db = ownerDb();
    const docRef = db.collection("users").doc("user123").collection("routineEvents").doc("event-1");

    await assertSucceeds(docRef.set(eventData()));
    await assertFails(docRef.update({ source: "system" }));
    await assertFails(docRef.delete());
  });

  it("rejects malformed Routine events", async () => {
    const db = ownerDb();
    const docRef = db.collection("users").doc("user123").collection("routineEvents").doc("event-1");

    await assertFails(docRef.set(eventData("user123", "event-2")));
    await assertFails(docRef.set(eventData("user123", "event-1", {
      itemSnapshot: eventSnapshot({ title: "" }),
    })));
    await assertFails(docRef.set(eventData("user123", "event-1", {
      eventType: "completed",
    })));
  });

  it("allows valid projection progress and rejects invalid transitions", async () => {
    const db = ownerDb();
    const docRef = db.collection("users").doc("user123").collection("routineProjections").doc("onboarding-initial-v1");

    await assertSucceeds(docRef.set(projectionData()));
    await assertSucceeds(docRef.update(projectionData("user123", {
      cursor: 1,
      updatedAt,
    })));
    await assertFails(docRef.update(projectionData("user123", {
      cursor: 0,
      updatedAt: completedAt,
    })));
  });

  it("allows completed projection receipt only at total cursor", async () => {
    const db = ownerDb();
    const docRef = db.collection("users").doc("user123").collection("routineProjections").doc("onboarding-initial-v1");

    await assertSucceeds(docRef.set(projectionData()));
    await assertFails(docRef.update(projectionData("user123", {
      cursor: 1,
      status: "completed",
      completedAt,
    })));
    await assertSucceeds(docRef.update(projectionData("user123", {
      cursor: 2,
      status: "completed",
      updatedAt: completedAt,
      completedAt,
    })));
  });

  it("allows verified owner Habit System reads, writes, and updates", async () => {
    const db = ownerDb();
    const docRef = db.collection("users").doc("user123").collection("habitSystems").doc("habitsys-1");

    await assertSucceeds(docRef.set(habitSystemData()));
    await assertSucceeds(docRef.update({
      title: "Updated Meditation",
      status: "paused",
      updatedAt: completedAt,
      version: 2,
    }));
    await assertSucceeds(docRef.delete());
  });

  it("rejects cross-user Habit System access and ownerUid mutation", async () => {
    const db = ownerDb("other_user");
    const docRef = db.collection("users").doc("user123").collection("habitSystems").doc("habitsys-1");

    await assertFails(docRef.set(habitSystemData("user123")));
    await assertFails(docRef.get());

    const owner = ownerDb("user123");
    const ownerDoc = owner.collection("users").doc("user123").collection("habitSystems").doc("habitsys-1");
    await assertSucceeds(ownerDoc.set(habitSystemData("user123")));

    await assertFails(ownerDoc.update({ ownerUid: "hacker", version: 2 }));
    await assertFails(ownerDoc.update({ systemId: "other_id", version: 2 }));
  });

  it("does not let the catch-all bypass strict Routine collections", async () => {
    const db = ownerDb();

    await assertFails(
      db.collection("users").doc("user123").collection("routineEvents").doc("event-1").set({
        id: "event-1",
        ownerUid: "user123",
        arbitrary: true,
        createdAt,
      })
    );

    await assertFails(
      db.collection("users").doc("user123").collection("routineProjections").doc("other-projection").set(projectionData("user123", {
        id: "other-projection",
      }))
    );

    await assertFails(
      db.collection("users").doc("user123").collection("habitSystems").doc("habitsys-1").set({
        systemId: "habitsys-1",
        ownerUid: "user123",
        unknownField: true,
      })
    );
  });

  describe("Issue 64: Firestore Security Rules for Users, Onboarding Jobs, and Routine Rules", () => {
    it("allows verified owner user profile document access and rejects unverified or cross-user access", async () => {
      const verifiedOwner = ownerDb("user123", true);
      const unverifiedOwner = ownerDb("user123", false);
      const otherUser = ownerDb("other_user", true);

      const docRef = verifiedOwner.collection("users").doc("user123");
      await assertSucceeds(docRef.set(userData("user123")));
      await assertSucceeds(docRef.get());

      const unverifiedDocRef = unverifiedOwner.collection("users").doc("user123");
      await assertFails(unverifiedDocRef.set(userData("user123")));

      const otherDocRef = otherUser.collection("users").doc("user123");
      await assertFails(otherDocRef.set(userData("user123")));
      await assertFails(otherDocRef.get());
    });

    it("allows verified owner onboarding completion job access and rejects cross-user access", async () => {
      const owner = ownerDb("user123", true);
      const otherUser = ownerDb("other_user", true);

      const jobRef = owner.collection("users").doc("user123").collection("onboardingCompletionJobs").doc("current");
      await assertSucceeds(jobRef.set(onboardingJobData("user123")));
      await assertSucceeds(jobRef.get());

      const otherJobRef = otherUser.collection("users").doc("user123").collection("onboardingCompletionJobs").doc("current");
      await assertFails(otherJobRef.set(onboardingJobData("user123")));
      await assertFails(otherJobRef.get());
    });

    it("validates routine template 'job' category and prohibits modifying immutable projection fields", async () => {
      const owner = ownerDb("user123", true);
      const validJobItemRef = owner.collection("users").doc("user123").collection("routineItems").doc("routine-job-1");
      await assertSucceeds(validJobItemRef.set(routineItemData("user123", "routine-job-1", { category: "job" })));

      const invalidCategoryRef = owner.collection("users").doc("user123").collection("routineItems").doc("routine-bad-cat");
      await assertFails(invalidCategoryRef.set(routineItemData("user123", "routine-bad-cat", { category: "unauthorized_category" })));

      const itemRef = owner.collection("users").doc("user123").collection("routineItems").doc("routine-item-1");
      await assertSucceeds(itemRef.set(routineItemData("user123", "routine-item-1", { onboardingProjectionId: "onboarding-initial-v1" })));
      await assertFails(itemRef.update({ onboardingProjectionId: "modified-projection-id" }));
    });

    it("accepts canonical eating routine template with mealSlot and rejects invalid mealSlot", async () => {
      const owner = ownerDb("user123", true);
      const mealRef = owner.collection("users").doc("user123").collection("routineItems").doc("routine-meal-1");
      await assertSucceeds(mealRef.set(routineItemData("user123", "routine-meal-1", {
        category: "eating",
        mealCategory: "breakfast",
        mealSlot: "breakfast",
      })));

      const invalidMealRef = owner.collection("users").doc("user123").collection("routineItems").doc("routine-meal-invalid");
      await assertFails(invalidMealRef.set(routineItemData("user123", "routine-meal-invalid", {
        category: "eating",
        mealCategory: "breakfast",
        mealSlot: 12345,
      })));
    });

    it("accepts routine template with source 'baseTimeline' and baseTimelineSection", async () => {
      const owner = ownerDb("user123", true);
      const baseTimelineItemRef = owner.collection("users").doc("user123").collection("routineItems").doc("routine-bt-1");
      await assertSucceeds(baseTimelineItemRef.set(routineItemData("user123", "routine-bt-1", {
        source: "baseTimeline",
        baseTimelineSection: "classes",
      })));

      const invalidSectionRef = owner.collection("users").doc("user123").collection("routineItems").doc("routine-bt-invalid");
      await assertFails(invalidSectionRef.set(routineItemData("user123", "routine-bt-invalid", {
        source: "baseTimeline",
        baseTimelineSection: 12345,
      })));
    });

    it("accepts bounded onboarding visual style metadata and rejects malformed values", async () => {
      const owner = ownerDb("user123", true);
      const styledRef = owner.collection("users").doc("user123").collection("routineItems").doc("routine-style-1");
      await assertSucceeds(styledRef.set(routineItemData("user123", "routine-style-1", {
        source: "onboarding",
        onboardingProjectionId: "onboarding-initial-v1",
        onboardingSourceItemId: "class-source-1",
        onboardingVisualStyleKey: "class:0",
      })));

      const invalidTypeRef = owner.collection("users").doc("user123").collection("routineItems").doc("routine-style-invalid-type");
      await assertFails(invalidTypeRef.set(routineItemData("user123", "routine-style-invalid-type", {
        onboardingVisualStyleKey: 0,
      })));

      const oversizedRef = owner.collection("users").doc("user123").collection("routineItems").doc("routine-style-oversized");
      await assertFails(oversizedRef.set(routineItemData("user123", "routine-style-oversized", {
        onboardingVisualStyleKey: "x".repeat(65),
      })));
    });

    it("validates routine occurrence action and enforces immutable occurrence fields", async () => {
      const owner = ownerDb("user123", true);
      const validOccRef = owner.collection("users").doc("user123").collection("routineHistory").doc("occ-valid");
      await assertSucceeds(validOccRef.set(occurrenceData("user123", "occ-valid", { action: "complete" })));

      const invalidActionRef = owner.collection("users").doc("user123").collection("routineHistory").doc("occ-invalid");
      await assertFails(invalidActionRef.set(occurrenceData("user123", "occ-invalid", { action: "invalid_action_name" })));

      await assertFails(validOccRef.update({ occurrenceDateKey: "2026-12-31" }));
    });

    it("enforces strict append-only constraints on routineEvents", async () => {
      const owner = ownerDb("user123", true);
      const eventRef = owner.collection("users").doc("user123").collection("routineEvents").doc("event-append-1");
      await assertSucceeds(eventRef.set(eventData("user123", "event-append-1")));

      await assertFails(eventRef.update({ eventType: "updated" }));
      await assertFails(eventRef.delete());
    });

    it("enforces projectionId matching, total cursor requirements, and monotonic progress", async () => {
      const owner = ownerDb("user123", true);
      const invalidProjIdRef = owner.collection("users").doc("user123").collection("routineProjections").doc("wrong-proj-id");
      await assertFails(invalidProjIdRef.set(projectionData("user123", { id: "wrong-proj-id" })));

      const projRef = owner.collection("users").doc("user123").collection("routineProjections").doc("onboarding-initial-v1");
      const projectedItemIds = [
        "routine-item-1",
        "routine-item-2",
        "routine-item-3",
        "routine-item-4",
        "routine-item-5",
      ];
      await assertSucceeds(projRef.set(projectionData("user123", {
        projectedItemIds,
        totalCount: 5,
        cursor: 2,
        status: "pending",
      })));

      // Transitioning status to completed when cursor (2) < totalCount (5) must fail
      await assertFails(projRef.update({ status: "completed", completedAt }));

      // Regressing cursor (from 2 to 1) must fail
      await assertFails(projRef.update({ cursor: 1 }));
    });
  });

  describe("Work Package E Remediation (Phase 4.6 Final Production Closure)", () => {
    describe("ISSUE-SEC-01 / PATH3-SEC-01: Wildcard Subcollection Catch-All Rule Bypasses Validation", () => {
      it("allows owner to write valid subcollection documents and rejects malformed or arbitrary keys", async () => {
        const owner = ownerDb("user123", true);

        // Valid tracker config doc
        const trackerRef = owner.collection("users").doc("user123").collection("trackers").doc("config");
        await assertSucceeds(trackerRef.set({
          id: "config",
          enabledTrackers: ["water", "sleep"],
          createdAt,
          updatedAt
        }));

        // Malformed tracker config with illegal key
        await assertFails(trackerRef.set({
          id: "config",
          enabledTrackers: ["water"],
          illegalInjection: true
        }));

        // Valid habit template doc
        const habitRef = owner.collection("users").doc("user123").collection("habitTemplates").doc("habit-1");
        await assertSucceeds(habitRef.set({
          id: "habit-1",
          title: "Morning Journaling",
          category: "mindfulness",
          targetDaysPerWeek: 5,
          createdAt,
          updatedAt
        }));

        // Malformed habit template with oversized title
        await assertFails(habitRef.set({
          id: "habit-1",
          title: "A".repeat(250),
          category: "mindfulness"
        }));

        // Valid money entry doc
        const moneyRef = owner.collection("users").doc("user123").collection("money").doc("goals").collection("items").doc("goal-1");
        await assertSucceeds(moneyRef.set({
          id: "goal-1",
          title: "Emergency Fund",
          targetAmount: 5000,
          currentAmount: 1000,
          createdAt,
          updatedAt
        }));

        // Malformed money entry doc
        await assertFails(moneyRef.set({
          id: "goal-1",
          unsupportedField: "malicious"
        }));

        // Valid coach preferences doc
        const coachPrefRef = owner.collection("users").doc("user123").collection("coach").doc("preferences").collection("main").doc("settings");
        await assertSucceeds(coachPrefRef.set({
          id: "settings",
          coachName: "Marcus",
          coachStyle: "direct",
          accountabilityMode: "daily",
          createdAt,
          updatedAt
        }));

        // Malformed coach preferences doc
        await assertFails(coachPrefRef.set({
          id: "settings",
          unknownKey: 12345
        }));
      });

      it("rejects cross-user subcollection writes", async () => {
        const otherUser = ownerDb("other_user", true);

        const trackerRef = otherUser.collection("users").doc("user123").collection("trackers").doc("config");
        await assertFails(trackerRef.set({
          id: "config",
          enabledTrackers: ["water"]
        }));

        const settingsRef = otherUser.collection("users").doc("user123").collection("settings").doc("appPreferences");
        await assertFails(settingsRef.set({
          id: "appPreferences",
          locale: "en_US"
        }));
      });
    });

    describe("ISSUE-SEC-02 / PATH3-SEC-02: Permissive Onboarding Collection Rule Allows Malformed Document Injection", () => {
      it("allows verified owner valid onboarding draft and bundle writes and rejects malformed documents", async () => {
        const owner = ownerDb("user123", true);

        // Valid onboarding draft
        const draftRef = owner.collection("users").doc("user123").collection("onboarding").doc("draft");
        await assertSucceeds(draftRef.set(onboardingDraftData()));

        // Malformed onboarding draft (invalid currentStep type and missing schemaVersion)
        await assertFails(draftRef.set({
          uid: "user123",
          currentStep: "not-a-number"
        }));

        // Malformed onboarding draft with illegal field injection
        await assertFails(draftRef.set({
          uid: "user123",
          schemaVersion: 1,
          currentStep: 0,
          stepCompleted: [],
          stepDirty: [],
          stepLoading: [],
          onboardingCompleted: false,
          welcomeSaved: true,
          patiencePledgeAccepted: true,
          badHabitsNotNow: true,
          badHabits: [],
          goodHabitsNotNow: true,
          goodHabits: [],
          identityGoals: [],
          lifeRole: {},
          bodyBasics: {},
          baseTimeline: {},
          coachSetup: {},
          notifications: {},
          injectedHackerField: "pwned"
        }));

        // Valid completion bundle
        const bundleRef = owner.collection("users").doc("user123").collection("onboarding").doc("completionBundle");
        await assertSucceeds(bundleRef.set(completionBundleData()));

        // Malformed completion bundle (onboardingCompleted = false)
        await assertFails(bundleRef.set({
          uid: "user123",
          schemaVersion: 1,
          onboardingCompleted: false,
          userProfilePatch: {}
        }));

        // Reject arbitrary unrecognized onboarding doc ID
        const malformedDocRef = owner.collection("users").doc("user123").collection("onboarding").doc("arbitraryDoc");
        await assertFails(malformedDocRef.set({
          uid: "user123",
          randomData: true
        }));
      });
    });

    describe("ISSUE-SEC-03 / PATH3-SEC-03: Root User Profile Document (/users/{uid}) Lacks Key & Field Length Rules", () => {
      it("enforces strict field length restrictions, required string formats, and immutable uid on /users/{uid}", async () => {
        const owner = ownerDb("user123", true);
        const userRef = owner.collection("users").doc("user123");

        // Valid user profile set
        await assertSucceeds(userRef.set({
          uid: "user123",
          email: "user@example.com",
          displayName: "Valid User Name",
          accountStatus: "active",
          coachName: "Coach Alex",
          coachStyle: "supportive",
          createdAt,
          updatedAt,
          schemaVersion: 1
        }));

        // Reject oversized displayName (> 200 chars)
        await assertFails(userRef.set({
          uid: "user123",
          email: "user@example.com",
          displayName: "X".repeat(250)
        }));

        // Reject oversized coachName (> 100 chars)
        await assertFails(userRef.set({
          uid: "user123",
          email: "user@example.com",
          coachName: "Y".repeat(150)
        }));

        // Reject unallowed key injection
        await assertFails(userRef.set({
          uid: "user123",
          email: "user@example.com",
          adminPrivileges: true
        }));

        // Reject mutating uid on update
        await assertFails(userRef.update({
          uid: "hacker_uid"
        }));

        // Reject mutating createdAt on update
        await assertFails(userRef.update({
          createdAt: new Date("2020-01-01T00:00:00.000Z")
        }));
      });
    });
  });
});

describe("Phase 4.6.4 canonical production contracts", () => {
  it("accepts root UserProfile create and valid owner update", async () => {
    const db = ownerDb();
    const ref = db.collection("users").doc("user123");
    await assertSucceeds(ref.set(userData()));
    await assertSucceeds(ref.update({ displayName: "Updated", updatedAt: completedAt }));
  });

  it("rejects cross-user profile access, immutable UID mutation, and unknown fields", async () => {
    const owner = ownerDb();
    const ref = owner.collection("users").doc("user123");
    await assertSucceeds(ref.set(userData()));
    await assertFails(ownerDb("other_user").collection("users").doc("user123").get());
    await assertFails(ref.update({ uid: "other_user", updatedAt: completedAt }));
    await assertFails(ref.update({ admin: true, updatedAt: completedAt }));
  });

  it("rejects full UserProfile at profile/main and accepts only profile settings there", async () => {
    const db = ownerDb();
    const ref = db.collection("users").doc("user123").collection("profile").doc("main");
    await assertFails(ref.set(userData()));
    await assertSucceeds(ref.set(profileSettingsData()));
    await assertFails(ref.set(profileSettingsData("user123", { email: "not-allowed@example.com" })));
  });

  it("accepts exact RegionLocalization and rejects schema drift", async () => {
    const db = ownerDb();
    const ref = db.collection("users").doc("user123").collection("settings").doc("regionLocalization");
    await assertSucceeds(ref.set(regionData()));
    await assertFails(ref.set(regionData("user123", { schemaVersion: 2 })));
    await assertFails(ref.set(regionData("user123", { source: "client_guessed" })));
    await assertFails(ref.set(regionData("user123", { unknown: true })));
  });

  it("accepts exact AppPreferences and rejects unrelated profile fields", async () => {
    const db = ownerDb();
    const ref = db.collection("users").doc("user123").collection("settings").doc("appPreferences");
    await assertSucceeds(ref.set(appPreferencesData()));
    await assertFails(ref.set(appPreferencesData("user123", { bio: "not a preference" })));
    await assertFails(ref.set(appPreferencesData("other_user")));
  });

  describe("schema-v2 CompletionBundle contract", () => {
    function bundleRef(db = ownerDb()) {
      return db.collection("users").doc("user123").collection("onboarding").doc("completionBundle");
    }

    it("keeps the canonical fixture in exact required-key and schema parity", () => {
      expect(Object.keys(completionBundleData()).sort()).toEqual(
        [...completionBundleRequiredKeys].sort(),
      );
      expect(completionBundleData().schemaVersion).toBe(2);
    });

    it("allows a valid schema-v2 create", async () => {
      await assertSucceeds(bundleRef().set(completionBundleData()));
    });

    it("allows a valid schema-v2 full overwrite for the same owner and run", async () => {
      const ref = bundleRef();
      await assertSucceeds(ref.set(completionBundleData()));
      await assertSucceeds(ref.set(completionBundleData("user123", {
        updatedAt: completedAt,
        warnings: ["schedule-adjusted"],
      })));
    });

    it("allows non-empty conflict, acceptance-ID, and unscheduled-suggestion metadata", async () => {
      await assertSucceeds(bundleRef().set(completionBundleData("user123", {
        conflictAcceptances: [completionBundleConflictAcceptanceData()],
        expectedAcceptanceIds: [canonicalAcceptanceId],
        unscheduledRoutineSuggestions: [unscheduledRoutineSuggestionData()],
      })));
    });

    it("allows unique expectedAcceptanceIds", async () => {
      await assertSucceeds(bundleRef().set(completionBundleData("user123", {
        expectedAcceptanceIds: [canonicalAcceptanceId, `ca_${"b".repeat(40)}`],
      })));
    });

    it("rejects duplicate expectedAcceptanceIds", async () => {
      await assertFails(bundleRef().set(completionBundleData("user123", {
        expectedAcceptanceIds: [canonicalAcceptanceId, canonicalAcceptanceId],
      })));
    });

    it("rejects schemaVersion 1", async () => {
      await assertFails(bundleRef().set(completionBundleData("user123", {
        schemaVersion: 1,
      })));
    });

    it.each([
      "runId",
      "conflictAcceptances",
      "expectedAcceptanceIds",
      "unscheduledRoutineSuggestions",
    ])("requires the schema-v2 %s field", async (field) => {
      const data = completionBundleData();
      delete data[field];
      await assertFails(bundleRef().set(data));
    });

    it("rejects an unknown extra top-level key", async () => {
      await assertFails(bundleRef().set(completionBundleData("user123", {
        arbitrary: true,
      })));
    });

    it("rejects malformed run IDs", async () => {
      await assertFails(bundleRef().set(completionBundleData("user123", {
        runId: "run-not-canonical",
      })));
    });

    it("rejects a bundle UID that differs from the owner path", async () => {
      await assertFails(bundleRef().set(completionBundleData("other-user")));
    });

    it("rejects malformed source fingerprints", async () => {
      await assertFails(bundleRef().set(completionBundleData("user123", {
        sourceFingerprint: "not-a-fingerprint",
      })));
    });

    it("rejects draftRevision below one", async () => {
      await assertFails(bundleRef().set(completionBundleData("user123", {
        draftRevision: 0,
      })));
    });

    it("rejects wrong top-level timestamp types", async () => {
      await assertFails(bundleRef().set(completionBundleData("user123", {
        createdAt: createdAt.toISOString(),
      })));
      await assertFails(bundleRef().set(completionBundleData("user123", {
        updatedAt: updatedAt.toISOString(),
      })));
    });

    it.each([
      ["conflictAcceptances", {}],
      ["expectedAcceptanceIds", {}],
      ["unscheduledRoutineSuggestions", {}],
    ])("rejects a wrong %s field type", async (field, value) => {
      await assertFails(bundleRef().set(completionBundleData("user123", {
        [field]: value,
      })));
    });
  });

  it("accepts canonical CompletionJob and rejects alternate uid/in_progress schema", async () => {
    const db = ownerDb();
    const ref = db.collection("users").doc("user123").collection("onboardingCompletionJobs").doc("current");
    await assertSucceeds(ref.set(onboardingJobData()));
    const alternate = onboardingJobData();
    delete alternate.ownerUid;
    alternate.uid = "user123";
    alternate.status = "in_progress";
    await assertFails(ref.set(alternate));
  });

  it("rejects invalid CompletionJob create stage, enum, unknown field, and skipped transition", async () => {
    const db = ownerDb();
    const ref = db.collection("users").doc("user123").collection("onboardingCompletionJobs").doc("current");
    await assertFails(ref.set(onboardingJobData("user123", { stage: "persistDraft" })));
    await assertFails(ref.set(onboardingJobData("user123", { status: "inProgress" })));
    await assertFails(ref.set(onboardingJobData("user123", { lastError: "raw exception" })));
    await assertSucceeds(ref.set(onboardingJobData()));
    await assertFails(ref.update({ stage: "verifyDraft", status: "running", updatedAt: completedAt }));
    await assertSucceeds(ref.update({
      stage: "validateInput",
      status: "running",
      stagesCompleted: { validateInput: true },
      updatedAt: completedAt,
    }));
    await assertSucceeds(ref.update({
      stage: "persistDraft",
      status: "running",
      stagesCompleted: { validateInput: true, persistDraft: true },
      updatedAt: completedAt,
    }));
  });

  it("rejects a completed draft whose verified steps are incomplete", async () => {
    const db = ownerDb();
    const ref = db.collection("users").doc("user123").collection("onboarding").doc("draft");
    await assertFails(ref.set(onboardingDraftData("user123", {
      currentStep: 14,
      onboardingCompleted: true,
    })));
    await assertSucceeds(ref.set(onboardingDraftData("user123", {
      currentStep: 14,
      stepCompleted: Array(15).fill(true),
      onboardingCompleted: true,
    })));
  });

  it("accepts only the canonical schema-v4 onboarding draft completion contract", async () => {
    const db = ownerDb();
    const ref = db.collection("users").doc("user123").collection("onboarding").doc("draft");
    await assertSucceeds(ref.set(onboardingDraftData()));
    await assertFails(ref.set(onboardingDraftData("user123", { schemaVersion: 2 })));
    await assertFails(ref.set(onboardingDraftData("user123", {
      stepCompletionContractVersions: Array(15).fill(0),
    })));
    await assertFails(ref.set(onboardingDraftData("user123", { timezoneId: "" })));
    const missingTimezone = onboardingDraftData();
    delete missingTimezone.timezoneId;
    await assertFails(ref.set(missingTimezone));
  });

  it("enforces all schema-v4 stepCompletionContractVersions edge cases", async () => {
    const db = ownerDb();
    const ref = db.collection("users").doc("user123").collection("onboarding").doc("draft");

    // valid schema-v4 draft — must succeed
    await assertSucceeds(ref.set(onboardingDraftData()));

    // schemaVersion = 3 — must be denied (only 4 is allowed)
    await assertFails(ref.set(onboardingDraftData("user123", { schemaVersion: 3 })));

    // schemaVersion = 2 — must be denied
    await assertFails(ref.set(onboardingDraftData("user123", { schemaVersion: 2 })));

    // missing stepCompletionContractVersions — must be denied
    const missingReceipts = onboardingDraftData();
    delete missingReceipts.stepCompletionContractVersions;
    await assertFails(ref.set(missingReceipts));

    // stepCompletionContractVersions length = 14 (too short) — must be denied
    await assertFails(ref.set(onboardingDraftData("user123", {
      stepCompletionContractVersions: Array(14).fill(1),
    })));

    // stepCompletionContractVersions length = 16 (too long) — must be denied
    await assertFails(ref.set(onboardingDraftData("user123", {
      stepCompletionContractVersions: Array(16).fill(1),
    })));

    // all versions = 0 — must be denied
    await assertFails(ref.set(onboardingDraftData("user123", {
      stepCompletionContractVersions: Array(15).fill(0),
    })));

    // one version = 0 (contract version 0 is unsupported) — must be denied
    await assertFails(ref.set(onboardingDraftData("user123", {
      stepCompletionContractVersions: [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    })));

    // one version = 2 (unsupported; only v1 is the current supported contract) — must be denied
    await assertFails(ref.set(onboardingDraftData("user123", {
      stepCompletionContractVersions: [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    })));

    // wrong UID on ref — must be denied
    const wrongUidRef = ownerDb("other_user").collection("users").doc("user123").collection("onboarding").doc("draft");
    await assertFails(wrongUidRef.set(onboardingDraftData("user123")));

    // malformed stepCompleted length (14 instead of 15) — must be denied
    await assertFails(ref.set(onboardingDraftData("user123", {
      stepCompleted: Array(14).fill(false),
    })));

    // malformed stepDirty length (16 instead of 15) — must be denied
    await assertFails(ref.set(onboardingDraftData("user123", {
      stepDirty: Array(16).fill(false),
    })));

    // malformed stepLoading length (14 instead of 15) — must be denied
    await assertFails(ref.set(onboardingDraftData("user123", {
      stepLoading: Array(14).fill(false),
    })));
  });

  it("rejects source conversion while allowing content repair for onboarding Routine", async () => {
    const db = ownerDb();
    const ref = db.collection("users").doc("user123").collection("routineItems").doc("routine-item-1");
    await assertSucceeds(ref.set(routineItemData()));
    await assertFails(ref.update({
      source: "onboarding",
      onboardingProjectionId: "onboarding-initial-v1",
      onboardingSourceItemId: "source-1",
      updatedAt: completedAt,
    }));

    const projected = db.collection("users").doc("user123").collection("routineItems").doc("projected-1");
    await assertSucceeds(projected.set(routineItemData("user123", "projected-1", {
      source: "onboarding",
      onboardingProjectionId: "onboarding-initial-v1",
      onboardingSourceItemId: "source-1",
    })));
    await assertSucceeds(projected.update({ title: "Repaired title", updatedAt: completedAt }));
  });

  it("rejects wrong-source History conversion and accepts exact onboarding History", async () => {
    const db = ownerDb();
    const collection = db.collection("users").doc("user123").collection("routineHistory");
    const manualRef = collection.doc("manual-history");
    await assertSucceeds(manualRef.set(occurrenceData("user123", "manual-history")));
    await assertFails(manualRef.update({
      source: "onboarding",
      action: "repair",
      onboardingProjectionId: "onboarding-initial-v1",
      onboardingSourceItemId: "source-1",
      sourceFingerprint: fingerprint,
      updatedAt: completedAt,
    }));

    const projectedRef = collection.doc("projected-history");
    const projectedHistory = occurrenceData("user123", "projected-history", {
      status: "active",
      source: "onboarding",
      action: "project",
      operationKey: "onboarding_history_1",
      onboardingProjectionId: "onboarding-initial-v1",
      onboardingSourceItemId: "source-1",
      sourceFingerprint: fingerprint,
    });
    delete projectedHistory.movedToDateKey;
    delete projectedHistory.movedStartMinute;
    delete projectedHistory.movedEndMinute;
    await assertSucceeds(projectedRef.set(projectedHistory));
  });

  it("allows canonical prior-projection History repair and rejects identity drift", async () => {
    const db = ownerDb();
    const collection = db.collection("users").doc("user123").collection("routineHistory");
    const ref = collection.doc("projected-history-repair");
    const priorProjection = `onboarding-run_${"a".repeat(40)}-v1`;
    const currentProjection = `onboarding-run_${"b".repeat(40)}-v1`;
    const priorFingerprint = "c".repeat(64);
    const currentFingerprint = "d".repeat(64);
    const original = occurrenceData("user123", "projected-history-repair", {
      status: "active",
      source: "onboarding",
      action: "project",
      operationKey: "onboarding_history_prior",
      onboardingProjectionId: priorProjection,
      onboardingSourceItemId: "source-1",
      sourceFingerprint: priorFingerprint,
    });
    delete original.movedToDateKey;
    delete original.movedStartMinute;
    delete original.movedEndMinute;
    await assertSucceeds(ref.set(original));

    await assertSucceeds(ref.update({
      action: "repair",
      operationKey: "onboarding_history_current_repair",
      onboardingProjectionId: currentProjection,
      sourceFingerprint: currentFingerprint,
      updatedAt: completedAt,
    }));

    await assertFails(ref.update({
      onboardingProjectionId: "invalid-projection",
      sourceFingerprint: "e".repeat(64),
      updatedAt: updatedAt,
    }));
    await assertFails(ref.update({
      onboardingProjectionId: `onboarding-run_${"e".repeat(40)}-v1`,
      onboardingSourceItemId: "different-source",
      sourceFingerprint: "f".repeat(64),
      updatedAt: updatedAt,
    }));
    await assertFails(ref.update({
      onboardingProjectionId: `onboarding-run_${"e".repeat(40)}-v1`,
      sourceFingerprint: "not-a-canonical-fingerprint",
      updatedAt: updatedAt,
    }));
    await assertFails(ref.update({
      routineItemId: "different-routine",
      onboardingProjectionId: `onboarding-run_${"e".repeat(40)}-v1`,
      sourceFingerprint: "f".repeat(64),
      updatedAt: updatedAt,
    }));
  });

  it("rejects wrong-source Habit conversion and accepts exact onboarding Habit", async () => {
    const db = ownerDb();
    const collection = db.collection("users").doc("user123").collection("habitSystems");
    const userRef = collection.doc("user-habit");
    await assertSucceeds(userRef.set(habitSystemData("user123", "user-habit")));
    await assertFails(userRef.update({
      source: "onboarding",
      onboardingSourceId: "source-1",
      onboardingProjectionId: "projection-1",
      sourceFingerprint: fingerprint,
      version: 2,
      updatedAt: completedAt,
    }));

    await assertSucceeds(collection.doc("onboarding-habit").set(habitSystemData("user123", "onboarding-habit", {
      source: "onboarding",
      onboardingSourceId: "source-1",
      onboardingProjectionId: "projection-1",
      sourceFingerprint: fingerprint,
    })));
  });

  it("allows canonical onboarding Habit fingerprint repair and rejects identity spoofing", async () => {
    const db = ownerDb();
    const ref = db.collection("users").doc("user123").collection("habitSystems").doc("onboarding-habit");
    const projectionId = "proj_onboard_hs_v1_user123";
    await assertSucceeds(ref.set(habitSystemData("user123", "onboarding-habit", {
      source: "onboarding",
      onboardingSourceId: "source-1",
      onboardingProjectionId: projectionId,
      sourceFingerprint: "b".repeat(64),
    })));

    await assertSucceeds(ref.update({
      sourceFingerprint: "c".repeat(64),
      version: 2,
      updatedAt: completedAt,
    }));
    await assertFails(ref.update({
      onboardingSourceId: "different-source",
      sourceFingerprint: "d".repeat(64),
      version: 3,
      updatedAt,
    }));
    await assertFails(ref.update({
      onboardingProjectionId: "different-projection",
      sourceFingerprint: "d".repeat(64),
      version: 3,
      updatedAt,
    }));
    await assertFails(ref.update({
      sourceFingerprint: "not-a-canonical-fingerprint",
      version: 3,
      updatedAt,
    }));
  });

  describe("Phase 4.6.7 production onboarding lifecycle paths", () => {
    it("rejects unverified and unauthenticated completion access", async () => {
      const unverified = ownerDb("user123", false);
      const unauthenticated = testEnv.unauthenticatedContext().firestore();
      const runPath = "users/user123/onboardingRuns/run-001";
      const pointerPath = "users/user123/onboarding/currentRun";

      await assertFails(unverified.doc(runPath).set(onboardingRunData()));
      await assertFails(unverified.doc(pointerPath).get());
      await assertFails(unauthenticated.doc(runPath).get());
      await assertFails(unauthenticated.doc(pointerPath).set(currentRunData()));
    });

    it("allows canonical failure metadata while retryableFailure", async () => {
      const db = ownerDb();
      const ref = db.collection("users").doc("user123").collection("onboardingRuns").doc("run-001");

      await assertSucceeds(ref.set(onboardingRunData()));
      await assertSucceeds(ref.set(failedOnboardingRunData()));
    });

    it("allows retryableFailure to return to running after failure keys are removed", async () => {
      const db = ownerDb();
      const ref = db.collection("users").doc("user123").collection("onboardingRuns").doc("run-001");

      await assertSucceeds(ref.set(onboardingRunData()));
      await assertSucceeds(ref.set(failedOnboardingRunData()));
      await assertSucceeds(ref.set(onboardingRunData("user123", "run-001", {
        retryCount: 1,
        updatedAt: completedAt,
      })));
    });

    it("rejects running retry payloads retaining any canonical failure-only key", async () => {
      const staleFailureCases = [
        { failureCode: "persist_bundle_failed" },
        { safeCauseType: "FirebaseException" },
      ];

      for (let index = 0; index < staleFailureCases.length; index++) {
        const runId = `stale-run-${index}`;
        const db = ownerDb();
        const ref = db.collection("users").doc("user123").collection("onboardingRuns").doc(runId);
        await testEnv.withSecurityRulesDisabled(async (context) => {
          const adminRef = context.firestore().collection("users").doc("user123").collection("onboardingRuns").doc(runId);
          await adminRef.set(failedOnboardingRunData("user123", runId));
        });

        await assertFails(ref.set(onboardingRunData("user123", runId, {
          retryCount: 1,
          updatedAt: completedAt,
          ...staleFailureCases[index],
        })));
      }
    });

    it("allows an atomic retry activation when both run and currentRun are valid", async () => {
      const db = ownerDb();
      const runRef = db.collection("users").doc("user123").collection("onboardingRuns").doc("run-001");
      const pointerRef = db.collection("users").doc("user123").collection("onboarding").doc("currentRun");
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const admin = context.firestore();
        await admin.doc("users/user123/onboarding/draft").set(completedOnboardingDraftData());
        await admin.doc(runRef.path).set(failedOnboardingRunData());
        await admin.doc(pointerRef.path).set(currentRunData());
      });

      const batch = db.batch();
      batch.set(runRef, onboardingRunData("user123", "run-001", {
        retryCount: 1,
        updatedAt: completedAt,
      }));
      batch.set(pointerRef, currentRunData());
      await assertSucceeds(batch.commit());

      expect((await runRef.get()).data().status).toBe("running");
      expect((await pointerRef.get()).exists).toBe(true);
    });

    it("rejects the whole activation batch when the running run retains failure metadata", async () => {
      const db = ownerDb();
      const runRef = db.collection("users").doc("user123").collection("onboardingRuns").doc("run-001");
      const pointerRef = db.collection("users").doc("user123").collection("onboarding").doc("currentRun");
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminRef = context.firestore().collection("users").doc("user123").collection("onboardingRuns").doc("run-001");
        await adminRef.set(failedOnboardingRunData());
      });

      const batch = db.batch();
      batch.set(runRef, onboardingRunData("user123", "run-001", {
        retryCount: 1,
        updatedAt: completedAt,
        failureCode: "persist_bundle_failed",
      }));
      batch.set(pointerRef, currentRunData());
      await assertFails(batch.commit());

      expect((await runRef.get()).data().status).toBe("retryableFailure");
      expect((await pointerRef.get()).exists).toBe(false);
    });

    it("allows the verified owner to create, read, and advance a schema-v3 onboarding run", async () => {
      const db = ownerDb();
      const ref = db.collection("users").doc("user123").collection("onboardingRuns").doc("run-001");

      await assertSucceeds(ref.set(onboardingRunData()));
      await assertSucceeds(ref.get());
      await assertSucceeds(ref.update({
        stage: "validateInput",
        stagesCompleted: { validateInput: true },
        updatedAt: completedAt,
      }));
      await assertSucceeds(ref.update({
        stage: "persistDraft",
        stagesCompleted: { validateInput: true, persistDraft: true },
        updatedAt: completedAt,
      }));
    });

    it("requires every persisted run stage to carry its complete true-valued prefix", async () => {
      const db = ownerDb();
      const ref = db.collection("users").doc("user123").collection("onboardingRuns").doc("run-prefix");
      await assertSucceeds(ref.set(onboardingRunData("user123", "run-prefix")));

      await assertSucceeds(ref.update({
        stage: "validateInput",
        stagesCompleted: { validateInput: true },
        updatedAt: completedAt,
      }));

      await assertFails(ref.update({
        stage: "persistDraft",
        stagesCompleted: { validateInput: true },
        updatedAt: completedAt,
      }));

      await assertSucceeds(ref.update({
        stage: "persistDraft",
        stagesCompleted: { validateInput: true, persistDraft: true },
        updatedAt: completedAt,
      }));

      await assertFails(ref.update({
        stage: "verifyDraft",
        stagesCompleted: { validateInput: true, persistDraft: true },
        updatedAt: completedAt,
      }));
    });

    it("accepts the exact durable onboarding stage order one checkpoint at a time", async () => {
      const db = ownerDb();
      const runId = "run-exact-stage-order";
      const ref = db.collection("users").doc("user123").collection("onboardingRuns").doc(runId);
      const stages = [
        "validateInput", "persistDraft", "verifyDraft", "persistBundle", "verifyBundle",
        "reconcileRoutines", "verifyRoutines", "projectRoutineHistory", "verifyRoutineHistory",
        "reconcileHabitSystems", "verifyHabitSystems", "reloadControllers", "verifyFrontendState",
        "finalizeProfile",
      ];
      await assertSucceeds(ref.set(onboardingRunData("user123", runId)));
      const completed = {};
      for (const stage of stages) {
        completed[stage] = true;
        await assertSucceeds(ref.update({
          stage,
          stagesCompleted: { ...completed },
          updatedAt: completedAt,
        }));
      }
    });

    it("regression A: rejects an early-to-late jump while real draft and bundle writes advance sequentially", async () => {
      const db = ownerDb();
      const draftRef = db.doc("users/user123/onboarding/draft");
      const bundleRef = db.doc("users/user123/onboarding/completionBundle");
      const runRef = db.doc(`users/user123/onboardingRuns/${verifiableRunId}`);
      const pointerRef = db.doc("users/user123/onboarding/currentRun");

      const activation = db.batch();
      activation.set(draftRef, completedOnboardingDraftData());
      activation.set(runRef, onboardingRunData("user123", verifiableRunId));
      activation.set(pointerRef, currentRunData("user123", verifiableRunId));
      await assertSucceeds(activation.commit());

      await assertSucceeds(runRef.update({
        stage: "validateInput",
        stagesCompleted: { validateInput: true },
        updatedAt: completedAt,
      }));

      // Old bug A issued the equivalent persisted early -> later-stage jump.
      await assertFails(runRef.update({
        stage: "persistBundle",
        stagesCompleted: {
          validateInput: true,
          persistDraft: true,
          verifyDraft: true,
          persistBundle: true,
        },
        updatedAt: completedAt,
      }));

      await assertSucceeds(draftRef.set(completedOnboardingDraftData("user123", {
        updatedAt: completedAt,
      })));
      await assertSucceeds(runRef.update({
        stage: "persistDraft",
        stagesCompleted: { validateInput: true, persistDraft: true },
        updatedAt: completedAt,
      }));
      await assertSucceeds(runRef.update({
        stage: "verifyDraft",
        stagesCompleted: {
          validateInput: true,
          persistDraft: true,
          verifyDraft: true,
        },
        updatedAt: completedAt,
      }));
      await assertSucceeds(bundleRef.set(completionBundleData("user123", {
        runId: verifiableRunId,
        updatedAt: completedAt,
      })));
      await assertSucceeds(runRef.update({
        stage: "persistBundle",
        stagesCompleted: {
          validateInput: true,
          persistDraft: true,
          verifyDraft: true,
          persistBundle: true,
        },
        updatedAt: completedAt,
      }));

      expect((await draftRef.get()).data().onboardingCompleted).toBe(true);
      expect((await bundleRef.get()).data().runId).toBe(verifiableRunId);
      expect((await runRef.get()).data().stage).toBe("persistBundle");
    });

    it("resumes from an intermediate durable bundle stage in a fresh authenticated context", async () => {
      const runPath = `users/user123/onboardingRuns/${verifiableRunId}`;
      const draftPath = "users/user123/onboarding/draft";
      const bundlePath = "users/user123/onboarding/completionBundle";
      const pointerPath = "users/user123/onboarding/currentRun";
      const durablePrefix = {
        validateInput: true,
        persistDraft: true,
        verifyDraft: true,
        persistBundle: true,
      };

      await testEnv.withSecurityRulesDisabled(async (context) => {
        const admin = context.firestore();
        await admin.doc(draftPath).set(completedOnboardingDraftData());
        await admin.doc(bundlePath).set(completionBundleData("user123", {
          runId: verifiableRunId,
        }));
        await admin.doc(runPath).set(onboardingRunData("user123", verifiableRunId, {
          stage: "persistBundle",
          stagesCompleted: durablePrefix,
        }));
        await admin.doc(pointerPath).set(currentRunData("user123", verifiableRunId));
      });

      const resumedClient = ownerDb();
      const resumedRun = resumedClient.doc(runPath);
      expect((await resumedRun.get()).data().stage).toBe("persistBundle");
      await assertSucceeds(resumedClient.doc(bundlePath).get());
      await assertSucceeds(resumedRun.update({
        stage: "verifyBundle",
        stagesCompleted: { ...durablePrefix, verifyBundle: true },
        updatedAt: completedAt,
      }));
      expect((await resumedRun.get()).data().stage).toBe("verifyBundle");
    });

    it("allows production-sized late-stage checkpoint and failure accounting writes", async () => {
      const db = ownerDb();
      const ref = db.collection("users").doc("user123").collection("onboardingRuns").doc("run-habit-stage");
      const routineIds = Array.from({ length: 53 }, (_, index) => `routine-${index}`);
      const historyIds = Array.from({ length: 53 }, (_, index) => `history-${index}`);
      const acceptanceIds = Array.from({ length: 17 }, (_, index) => `acceptance-${index}`);
      const habitIds = Array.from({ length: 3 }, (_, index) => `habit-${index}`);
      const stagesBefore = {
        validateInput: true,
        persistDraft: true,
        verifyDraft: true,
        persistBundle: true,
        verifyBundle: true,
        reconcileRoutines: true,
        verifyRoutines: true,
        projectRoutineHistory: true,
        verifyRoutineHistory: true,
        reconcileHabitSystems: true,
        verifyHabitSystems: true,
      };
      const running = onboardingRunData("user123", "run-habit-stage", {
        stage: "reloadControllers",
        stagesCompleted: {
          ...stagesBefore,
        },
        expectedRoutineIds: routineIds,
        repairedRoutineIds: routineIds,
        expectedHistoryIds: historyIds,
        repairedHistoryIds: historyIds,
        expectedAcceptanceIds: acceptanceIds,
        appliedAcceptanceIds: acceptanceIds,
        expectedHabitIds: habitIds,
        repairedHabitIds: habitIds,
      });
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().doc(ref.path).set(running);
      });

      await assertSucceeds(ref.set({
        ...running,
        stagesCompleted: {
          ...stagesBefore,
          reloadControllers: true,
        },
        updatedAt: completedAt,
      }));

      await assertSucceeds(ref.set({
        ...running,
        stage: "verifyFrontendState",
        stagesCompleted: {
          ...stagesBefore,
          reloadControllers: true,
          verifyFrontendState: true,
        },
        updatedAt: completedAt,
      }));

      const verifiedFrontend = {
        ...running,
        stage: "verifyFrontendState",
        stagesCompleted: {
          ...stagesBefore,
          reloadControllers: true,
          verifyFrontendState: true,
        },
      };
      await assertSucceeds(ref.set({
        ...verifiedFrontend,
        status: "retryableFailure",
        retryCount: 1,
        failureCode: "frontend_state_verification_failed",
        failureStage: "verifyFrontendState",
        retryable: true,
        publicMessageKey: "error_habit_projection_failed",
        diagnosticCategory: "habit_projection_failed",
        safeCauseType: "HabitSystemProjectionFailureException",
        failedEntityIds: habitIds,
        failureOccurredAt: completedAt,
        updatedAt: completedAt,
      }));
    });

    it("rejects cross-owner onboarding-run access and owner or job-id spoofing", async () => {
      const other = ownerDb("other_user");
      const crossRef = other.collection("users").doc("user123").collection("onboardingRuns").doc("run-001");
      await assertFails(crossRef.get());
      await assertFails(crossRef.set(onboardingRunData()));

      const owner = ownerDb();
      const ref = owner.collection("users").doc("user123").collection("onboardingRuns").doc("run-001");
      await assertFails(ref.set(onboardingRunData("other_user")));
      await assertFails(ref.set(onboardingRunData("user123", "different-run")));
    });

    it("rejects malformed, skipped, regressed, and post-completion onboarding-run transitions", async () => {
      const db = ownerDb();
      const ref = db.collection("users").doc("user123").collection("onboardingRuns").doc("run-001");
      await assertFails(ref.set(onboardingRunData("user123", "run-001", { schemaVersion: 2 })));
      await assertFails(ref.set(onboardingRunData("user123", "run-001", { unexpected: true })));
      await assertSucceeds(ref.set(onboardingRunData()));
      await assertFails(ref.update({ stage: "verifyDraft", updatedAt: completedAt }));
      await assertFails(ref.update({ retryCount: -1, updatedAt: completedAt }));

      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminRef = context.firestore().collection("users").doc("user123").collection("onboardingRuns").doc("completed-run");
        await adminRef.set(onboardingRunData("user123", "completed-run", {
          stage: "completed",
          status: "completed",
          stagesCompleted: {
            validateInput: true,
            persistDraft: true,
            verifyDraft: true,
            persistBundle: true,
            verifyBundle: true,
            reconcileRoutines: true,
            verifyRoutines: true,
            projectRoutineHistory: true,
            verifyRoutineHistory: true,
            reconcileHabitSystems: true,
            verifyHabitSystems: true,
            reloadControllers: true,
            verifyFrontendState: true,
            finalizeProfile: true,
          },
          completedAt,
        }));
      });
      const completedRef = db.collection("users").doc("user123").collection("onboardingRuns").doc("completed-run");
      await assertFails(completedRef.update({ retryCount: 1, updatedAt: completedAt }));
    });

    it("allows no pointer to create a server-verifiable fresh run", async () => {
      const db = ownerDb();
      const draftRef = db.doc("users/user123/onboarding/draft");
      const runRef = db.doc(`users/user123/onboardingRuns/${verifiableRunId}`);
      const pointerRef = db.doc("users/user123/onboarding/currentRun");
      const batch = db.batch();
      batch.set(draftRef, completedOnboardingDraftData());
      batch.set(runRef, onboardingRunData("user123", verifiableRunId));
      batch.set(pointerRef, currentRunData("user123", verifiableRunId));
      await assertSucceeds(batch.commit());
      await assertSucceeds(pointerRef.get());
    });

    it("regression B: failed Run A plus a changed authoritative draft atomically creates Run B", async () => {
      const db = ownerDb();
      const draftRef = db.doc("users/user123/onboarding/draft");
      const priorRunRef = db.doc("users/user123/onboardingRuns/run-001");
      const replacementRunRef = db.doc(`users/user123/onboardingRuns/${replacementRunId}`);
      const pointerRef = db.doc("users/user123/onboarding/currentRun");
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const admin = context.firestore();
        await admin.doc(draftRef.path).set(completedOnboardingDraftData());
        await admin.doc(priorRunRef.path).set(failedOnboardingRunData());
        await admin.doc(pointerRef.path).set(currentRunData());
      });

      // Old bug B rejected this legitimate replacement of a failed run after
      // the user edited onboarding and produced a new authoritative revision.
      const batch = db.batch();
      batch.set(draftRef, completedOnboardingDraftData("user123", {
        revision: 8,
        sourceFingerprint: replacementFingerprint,
        updatedAt: completedAt,
      }));
      batch.set(replacementRunRef, onboardingRunData("user123", replacementRunId, {
        draftRevision: 8,
        sourceFingerprint: replacementFingerprint,
        updatedAt: completedAt,
      }));
      batch.set(pointerRef, currentRunData("user123", replacementRunId, {
        draftRevision: 8,
        sourceFingerprint: replacementFingerprint,
        updatedAt: completedAt,
      }));
      await assertSucceeds(batch.commit());

      expect((await pointerRef.get()).data().currentRunId).toBe(replacementRunId);
      expect((await priorRunRef.get()).data().status).toBe("retryableFailure");
    });

    it("makes a duplicate replacement safe and rejects stale A reclaiming B", async () => {
      const db = ownerDb();
      const draftRef = db.doc("users/user123/onboarding/draft");
      const priorRunRef = db.doc("users/user123/onboardingRuns/run-001");
      const replacementRunRef = db.doc(`users/user123/onboardingRuns/${replacementRunId}`);
      const pointerRef = db.doc("users/user123/onboarding/currentRun");
      const replacementDraft = completedOnboardingDraftData("user123", {
        revision: 8,
        sourceFingerprint: replacementFingerprint,
        updatedAt: completedAt,
      });
      const replacementRun = onboardingRunData("user123", replacementRunId, {
        draftRevision: 8,
        sourceFingerprint: replacementFingerprint,
        updatedAt: completedAt,
      });
      const replacementPointer = currentRunData("user123", replacementRunId, {
        draftRevision: 8,
        sourceFingerprint: replacementFingerprint,
        updatedAt: completedAt,
      });
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const admin = context.firestore();
        await admin.doc(draftRef.path).set(replacementDraft);
        await admin.doc(priorRunRef.path).set(failedOnboardingRunData());
        await admin.doc(replacementRunRef.path).set(replacementRun);
        await admin.doc(pointerRef.path).set(replacementPointer);
      });

      const duplicate = db.batch();
      duplicate.set(draftRef, replacementDraft);
      duplicate.set(replacementRunRef, replacementRun);
      duplicate.set(pointerRef, replacementPointer);
      await assertSucceeds(duplicate.commit());

      const stale = db.batch();
      stale.set(priorRunRef, onboardingRunData("user123", "run-001", {
        retryCount: 1,
        updatedAt: completedAt,
      }));
      stale.set(pointerRef, currentRunData());
      await assertFails(stale.commit());
      expect((await pointerRef.get()).data().currentRunId).toBe(replacementRunId);
    });

    it("rejects active or completed replacement, arbitrary ids, and owner mismatch", async () => {
      const cases = [
        { priorStatus: "running", pointerStatus: "active" },
        { priorStatus: "completed", pointerStatus: "completed" },
      ];
      for (let index = 0; index < cases.length; index++) {
        const uid = `replacement-state-${index}`;
        const db = ownerDb(uid);
        const draftRef = db.doc(`users/${uid}/onboarding/draft`);
        const priorRunRef = db.doc(`users/${uid}/onboardingRuns/run-001`);
        const replacementRunRef = db.doc(`users/${uid}/onboardingRuns/${replacementRunId}`);
        const pointerRef = db.doc(`users/${uid}/onboarding/currentRun`);
        await testEnv.withSecurityRulesDisabled(async (context) => {
          const admin = context.firestore();
          await admin.doc(draftRef.path).set(completedOnboardingDraftData(uid));
          await admin.doc(priorRunRef.path).set(onboardingRunData(uid, "run-001", {
            status: cases[index].priorStatus,
            ...(cases[index].priorStatus === "completed" ? {
              stage: "completed",
              stagesCompleted: { finalizeProfile: true },
              completedAt,
            } : {}),
          }));
          await admin.doc(pointerRef.path).set(currentRunData(uid, "run-001", {
            status: cases[index].pointerStatus,
          }));
        });
        const batch = db.batch();
        batch.set(draftRef, completedOnboardingDraftData(uid, {
          revision: 8,
          sourceFingerprint: replacementFingerprint,
          updatedAt: completedAt,
        }));
        batch.set(replacementRunRef, onboardingRunData(uid, replacementRunId, {
          draftRevision: 8,
          sourceFingerprint: replacementFingerprint,
          updatedAt: completedAt,
        }));
        batch.set(pointerRef, currentRunData(uid, replacementRunId, {
          draftRevision: 8,
          sourceFingerprint: replacementFingerprint,
          updatedAt: completedAt,
        }));
        await assertFails(batch.commit());
      }

      const arbitraryUid = "replacement-arbitrary";
      const arbitraryDb = ownerDb(arbitraryUid);
      const arbitraryDraftRef = arbitraryDb.doc(`users/${arbitraryUid}/onboarding/draft`);
      const arbitraryPriorRef = arbitraryDb.doc(`users/${arbitraryUid}/onboardingRuns/run-001`);
      const arbitraryCandidateId = `run_${"e".repeat(64)}`;
      const arbitraryCandidateRef = arbitraryDb.doc(
        `users/${arbitraryUid}/onboardingRuns/${arbitraryCandidateId}`,
      );
      const arbitraryPointerRef = arbitraryDb.doc(`users/${arbitraryUid}/onboarding/currentRun`);
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const admin = context.firestore();
        await admin.doc(arbitraryDraftRef.path).set(completedOnboardingDraftData(arbitraryUid));
        await admin.doc(arbitraryPriorRef.path).set(failedOnboardingRunData(arbitraryUid));
        await admin.doc(arbitraryPointerRef.path).set(currentRunData(arbitraryUid));
      });
      const arbitrary = arbitraryDb.batch();
      arbitrary.set(arbitraryDraftRef, completedOnboardingDraftData(arbitraryUid, {
        revision: 8,
        sourceFingerprint: replacementFingerprint,
        updatedAt: completedAt,
      }));
      arbitrary.set(arbitraryCandidateRef, onboardingRunData(
        arbitraryUid,
        arbitraryCandidateId,
        {
          draftRevision: 8,
          sourceFingerprint: replacementFingerprint,
          updatedAt: completedAt,
        },
      ));
      arbitrary.set(arbitraryPointerRef, currentRunData(
        arbitraryUid,
        arbitraryCandidateId,
        {
          draftRevision: 8,
          sourceFingerprint: replacementFingerprint,
          updatedAt: completedAt,
        },
      ));
      await assertFails(arbitrary.commit());

      const owner = ownerDb();
      const ownerMismatchRef = owner.doc("users/user123/onboarding/currentRun");
      await assertFails(ownerMismatchRef.set(currentRunData("other-user", replacementRunId, {
        sourceFingerprint: replacementFingerprint,
        draftRevision: 8,
      })));
    });

    it("rejects replacement run fingerprint and revision mismatches", async () => {
      for (const mismatch of ["fingerprint", "revision"]) {
        const uid = `replacement-${mismatch}`;
        const db = ownerDb(uid);
        const draftRef = db.doc(`users/${uid}/onboarding/draft`);
        const priorRunRef = db.doc(`users/${uid}/onboardingRuns/run-001`);
        const replacementRunRef = db.doc(`users/${uid}/onboardingRuns/${replacementRunId}`);
        const pointerRef = db.doc(`users/${uid}/onboarding/currentRun`);
        await testEnv.withSecurityRulesDisabled(async (context) => {
          const admin = context.firestore();
          await admin.doc(draftRef.path).set(completedOnboardingDraftData(uid));
          await admin.doc(priorRunRef.path).set(failedOnboardingRunData(uid));
          await admin.doc(pointerRef.path).set(currentRunData(uid));
        });
        const batch = db.batch();
        batch.set(draftRef, completedOnboardingDraftData(uid, {
          revision: 8,
          sourceFingerprint: replacementFingerprint,
          updatedAt: completedAt,
        }));
        batch.set(replacementRunRef, onboardingRunData(uid, replacementRunId, {
          draftRevision: mismatch === "revision" ? 9 : 8,
          sourceFingerprint: mismatch === "fingerprint" ? "e".repeat(64) : replacementFingerprint,
          updatedAt: completedAt,
        }));
        batch.set(pointerRef, currentRunData(uid, replacementRunId, {
          draftRevision: 8,
          sourceFingerprint: replacementFingerprint,
          updatedAt: completedAt,
        }));
        await assertFails(batch.commit());
      }
    });

    it("allows only an atomic profile + run + currentRun completion boundary", async () => {
      const db = ownerDb();
      const profileRef = db.collection("users").doc("user123");
      const runRef = profileRef.collection("onboardingRuns").doc("run-001");
      const pointerRef = profileRef.collection("onboarding").doc("currentRun");
      const stages = {
        validateInput: true,
        persistDraft: true,
        verifyDraft: true,
        persistBundle: true,
        verifyBundle: true,
        reconcileRoutines: true,
        verifyRoutines: true,
        projectRoutineHistory: true,
        verifyRoutineHistory: true,
        reconcileHabitSystems: true,
        verifyHabitSystems: true,
        reloadControllers: true,
        verifyFrontendState: true,
      };
      const activeRun = onboardingRunData("user123", "run-001", {
        stage: "finalizeProfile",
        status: "running",
        stagesCompleted: stages,
      });
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const admin = context.firestore();
        await admin.doc(profileRef.path).set(userData());
        await admin.doc("users/user123/onboarding/draft").set(completedOnboardingDraftData());
        await admin.doc(runRef.path).set(activeRun);
        await admin.doc(pointerRef.path).set(currentRunData());
      });
      const completedProfile = userData("user123", {
        onboardingInputCompleted: true,
        onboardingProjectionStatus: "completed",
        onboardingCompleted: true,
        updatedAt: completedAt,
      });
      const completedRun = {
        ...activeRun,
        stage: "completed",
        status: "completed",
        stagesCompleted: { ...stages, finalizeProfile: true },
        updatedAt: completedAt,
        completedAt,
      };
      const completedPointer = currentRunData("user123", "run-001", {
        status: "completed",
        updatedAt: completedAt,
      });

      const incompleteBatch = db.batch();
      incompleteBatch.set(runRef, completedRun);
      incompleteBatch.set(pointerRef, completedPointer);
      await assertFails(incompleteBatch.commit());
      expect((await runRef.get()).data().status).toBe("running");
      expect((await pointerRef.get()).data().status).toBe("active");

      const terminalBatch = db.batch();
      terminalBatch.set(profileRef, completedProfile);
      terminalBatch.set(runRef, completedRun);
      terminalBatch.set(pointerRef, completedPointer);
      await assertSucceeds(terminalBatch.commit());
      expect((await profileRef.get()).data().onboardingCompleted).toBe(true);
      expect((await runRef.get()).data().status).toBe("completed");
      expect((await pointerRef.get()).data().status).toBe("completed");

      await assertFails(pointerRef.set(currentRunData()));
      await assertFails(runRef.update({ status: "running", completedAt: null }));
    });

    it("treats a duplicate completed attempt as idempotent and keeps the completed run immutable", async () => {
      const db = ownerDb();
      const profileRef = db.doc("users/user123");
      const draftRef = db.doc("users/user123/onboarding/draft");
      const runRef = db.doc(`users/user123/onboardingRuns/${verifiableRunId}`);
      const pointerRef = db.doc("users/user123/onboarding/currentRun");
      const completedStages = {
        validateInput: true,
        persistDraft: true,
        verifyDraft: true,
        persistBundle: true,
        verifyBundle: true,
        reconcileRoutines: true,
        verifyRoutines: true,
        projectRoutineHistory: true,
        verifyRoutineHistory: true,
        reconcileHabitSystems: true,
        verifyHabitSystems: true,
        reloadControllers: true,
        verifyFrontendState: true,
      };
      const running = onboardingRunData("user123", verifiableRunId, {
        stage: "finalizeProfile",
        stagesCompleted: completedStages,
      });
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const admin = context.firestore();
        await admin.doc(profileRef.path).set(userData());
        await admin.doc(draftRef.path).set(completedOnboardingDraftData());
        await admin.doc(runRef.path).set(running);
        await admin.doc(pointerRef.path).set(currentRunData("user123", verifiableRunId));
      });

      const completedProfile = userData("user123", {
        onboardingInputCompleted: true,
        onboardingProjectionStatus: "completed",
        onboardingCompleted: true,
        updatedAt: completedAt,
      });
      const completedRun = {
        ...running,
        stage: "completed",
        status: "completed",
        stagesCompleted: { ...completedStages, finalizeProfile: true },
        updatedAt: completedAt,
        completedAt,
      };
      const completedPointer = currentRunData("user123", verifiableRunId, {
        status: "completed",
        updatedAt: completedAt,
      });
      const terminal = db.batch();
      terminal.set(profileRef, completedProfile);
      terminal.set(runRef, completedRun);
      terminal.set(pointerRef, completedPointer);
      await assertSucceeds(terminal.commit());

      // A reconstructed client observes the terminal proof and repeats only
      // the pointer write performed by the production idempotency path.
      const duplicateClient = ownerDb();
      expect((await duplicateClient.doc(runRef.path).get()).data().status).toBe("completed");
      expect((await duplicateClient.doc(pointerRef.path).get()).data().status).toBe("completed");
      await assertSucceeds(duplicateClient.doc(pointerRef.path).set(completedPointer));
      await assertFails(duplicateClient.doc(runRef.path).update({
        retryCount: 1,
        updatedAt: completedAt,
      }));
      await assertFails(duplicateClient.doc(runRef.path).delete());
    });

    it("rejects cross-owner and malformed current-run pointers", async () => {
      const owner = ownerDb();
      const ref = owner.collection("users").doc("user123").collection("onboarding").doc("currentRun");
      await assertFails(ref.set(currentRunData("other_user")));
      await assertFails(ref.set(currentRunData("user123", "")));
      await assertFails(ref.set(currentRunData("user123", "run-001", { status: "completed" })));
      await assertFails(ref.set(currentRunData("user123", "run-001", { arbitrary: true })));

      const other = ownerDb("other_user");
      const crossRef = other.collection("users").doc("user123").collection("onboarding").doc("currentRun");
      await assertFails(crossRef.get());
      await assertFails(crossRef.set(currentRunData()));
    });

    it("allows transitioning currentRun to superseded and enforces lineage fencing on terminalization", async () => {
      const db = ownerDb();
      const pointerRef = db.doc("users/user123/onboarding/currentRun");
      const profileRef = db.doc("users/user123");
      const runRef = db.doc("users/user123/onboardingRuns/run-001");

      // Setup initial active pointer
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const admin = context.firestore();
        await admin.doc(pointerRef.path).set(currentRunData("user123", "run-001", {
          status: "active",
          setupGeneration: 0,
        }));
      });

      // 1. Owner can transition pointer from active to superseded with same run details
      await assertSucceeds(pointerRef.set(currentRunData("user123", "run-001", {
        status: "superseded",
        setupGeneration: 0,
        updatedAt: completedAt,
      })));
      expect((await pointerRef.get()).data().status).toBe("superseded");

      // 2. Setting pointer to superseded again is idempotent
      await assertSucceeds(pointerRef.set(currentRunData("user123", "run-001", {
        status: "superseded",
        setupGeneration: 0,
        updatedAt: completedAt,
      })));

      // 3. Lineage fence test: profile at generation 1 rejects terminalization of run from generation 0
      const stagesBeforeFinal = {
        validateInput: true, persistDraft: true, verifyDraft: true, persistBundle: true,
        verifyBundle: true, reconcileRoutines: true, verifyRoutines: true, projectRoutineHistory: true,
        verifyRoutineHistory: true, reconcileHabitSystems: true, verifyHabitSystems: true,
        reloadControllers: true, verifyFrontendState: true,
      };
      const activeRunGen0 = onboardingRunData("user123", "run-001", {
        stage: "finalizeProfile",
        status: "running",
        setupGeneration: 0,
        stagesCompleted: stagesBeforeFinal,
      });
      const completedRunGen0 = {
        ...activeRunGen0,
        stage: "completed",
        status: "completed",
        stagesCompleted: { ...stagesBeforeFinal, finalizeProfile: true },
        updatedAt: completedAt,
        completedAt,
      };
      const profileGen1 = userData("user123", {
        onboardingInputCompleted: true,
        onboardingProjectionStatus: "completed",
        onboardingCompleted: true,
        currentSetupGeneration: 1,
        updatedAt: completedAt,
      });
      const pointerGen0 = currentRunData("user123", "run-001", {
        status: "completed",
        setupGeneration: 0,
        updatedAt: completedAt,
      });

      await testEnv.withSecurityRulesDisabled(async (context) => {
        const admin = context.firestore();
        await admin.doc("users/user123/onboarding/draft").set(completedOnboardingDraftData());
        await admin.doc(profileRef.path).set(userData("user123", { currentSetupGeneration: 1 }));
        await admin.doc(runRef.path).set(activeRunGen0);
        await admin.doc(pointerRef.path).set(currentRunData("user123", "run-001", { setupGeneration: 0 }));
      });

      // Mismatched generations (run=0, pointer=0, profile=1) MUST FAIL at terminal boundary
      const fenceViolationBatch = db.batch();
      fenceViolationBatch.set(profileRef, profileGen1);
      fenceViolationBatch.set(runRef, completedRunGen0);
      fenceViolationBatch.set(pointerRef, pointerGen0);
      await assertFails(fenceViolationBatch.commit());

      // Matching generations (run=1, pointer=1, profile=1) MUST SUCCEED
      const activeRunGen1 = { ...activeRunGen0, setupGeneration: 1 };
      const matchingRunGen1 = { ...completedRunGen0, setupGeneration: 1 };
      const matchingPointerGen1 = { ...pointerGen0, setupGeneration: 1 };
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const admin = context.firestore();
        await admin.doc(runRef.path).set(activeRunGen1);
        await admin.doc(pointerRef.path).set(currentRunData("user123", "run-001", { setupGeneration: 1 }));
      });
      const matchingBatch = db.batch();
      matchingBatch.set(profileRef, profileGen1);
      matchingBatch.set(runRef, matchingRunGen1);
      matchingBatch.set(pointerRef, matchingPointerGen1);
      await assertSucceeds(matchingBatch.commit());
      expect((await profileRef.get()).data().currentSetupGeneration).toBe(1);
    });

    it("enforces setupLineageVersion monotonic fences and terminal consistency", async () => {
      const db = ownerDb();
      const profileRef = db.collection("users").doc("user123");
      const pointerRef = db.collection("users").doc("user123").collection("onboarding").doc("currentRun");
      const runRef = db.collection("users").doc("user123").collection("onboardingRuns").doc("run-001");

      // 1. Initial setup at lineage 0
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const admin = context.firestore();
        await admin.doc(profileRef.path).set(userData("user123", { setupLineageVersion: 0 }));
        await admin.doc(pointerRef.path).set(currentRunData("user123", "run-001", {
          status: "active",
          setupLineageVersion: 0,
        }));
      });

      // 2. Migration: owner can upgrade pointer to superseded with setupLineageVersion: 1
      await assertSucceeds(pointerRef.set(currentRunData("user123", "run-001", {
        status: "superseded",
        setupLineageVersion: 1,
        updatedAt: completedAt,
      })));
      expect((await pointerRef.get()).data().setupLineageVersion).toBe(1);

      // 3. Monotonic profile update: upgrading setupLineageVersion 0 -> 1 succeeds
      await assertSucceeds(profileRef.set(userData("user123", { setupLineageVersion: 1, updatedAt: completedAt })));
      expect((await profileRef.get()).data().setupLineageVersion).toBe(1);

      // 4. Monotonic profile update: regressing setupLineageVersion 1 -> 0 FAILS
      await assertFails(profileRef.set(userData("user123", { setupLineageVersion: 0, updatedAt: completedAt })));

      // 5. Terminalization fence: profile at lineage 1 rejects terminalization of run with lineage 0
      const stagesBeforeFinal = {
        validateInput: true, persistDraft: true, verifyDraft: true, persistBundle: true,
        verifyBundle: true, reconcileRoutines: true, verifyRoutines: true, projectRoutineHistory: true,
        verifyRoutineHistory: true, reconcileHabitSystems: true, verifyHabitSystems: true,
        reloadControllers: true, verifyFrontendState: true,
      };
      const activeRunLineage0 = onboardingRunData("user123", "run-001", {
        stage: "finalizeProfile",
        status: "running",
        setupLineageVersion: 0,
        stagesCompleted: stagesBeforeFinal,
      });
      const completedRunLineage0 = {
        ...activeRunLineage0,
        stage: "completed",
        status: "completed",
        stagesCompleted: { ...stagesBeforeFinal, finalizeProfile: true },
        updatedAt: completedAt,
        completedAt,
      };
      const profileCompletedLineage1 = userData("user123", {
        onboardingInputCompleted: true,
        onboardingProjectionStatus: "completed",
        onboardingCompleted: true,
        setupLineageVersion: 1,
        updatedAt: completedAt,
      });
      const pointerLineage0 = currentRunData("user123", "run-001", {
        status: "completed",
        setupLineageVersion: 0,
        updatedAt: completedAt,
      });

      await testEnv.withSecurityRulesDisabled(async (context) => {
        const admin = context.firestore();
        await admin.doc("users/user123/onboarding/draft").set(completedOnboardingDraftData("user123", { setupLineageVersion: 1 }));
        await admin.doc(profileRef.path).set(userData("user123", { setupLineageVersion: 1 }));
        await admin.doc(runRef.path).set(activeRunLineage0);
        await admin.doc(pointerRef.path).set(currentRunData("user123", "run-001", { setupLineageVersion: 0 }));
      });

      const mismatchBatch = db.batch();
      mismatchBatch.set(profileRef, profileCompletedLineage1);
      mismatchBatch.set(runRef, completedRunLineage0);
      mismatchBatch.set(pointerRef, pointerLineage0);
      await assertFails(mismatchBatch.commit());

      // 6. Matching lineage (lineage 1 for profile, run, pointer) SUCCEEDS
      const activeRunLineage1 = { ...activeRunLineage0, setupLineageVersion: 1 };
      const matchingRunLineage1 = { ...completedRunLineage0, setupLineageVersion: 1 };
      const matchingPointerLineage1 = { ...pointerLineage0, setupLineageVersion: 1 };
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const admin = context.firestore();
        await admin.doc(runRef.path).set(activeRunLineage1);
        await admin.doc(pointerRef.path).set(currentRunData("user123", "run-001", { setupLineageVersion: 1 }));
      });
      const matchingBatch = db.batch();
      matchingBatch.set(profileRef, profileCompletedLineage1);
      matchingBatch.set(runRef, matchingRunLineage1);
      matchingBatch.set(pointerRef, matchingPointerLineage1);
      await assertSucceeds(matchingBatch.commit());
      expect((await profileRef.get()).data().setupLineageVersion).toBe(1);
    });

    it("allows canonical acceptance creation, owner read, and one-way invalidation", async () => {
      const db = ownerDb();
      const ref = db.collection("users").doc("user123").collection("conflictAcceptances").doc(acceptanceId);
      await assertSucceeds(ref.set(conflictAcceptanceData()));
      await assertSucceeds(ref.get());
      await assertSucceeds(ref.update({
        status: "invalidated",
        invalidatedAt: completedAt,
        invalidationReason: "supersededByCurrentSchedule",
      }));
      await assertFails(ref.update({
        status: "active",
        invalidatedAt: null,
        invalidationReason: null,
      }));
      await assertFails(ref.delete());
    });

    it("rejects cross-owner acceptance access, owner spoofing, and document-id spoofing", async () => {
      const other = ownerDb("other_user");
      const crossRef = other.collection("users").doc("user123").collection("conflictAcceptances").doc(acceptanceId);
      await assertFails(crossRef.get());
      await assertFails(crossRef.set(conflictAcceptanceData()));

      const owner = ownerDb();
      const collection = owner.collection("users").doc("user123").collection("conflictAcceptances");
      await assertFails(collection.doc(acceptanceId).set(conflictAcceptanceData("other_user")));
      await assertFails(collection.doc(`ca_${"9".repeat(40)}`).set(conflictAcceptanceData()));
    });

    it("rejects malformed acceptance scope, recurrence, timezone, fingerprints, schema, and unknown fields", async () => {
      const db = ownerDb();
      const ref = db.collection("users").doc("user123").collection("conflictAcceptances").doc(acceptanceId);
      await assertFails(ref.set(conflictAcceptanceData("user123", { scope: "singleOccurrence" })));
      await assertFails(ref.set(conflictAcceptanceData("user123", { applicableWeekdays: [1, 1] })));
      await assertFails(ref.set(conflictAcceptanceData("user123", { applicableWeekdays: [0] })));
      await assertFails(ref.set(conflictAcceptanceData("user123", { timezoneId: "" })));
      await assertFails(ref.set(conflictAcceptanceData("user123", { combinedScheduleFingerprint: "bad" })));
      await assertFails(ref.set(conflictAcceptanceData("user123", { schemaVersion: 1 })));
      await assertFails(ref.set(conflictAcceptanceData("user123", { arbitrary: true })));
    });

    it("rejects prohibited conflict types and immutable acceptance identity mutation", async () => {
      const db = ownerDb();
      const ref = db.collection("users").doc("user123").collection("conflictAcceptances").doc(acceptanceId);
      await assertFails(ref.set(conflictAcceptanceData("user123", { conflictType: "sleepOverlap" })));
      await assertSucceeds(ref.set(conflictAcceptanceData()));
      await assertFails(ref.update({ firstScheduleFingerprint: "f".repeat(64) }));
      await assertFails(ref.update({ applicableWeekdays: [2, 4] }));
      await assertFails(ref.update({ projectionId: "another-projection-v1" }));
    });

    it("allows onboarding routine repair to update projectionId to canonical format while rejecting invalid formats", async () => {
      const db = ownerDb();
      const ref = db.collection("users").doc("user123").collection("routineItems").doc("projected-repair-1");
      await assertSucceeds(ref.set(routineItemData("user123", "projected-repair-1", {
        source: "onboarding",
        onboardingProjectionId: "onboarding-initial-v1",
        onboardingSourceItemId: "source-1",
      })));

      // Valid new canonical projection ID
      const canonicalRunId = "a".repeat(40);
      const newProjId = `onboarding-run_${canonicalRunId}-v1`;
      await assertSucceeds(ref.update({
        onboardingProjectionId: newProjId,
        updatedAt: completedAt,
      }));

      // Invalid projection ID format rejected
      await assertFails(ref.update({
        onboardingProjectionId: "invalid-projection-format",
        updatedAt: completedAt,
      }));
    });

    it("handles pending vs completed routine projection receipt totalCount constraints", async () => {
      const db = ownerDb();
      const canonicalRunId = "b".repeat(40);
      const projId = `onboarding-run_${canonicalRunId}-v1`;
      const docRef = db.collection("users").doc("user123").collection("routineProjections").doc(projId);

      // Pending receipt with partial projected items succeeds
      await assertSucceeds(docRef.set(projectionData("user123", {
        id: projId,
        slot: `onboarding-run_${canonicalRunId}`,
        status: "pending",
        cursor: 32,
        totalCount: 52,
        projectedItemIds: Array.from(
          { length: 32 },
          (_, index) => `onb_${index.toString(16).padStart(40, "0")}`
        ),
      })));

      // Completed receipt with mismatching totalCount and projectedItemIds size fails
      const invalidCompletedRef = db.collection("users").doc("user123").collection("routineProjections").doc(`onboarding-run_${"c".repeat(40)}-v1`);
      await assertFails(invalidCompletedRef.set(projectionData("user123", {
        id: `onboarding-run_${"c".repeat(40)}-v1`,
        slot: `onboarding-run_${"c".repeat(40)}`,
        status: "completed",
        cursor: 32,
        totalCount: 52,
        completedAt: completedAt,
        projectedItemIds: Array.from(
          { length: 32 },
          (_, index) => `onb_${index.toString(16).padStart(40, "0")}`
        ),
      })));
    });
  });
});

describe("Firestore Rules for upload metadata", () => {
  function uploadData(uid = "user123", assetId = "asset-001", overrides = {}) {
    const data = {
      assetId,
      ownerUid: uid,
      sourceFeature: "onboarding",
      purpose: "skin_face",
      fileName: "photo.jpg",
      contentType: "image/jpeg",
      sizeBytes: 1048576,
      status: "uploaded",
      createdAt,
      updatedAt,
      errorMessage: null,
      ...overrides,
    };
    if (!("r2Key" in overrides)) {
      data.r2Key = `users/${uid}/${data.sourceFeature}/${data.purpose}/${assetId}.jpg`;
    }
    return data;
  }

  function uploadRef(db, uid = "user123", assetId = "asset-001") {
    return db.collection("users").doc(uid).collection("uploads").doc(assetId);
  }

  // --- Owner create: one test per purpose ---

  it("owner creates skin_face upload", async () => {
    const db = ownerDb();
    await assertSucceeds(uploadRef(db).set(uploadData()));
  });

  it("owner creates skin_products upload", async () => {
    const db = ownerDb();
    await assertSucceeds(uploadRef(db, "user123", "asset-002").set(
      uploadData("user123", "asset-002", { purpose: "skin_products" })
    ));
  });

  it("owner creates class_timetable upload", async () => {
    const db = ownerDb();
    await assertSucceeds(uploadRef(db, "user123", "asset-003").set(
      uploadData("user123", "asset-003", { purpose: "class_timetable" })
    ));
  });

  it("owner creates work_schedule upload", async () => {
    const db = ownerDb();
    await assertSucceeds(uploadRef(db, "user123", "asset-004").set(
      uploadData("user123", "asset-004", { purpose: "work_schedule" })
    ));
  });

  it("owner creates eating_menu upload", async () => {
    const db = ownerDb();
    await assertSucceeds(uploadRef(db, "user123", "asset-005").set(
      uploadData("user123", "asset-005", { purpose: "eating_menu" })
    ));
  });

  it("rejects owner creates legacy skin_care upload", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db, "user123", "asset-006").set(
      uploadData("user123", "asset-006", { purpose: "skin_care", r2Key: "uploads/user123/asset-006.jpg" })
    ));
  });

  it("owner creates profile_photo upload with correct constraints", async () => {
    const db = ownerDb();
    await assertSucceeds(uploadRef(db, "user123", "asset-007").set(
      uploadData("user123", "asset-007", {
        purpose: "profile_photo",
        contentType: "image/jpeg",
        sizeBytes: 2097152,
      })
    ));
  });

  // --- Base Timeline upload tests ---

  it("owner creates routine_base_timeline class_timetable upload", async () => {
    const db = ownerDb();
    await assertSucceeds(uploadRef(db, "user123", "bt-class").set(
      uploadData("user123", "bt-class", {
        sourceFeature: "routine_base_timeline",
        purpose: "class_timetable",
      })
    ));
  });

  it("owner creates routine_base_timeline work_schedule upload", async () => {
    const db = ownerDb();
    await assertSucceeds(uploadRef(db, "user123", "bt-work").set(
      uploadData("user123", "bt-work", {
        sourceFeature: "routine_base_timeline",
        purpose: "work_schedule",
      })
    ));
  });

  it("owner creates routine_base_timeline eating_menu upload", async () => {
    const db = ownerDb();
    await assertSucceeds(uploadRef(db, "user123", "bt-eating").set(
      uploadData("user123", "bt-eating", {
        sourceFeature: "routine_base_timeline",
        purpose: "eating_menu",
      })
    ));
  });

  it("owner creates routine_base_timeline skin_face upload", async () => {
    const db = ownerDb();
    await assertSucceeds(uploadRef(db, "user123", "bt-face").set(
      uploadData("user123", "bt-face", {
        sourceFeature: "routine_base_timeline",
        purpose: "skin_face",
      })
    ));
  });

  it("owner creates routine_base_timeline skin_products upload", async () => {
    const db = ownerDb();
    await assertSucceeds(uploadRef(db, "user123", "bt-products").set(
      uploadData("user123", "bt-products", {
        sourceFeature: "routine_base_timeline",
        purpose: "skin_products",
      })
    ));
  });

  it("rejects routine_base_timeline with profile_photo", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db, "user123", "bt-profile").set(
      uploadData("user123", "bt-profile", {
        sourceFeature: "routine_base_timeline",
        purpose: "profile_photo",
        contentType: "image/jpeg",
        sizeBytes: 2097152,
      })
    ));
  });

  it("rejects routine_base_timeline with invalid purpose", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db, "user123", "bt-invalid").set(
      uploadData("user123", "bt-invalid", {
        sourceFeature: "routine_base_timeline",
        purpose: "invalid_purpose",
      })
    ));
  });

  it("rejects unknown sourceFeature", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db, "user123", "unknown-src").set(
      uploadData("user123", "unknown-src", {
        sourceFeature: "unknown_feature",
        purpose: "class_timetable",
      })
    ));
  });

  // --- Owner read ---

  it("owner reads own upload", async () => {
    const adminDb = testEnv.authenticatedContext("user123", { email_verified: true }).firestore();
    await uploadRef(adminDb).set(uploadData());
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = ownerDb();
    await assertSucceeds(uploadRef(db).get());
  });

  // --- Owner legitimate update ---

  it("owner updates status to deleted with immutable fields preserved", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = ownerDb();
    const updatedAt2 = new Date("2026-07-24T01:00:00.000Z");
    await assertSucceeds(uploadRef(db).set(
      uploadData("user123", "asset-001", { status: "deleted", updatedAt: updatedAt2, errorMessage: null })
    ));
  });

  it("allows the owner to terminalize an exact legacy skin_care upload", async () => {
    const legacy = uploadData("user123", "legacy-skin-001", {
      purpose: "skin_care",
      r2Key: "users/user123/onboarding/skin_care/legacy-skin-001.jpg",
    });
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await uploadRef(context.firestore(), "user123", "legacy-skin-001").set(legacy);
    });
    const updatedAt2 = new Date("2026-07-24T01:00:00.000Z");
    await assertSucceeds(
      uploadRef(ownerDb(), "user123", "legacy-skin-001").set({
        ...legacy,
        status: "deleted",
        updatedAt: updatedAt2,
      })
    );
  });

  it("rejects cross-user terminalization of a legacy skin_care upload", async () => {
    const legacy = uploadData("user123", "legacy-skin-002", {
      purpose: "skin_care",
      r2Key: "users/user123/onboarding/skin_care/legacy-skin-002.jpg",
    });
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await uploadRef(context.firestore(), "user123", "legacy-skin-002").set(legacy);
    });
    const attackerDb = testEnv
      .authenticatedContext("attacker", { email_verified: true })
      .firestore();
    await assertFails(
      uploadRef(attackerDb, "user123", "legacy-skin-002").set({
        ...legacy,
        status: "deleted",
        updatedAt: new Date("2026-07-24T01:00:00.000Z"),
      })
    );
  });

  it("owner updates status to failed with errorMessage", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = ownerDb();
    const updatedAt2 = new Date("2026-07-24T01:00:00.000Z");
    await assertSucceeds(uploadRef(db).set(
      uploadData("user123", "asset-001", { status: "failed", updatedAt: updatedAt2, errorMessage: "Upload timed out" })
    ));
  });

  // --- Immutability attacks ---

  it("rejects update changing purpose from skin_face to skin_products", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = ownerDb();
    await assertFails(uploadRef(db).set(
      uploadData("user123", "asset-001", { purpose: "skin_products" })
    ));
  });

  it("rejects update changing ownerUid", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = ownerDb();
    await assertFails(uploadRef(db).set(
      uploadData("user123", "asset-001", { ownerUid: "attacker" })
    ));
  });

  it("rejects update changing assetId", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = ownerDb();
    await assertFails(uploadRef(db).set(
      uploadData("user123", "asset-001", { assetId: "asset-999" })
    ));
  });

  it("rejects update changing createdAt", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = ownerDb();
    await assertFails(uploadRef(db).set(
      uploadData("user123", "asset-001", { createdAt: new Date("2020-01-01T00:00:00.000Z") })
    ));
  });

  it("rejects update changing sourceFeature", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = ownerDb();
    await assertFails(uploadRef(db).set(
      uploadData("user123", "asset-001", { sourceFeature: "profile" })
    ));
  });

  it("rejects update changing r2Key", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = ownerDb();
    await assertFails(uploadRef(db).set(
      uploadData("user123", "asset-001", { r2Key: "uploads/user123/hijacked.jpg" })
    ));
  });

  it("rejects update changing fileName", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = ownerDb();
    await assertFails(uploadRef(db).set(
      uploadData("user123", "asset-001", { fileName: "different.png" })
    ));
  });

  it("rejects update changing contentType", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = ownerDb();
    await assertFails(uploadRef(db).set(
      uploadData("user123", "asset-001", { contentType: "image/png" })
    ));
  });

  it("rejects update changing sizeBytes", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = ownerDb();
    await assertFails(uploadRef(db).set(
      uploadData("user123", "asset-001", { sizeBytes: 9999999 })
    ));
  });

  // --- Cross-user isolation ---

  it("rejects user B reading user A upload", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = ownerDb("attacker");
    await assertFails(uploadRef(db, "user123").get());
  });

  it("rejects user B creating under user A path", async () => {
    const db = ownerDb("attacker");
    await assertFails(uploadRef(db, "user123", "asset-attack").set(
      uploadData("attacker", "asset-attack")
    ));
  });

  it("rejects user B updating user A upload", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = ownerDb("attacker");
    await assertFails(uploadRef(db, "user123").set(
      uploadData("user123", "asset-001", { status: "deleted" })
    ));
  });

  it("rejects user B deleting user A upload", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = ownerDb("attacker");
    await assertFails(uploadRef(db, "user123").delete());
  });

  // --- Unauthenticated ---

  it("rejects unauthenticated read", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(uploadRef(db).get());
  });

  it("rejects unauthenticated create", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(uploadRef(db).set(uploadData()));
  });

  it("rejects unauthenticated update", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(uploadRef(db).set(
      uploadData("user123", "asset-001", { status: "deleted" })
    ));
  });

  it("rejects unauthenticated delete", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(uploadRef(db).delete());
  });

  // --- Unverified email ---

  it("rejects create with unverified email", async () => {
    const db = ownerDb("user123", false);
    await assertFails(uploadRef(db).set(uploadData()));
  });

  // --- Invalid data ---

  it("rejects invalid purpose", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db).set(
      uploadData("user123", "asset-001", { purpose: "selfie" })
    ));
  });

  it("rejects invalid content type for routine-import purpose", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db).set(
      uploadData("user123", "asset-001", { contentType: "application/pdf" })
    ));
  });

  it("rejects webp content type for profile_photo", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db, "user123", "asset-pp").set(
      uploadData("user123", "asset-pp", {
        purpose: "profile_photo",
        contentType: "image/webp",
        sizeBytes: 1048576,
        r2Key: "uploads/user123/asset-pp.webp",
      })
    ));
  });

  it("rejects size exceeding 15 MB for image upload", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db).set(
      uploadData("user123", "asset-001", { sizeBytes: 15728641 })
    ));
  });

  it("rejects size exceeding 5 MB for profile_photo", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db, "user123", "asset-pp2").set(
      uploadData("user123", "asset-pp2", {
        purpose: "profile_photo",
        contentType: "image/jpeg",
        sizeBytes: 5242881,
        r2Key: "uploads/user123/asset-pp2.jpg",
      })
    ));
  });

  it("rejects zero sizeBytes", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db).set(
      uploadData("user123", "asset-001", { sizeBytes: 0 })
    ));
  });

  it("rejects forged ownerUid on create", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db, "user123", "asset-forged").set(
      uploadData("victim-uid", "asset-forged", { r2Key: "uploads/victim/forged.jpg" })
    ));
  });

  it("rejects banned localPreviewPath field", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db, "user123", "asset-banned").set({
      ...uploadData("user123", "asset-banned", { r2Key: "uploads/user123/asset-banned.jpg" }),
      localPreviewPath: "/tmp/preview.jpg",
    }));
  });

  it("rejects delete by owner", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").collection("uploads").doc("asset-001").set(uploadData());
    });
    const db = ownerDb();
    await assertFails(uploadRef(db).delete());
  });

  it("rejects invalid status value", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db).set(
      uploadData("user123", "asset-001", { status: "approved" })
    ));
  });

  it("rejects assetId not matching document path", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db, "user123", "asset-001").set(
      uploadData("user123", "mismatched-id")
    ));
  });

  it("rejects sourceFeature other than onboarding or routine_base_timeline", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db).set(
      uploadData("user123", "asset-001", { sourceFeature: "profile" })
    ));
  });

  it("accepts webp content type for skin_face", async () => {
    const db = ownerDb();
    await assertSucceeds(uploadRef(db, "user123", "asset-webp").set(
      uploadData("user123", "asset-webp", {
        contentType: "image/webp",
        r2Key: "users/user123/onboarding/skin_face/asset-webp.webp",
        fileName: "photo.webp",
      })
    ));
  });

  it("accepts png content type for skin_products", async () => {
    const db = ownerDb();
    await assertSucceeds(uploadRef(db, "user123", "asset-png").set(
      uploadData("user123", "asset-png", {
        purpose: "skin_products",
        contentType: "image/png",
        r2Key: "users/user123/onboarding/skin_products/asset-png.png",
        fileName: "photo.png",
      })
    ));
  });

  it("rejects r2Key containing another UID", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db, "user123", "asset-uid").set(
      uploadData("user123", "asset-uid", {
        purpose: "class_timetable",
        r2Key: "users/other/onboarding/class_timetable/asset-uid.jpg",
      })
    ));
  });

  it("rejects r2Key containing another purpose", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db, "user123", "asset-purpose").set(
      uploadData("user123", "asset-purpose", {
        purpose: "eating_menu",
        r2Key: "users/user123/onboarding/work_schedule/asset-purpose.jpg",
      })
    ));
  });

  it("rejects r2Key containing another assetId", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db, "user123", "asset-real").set(
      uploadData("user123", "asset-real", {
        r2Key: "users/user123/onboarding/skin_face/asset-fake.jpg",
      })
    ));
  });

  it("rejects traversal and unexpected upload namespaces", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db, "user123", "asset-traversal").set(
      uploadData("user123", "asset-traversal", {
        r2Key: "users/user123/onboarding/class_timetable/../asset-traversal.jpg",
      })
    ));
    await assertFails(uploadRef(db, "user123", "asset-namespace").set(
      uploadData("user123", "asset-namespace", {
        r2Key: "uploads/user123/onboarding/skin_face/asset-namespace.jpg",
      })
    ));
  });

  it("rejects an unsupported object extension", async () => {
    const db = ownerDb();
    await assertFails(uploadRef(db, "user123", "asset-gif").set(
      uploadData("user123", "asset-gif", {
        r2Key: "users/user123/onboarding/skin_face/asset-gif.gif",
      })
    ));
  });
});

describe("Firestore Rules for baseTimelineSetup", () => {
  function baseTimelineSetupRef(db, uid = "user123", setupId = "current") {
    return db.collection("users").doc(uid).collection("baseTimelineSetup").doc(setupId);
  }

  it("owner can create and read baseTimelineSetup document", async () => {
    const db = ownerDb();
    await assertSucceeds(
      baseTimelineSetupRef(db).set({
        schemaVersion: 1,
        updatedAt: new Date().toISOString(),
        sections: {},
      })
    );
    const doc = await baseTimelineSetupRef(db).get();
    expect(doc.exists).toBe(true);
  });

  it("owner can update baseTimelineSetup document", async () => {
    const db = ownerDb();
    await baseTimelineSetupRef(db).set({
      schemaVersion: 1,
      updatedAt: new Date().toISOString(),
      sections: {},
    });
    await assertSucceeds(
      baseTimelineSetupRef(db).update({
        "sections.classes.configured": true,
      })
    );
  });

  it("non-owner cannot read or write baseTimelineSetup document", async () => {
    const other = ownerDb("other_user");
    await assertFails(
      baseTimelineSetupRef(other, "user123").set({
        schemaVersion: 1,
        updatedAt: new Date().toISOString(),
        sections: {},
      })
    );
    await assertFails(baseTimelineSetupRef(other, "user123").get());
  });

  it("unauthenticated client cannot read or write baseTimelineSetup document", async () => {
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      baseTimelineSetupRef(anon, "user123").set({
        schemaVersion: 1,
        updatedAt: new Date().toISOString(),
        sections: {},
      })
    );
    await assertFails(baseTimelineSetupRef(anon, "user123").get());
  });
});
