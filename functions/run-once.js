/**
 * run-once.js
 * Lit FIREBASE_SERVICE_ACCOUNT depuis les variables d'environnement,
 * initialise firebase-admin, et pour chaque spot de FISHING_SPOTS,
 * calcule les conditions via buildConditionsForSpot et les écrit
 * dans la collection Firestore "conditions" (doc = spotId).
 */

const admin = require('firebase-admin');
const { FISHING_SPOTS, buildConditionsForSpot } = require('./lib/conditions');

async function main() {
  // 1. Lecture du compte de service depuis l'environnement
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!serviceAccountJson) {
    console.error('Erreur : la variable FIREBASE_SERVICE_ACCOUNT est manquante.');
    process.exit(1);
  }

  let serviceAccount;
  try {
    serviceAccount = JSON.parse(serviceAccountJson);
  } catch (e) {
    console.error('Erreur : FIREBASE_SERVICE_ACCOUNT n\'est pas un JSON valide.', e.message);
    process.exit(1);
  }

  // 2. Initialisation Firebase Admin
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  const db = admin.firestore();

  // 3. Traitement de chaque spot
  for (const spot of FISHING_SPOTS) {
    try {
      console.log(`Traitement du spot : ${spot.name} (${spot.spotId})...`);
      const conditions = await buildConditionsForSpot(spot);

      await db.collection('conditions').doc(spot.spotId).set(conditions);
      console.log(`✅ Conditions écrites pour ${spot.spotId} (score: ${conditions.activityScore})`);
    } catch (err) {
      console.error(`❌ Erreur pour ${spot.spotId} :`, err.message);
    }
  }

  console.log('Terminé.');
  process.exit(0);
}

main().catch((err) => {
  console.error('Erreur fatale :', err);
  process.exit(1);
});
