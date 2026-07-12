/**
 * run-once.js
 * Lit FIREBASE_SERVICE_ACCOUNT, initialise firebase-admin,
 * calcule les conditions pour chaque spot et les écrit dans Firestore.
 */

const admin = require("firebase-admin");
const { FISHING_SPOTS, buildConditionsForSpot } = require("./lib/conditions");

async function main() {
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!serviceAccountJson) {
    console.error("FIREBASE_SERVICE_ACCOUNT manquante");
    process.exit(1);
  }

  const serviceAccount = JSON.parse(serviceAccountJson);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  const db = admin.firestore();

  for (const spot of FISHING_SPOTS) {
    try {
      console.log(`Traitement de ${spot.name}...`);
      const conditions = await buildConditionsForSpot(spot);
      await db.collection("conditions").doc(spot.spotId).set(conditions);
      console.log(`✔ ${spot.name} écrit (score: ${conditions.activityScore})`);
    } catch (err) {
      console.error(`✘ Erreur pour ${spot.name}:`, err.message);
    }
  }

  console.log("Terminé.");
  await admin.app().delete();
  process.exit(0);
}
main().catch((err) => {
  console.error("Erreur fatale:", err);
  process.exit(1);
});
