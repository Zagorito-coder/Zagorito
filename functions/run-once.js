/**
 * run-once.js
 * Lit FIREBASE_SERVICE_ACCOUNT depuis les variables d'environnement,
 * initialise firebase-admin, et pour chaque spot de FISHING_SPOTS,
 * calcule les conditions via buildConditionsForSpot et les écrit
 * dans la collection Firestore "conditions" (doc = spotId).
 */

const { cert, initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { FISHING_SPOTS, buildConditionsForSpot } = require('./lib/conditions');

async function main() {
  if (!process.env.OPEN_METEO_API_KEY) {
    console.error('Erreur : OPEN_METEO_API_KEY est obligatoire pour l\'usage commercial d\'Open-Meteo.');
    process.exit(1);
  }

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
  initializeApp({
    credential: cert(serviceAccount),
  });

  const db = getFirestore();
  let failedSpots = 0;

  // 3. Traitement de chaque spot
  for (const spot of FISHING_SPOTS) {
    try {
      console.log(`Traitement du spot : ${spot.name} (${spot.spotId})...`);
      const conditions = await buildConditionsForSpot(spot);

      await db.collection('conditions').doc(spot.spotId).set(conditions);
      console.log(`✅ Conditions écrites pour ${spot.spotId} (score: ${conditions.activityScore})`);
    } catch (err) {
      failedSpots += 1;
      console.error(`❌ Erreur pour ${spot.spotId} :`, err.message);
    }
  }

  console.log(`Terminé. ${FISHING_SPOTS.length - failedSpots}/${FISHING_SPOTS.length} spots mis à jour.`);
  // Un job vert alors qu'une station n'a pas été actualisée masque des
  // données périmées dans l'application. Les écritures réussies sont
  // conservées, mais le workflow doit signaler l'échec pour permettre une
  // reprise/alerte opérationnelle.
  process.exitCode = failedSpots > 0 ? 1 : 0;
}

main().catch((err) => {
  console.error('Erreur fatale :', err);
  process.exit(1);
});
