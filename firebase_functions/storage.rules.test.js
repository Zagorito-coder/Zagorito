'use strict';

const test = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const projectId = 'demo-boosterfish';
const [host, portText] = process.env.FIREBASE_STORAGE_EMULATOR_HOST.split(':');
const jpegBytes = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
let environment;

function avatarReference(context, uid = 'owner-1') {
  return context.storage().ref(`profile_avatars/${uid}/avatar.jpg`);
}

test.before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    storage: {host, port: Number(portText)},
  });
});

test.beforeEach(async () => {
  await environment.clearStorage();
});

test.after(async () => {
  await environment.cleanup();
});

test('the owner can upload the single processed JPEG profile photo', async () => {
  const owner = environment.authenticatedContext('owner-1');
  await assertSucceeds(
    avatarReference(owner).put(jpegBytes, {contentType: 'image/jpeg'}),
  );
});

test('another user and an anonymous client cannot upload an avatar', async () => {
  const attacker = environment.authenticatedContext('attacker-1');
  const anonymous = environment.unauthenticatedContext();
  await assertFails(
    avatarReference(attacker).put(jpegBytes, {contentType: 'image/jpeg'}),
  );
  await assertFails(
    avatarReference(anonymous).put(jpegBytes, {contentType: 'image/jpeg'}),
  );
});

test('invalid content type and oversized files are rejected', async () => {
  const owner = environment.authenticatedContext('owner-1');
  await assertFails(
    avatarReference(owner).put(jpegBytes, {contentType: 'image/png'}),
  );
  await assertFails(
    avatarReference(owner).put(
      new Uint8Array(358401),
      {contentType: 'image/jpeg'},
    ),
  );
});

test('bundled WebP presets can never be uploaded to Firebase Storage', async () => {
  const owner = environment.authenticatedContext('owner-1');
  const webpReference = owner.storage().ref(
    'profile_avatars/owner-1/fisher_01.webp',
  );
  await assertFails(
    webpReference.put(new Uint8Array([0x52, 0x49, 0x46, 0x46]), {
      contentType: 'image/webp',
    }),
  );
});

test('the selected photo is public, but only its owner can delete it', async () => {
  const owner = environment.authenticatedContext('owner-1');
  const attacker = environment.authenticatedContext('attacker-1');
  const anonymous = environment.unauthenticatedContext();
  await avatarReference(owner).put(jpegBytes, {contentType: 'image/jpeg'});

  await assertSucceeds(avatarReference(anonymous).getDownloadURL());
  await assertFails(avatarReference(attacker).delete());
  await assertSucceeds(avatarReference(owner).delete());
});
