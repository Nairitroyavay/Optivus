
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

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-project-1234",
    firestore: {
      rules: fs.readFileSync("firestore.rules", "utf8"),
    },
  });
});

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
  });
});
