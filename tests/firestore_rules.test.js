
const { assertFails, assertSucceeds, initializeTestEnvironment } = require("@firebase/rules-unit-testing");
const fs = require("fs");

let testEnv;

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
      createdAt: testEnv.firestore.FieldValue.serverTimestamp(),
      updatedAt: testEnv.firestore.FieldValue.serverTimestamp()
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
      createdAt: testEnv.firestore.FieldValue.serverTimestamp(),
      updatedAt: testEnv.firestore.FieldValue.serverTimestamp()
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
      createdAt: testEnv.firestore.FieldValue.serverTimestamp()
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
      createdAt: testEnv.firestore.FieldValue.serverTimestamp()
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
      createdAt: testEnv.firestore.FieldValue.serverTimestamp()
    }));
  });
});
