// ocr/test-basic.js - TEST RAPID OCR (Tesseract.js)
const Tesseract = require('tesseract.js');
const path = require('path');
const fs = require('fs');

console.log('VaultGuard OCR Test - Starting...');

// Test pe o imagine demo (sau specifică tu o cale)
const testImagePath = path.join(__dirname, '..', 'test-screenshot.png');

if (!fs.existsSync(testImagePath)) {
  console.log('Nu am gasit test-screenshot.png');
  console.log('Salveaza un screenshot cu text aici:');
  console.log(`  ${testImagePath}`);
  process.exit(0);
}

async function extractText(imagePath) {
  console.log(`\nProcesez: ${path.basename(imagePath)}`);
  console.log('OCR in curs... (prima data poate dura 10-30s)');

  const result = await Tesseract.recognize(
    imagePath,
    'ron+eng',
    {
      logger: (m) => {
        if (m.status === 'recognizing text') process.stdout.write('.');
      },
    }
  );

  console.log('\n\nTEXT EXTRAS:');
  console.log('='.repeat(60));
  console.log(result.data.text);
  console.log('='.repeat(60));

  console.log('\nSTATISTICI:');
  console.log(`  Incredere medie: ${Number(result.data.confidence).toFixed(2)}%`);
  if (result.data.language) console.log(`  Limba detectata: ${result.data.language}`);
  if (result.data.tesseract_ms) console.log(`  Timp procesare: ${Math.round(result.data.tesseract_ms)}ms`);

  return result.data.text;
}

extractText(testImagePath)
  .then(() => console.log('\nOCR TEST COMPLETAT CU SUCCES'))
  .catch((err) => {
    console.error('\nOCR TEST ESUAT:', err && err.message ? err.message : err);
    process.exit(1);
  });

