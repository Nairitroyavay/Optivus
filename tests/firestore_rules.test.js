
const { assertFails, assertSucceeds, initializeTestEnvironment } = require("@firebase/rules-unit-testing");
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
    displayName: "Test User",
    email: "user@example.com",
    onboardingCompleted: false,
    createdAt,
    updatedAt,
    ...overrides,
  };
}

function onboardingJobData(uid = "user123", overrides = {}) {
  return {
    jobId: "current",
    ownerUid: uid,
    stage: "persistDraft",
    status: "in_progress",
    createdAt,
    updatedAt,
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
        await assertSucceeds(draftRef.set({
          uid: "user123",
          schemaVersion: 1,
          currentStep: 2,
          stepCompleted: [0, 1],
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
          createdAt,
          updatedAt
        }));

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
        await assertSucceeds(bundleRef.set({
          uid: "user123",
          schemaVersion: 1,
          onboardingCompleted: true,
          userProfilePatch: { displayName: "Test User" },
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
          createdAt,
          updatedAt
        }));

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
          timezone: "America/New_York",
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

