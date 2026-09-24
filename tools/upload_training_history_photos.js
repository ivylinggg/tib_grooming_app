const fs = require('fs');
const path = require('path');

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Missing GOOGLE_APPLICATION_CREDENTIALS.');
  process.exit(1);
}

const serviceAccount = require(process.env.GOOGLE_APPLICATION_CREDENTIALS);

initializeApp({
  credential: cert(serviceAccount),
  projectId: 'tib-grooming',
  storageBucket: 'tib-grooming.firebasestorage.app',
});

const db = getFirestore();
const bucket = getStorage().bucket();

const PHOTO_ROOT = path.resolve(__dirname, '../training_final');

const records = [
  ['2025-11-04-hakeem', '2025-11-04', 'Hakeem'],
  ['2025-11-04-maserda', '2025-11-04', 'Maserda'],
  ['2025-11-04-danial', '2025-11-04', 'Danial'],
  ['2025-11-04-alif', '2025-11-04', 'Alif'],
  ['2025-11-04-putra', '2025-11-04', 'Putra'],
  ['2025-11-04-akmal', '2025-11-04', 'Akmal'],
  ['2025-11-04-fiqah', '2025-11-04', 'Fiqah'],
  ['2025-11-04-nur-nali', '2025-11-04', 'Nur Nali'],
  ['2025-11-04-yish', '2025-11-04', 'Yish'],
  ['2025-11-04-azeem-haqeemi', '2025-11-04', 'Azeem Haqeemi'],
  ['2025-11-04-nursafida', '2025-11-04', 'Nursafida'],
  ['2025-11-04-camila', '2025-11-04', 'Camila'],
  ['2025-11-04-farid', '2025-11-04', 'Farid'],
  ['2026-07-23-syaza', '2026-07-23', 'Syaza'],
  ['2026-07-23-reona', '2026-07-23', 'Reona'],
  ['2026-07-23-hana', '2026-07-23', 'Hana'],
  ['2026-07-23-mia', '2026-07-23', 'Mia'],
  ['2026-07-23-dania', '2026-07-23', 'Dania'],
  ['2026-07-23-sufi', '2026-07-23', 'Sufi'],
  ['2026-07-23-thusna', '2026-07-23', 'Thusna'],
  ['2026-07-23-intan', '2026-07-23', 'Intan'],
  ['2026-07-23-aina', '2026-07-23', 'Aina'],
  ['2026-07-23-sarah', '2026-07-23', 'Sarah'],
  ['2026-07-23-faizul', '2026-07-23', 'Faizul'],
  ['2026-07-23-jack', '2026-07-23', 'Jack'],
  ['2026-07-23-hanif', '2026-07-23', 'Hanif'],
  ['2026-07-23-danial-mc', '2026-07-23', 'Danial (MC)'],
  ['2026-07-23-mizrah', '2026-07-23', 'Mizrah'],
  ['2026-07-23-kimi', '2026-07-23', 'Kimi'],
  ['2026-07-31-kinal', '2026-07-31', 'Kinal'],
  ['2026-07-31-farhana', '2026-07-31', 'Farhana'],
  ['2026-07-31-irma', '2026-07-31', 'Irma'],
  ['2026-07-31-ameer', '2026-07-31', 'Ameer'],
  ['2026-07-31-marissa', '2026-07-31', 'Marissa'],
  ['2026-07-31-tasha', '2026-07-31', 'Tasha'],
  ['2026-07-31-diyanah', '2026-07-31', 'Diyanah'],
  ['2026-08-05-siti-nurmaisarah', '2026-08-05', 'Siti Nurmaisarah'],
  ['2026-08-05-ranjini', '2026-08-05', 'Ranjini'],
  ['2026-08-05-manpreet', '2026-08-05', 'Manpreet'],
  ['2026-08-05-shywanis', '2026-08-05', 'Shywanis'],
  ['2026-08-05-izarfiq', '2026-08-05', 'Izarfiq'],
  ['2026-08-05-khai', '2026-08-05', 'Khai'],
  ['2026-08-05-iman', '2026-08-05', 'Iman'],
  ['2026-08-05-isa', '2026-08-05', 'Isa'],
  ['2026-08-05-daiyan', '2026-08-05', 'Daiyan'],
  ['2026-08-05-trish', '2026-08-05', 'Trish'],
  ['2026-08-05-iz', '2026-08-05', 'Iz'],
  ['2026-08-05-danial', '2026-08-05', 'Danial'],
  ['2026-08-05-amir', '2026-08-05', 'Amir'],
  ['2026-08-05-puteri', '2026-08-05', 'Puteri'],
  ['2026-08-05-louis', '2026-08-05', 'Louis'],
  ['2026-08-05-hazreen', '2026-08-05', 'Hazreen'],
];

function normalizeName(name) {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
}

function findPhotoDir(date, name) {
  const exact = path.join(PHOTO_ROOT, date, normalizeName(name));
  if (fs.existsSync(exact)) return exact;

  const base = path.join(PHOTO_ROOT, date);
  if (!fs.existsSync(base)) return null;

  const target = normalizeName(name);
  const candidate = fs.readdirSync(base).find((entry) => normalizeName(entry) === target);
  return candidate ? path.join(base, candidate) : null;
}

function listImages(dir) {
  if (!dir || !fs.existsSync(dir)) return [];
  return fs.readdirSync(dir)
    .filter((f) => /\.(jpg|jpeg|png|webp)$/i.test(f))
    .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
}

async function upload(localPath, storagePath) {
  await bucket.upload(localPath, {
    destination: storagePath,
    metadata: {
      contentType: 'image/jpeg',
      cacheControl: 'public,max-age=31536000',
    },
  });

  const file = bucket.file(storagePath);
  await file.makePublic();

  return `https://storage.googleapis.com/${bucket.name}/${storagePath.split('/').map(encodeURIComponent).join('/')}`;
}

async function main() {
  let updated = 0;
  let skipped = 0;

  console.log(`Starting photo import for ${records.length} history records...`);

  for (const [docId, date, name] of records) {
    const dir = findPhotoDir(date, name);
    const files = listImages(dir);

    if (files.length === 0) {
      console.log(`⚠️ Skipped: ${date} / ${name} (no photo files found)`);
      skipped++;
      continue;
    }

    const photoUrls = [];

    for (const fileName of files) {
      const localPath = path.join(dir, fileName);
      const storagePath = `training_history/${date}/${normalizeName(name)}/${fileName}`;

      const url = await upload(localPath, storagePath);
      photoUrls.push(url);

      console.log(`  uploaded ${date} / ${name} / ${fileName}`);
    }

    await db.collection('training_history').doc(docId).set(
      { photoUrls },
      { merge: true },
    );

    updated++;
    console.log(`✅ Updated ${name}: ${photoUrls.length} photo(s)`);
  }

  console.log('');
  console.log('========================================');
  console.log(`Updated records: ${updated}`);
  console.log(`Skipped records: ${skipped}`);
  console.log('========================================');
}

main().catch((error) => {
  console.error('❌ Photo import failed:');
  console.error(error);
  process.exit(1);
});
