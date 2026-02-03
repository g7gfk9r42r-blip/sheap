import fs from 'fs-extra';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

// ESM-friendly __dirname
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
function parseArgs(argv) {
  const args = {};
  for (const token of argv.slice(2)) {
    const i = token.indexOf('=');
    if (i > 0) {
      const k = token.slice(0, i);
      const v = token.slice(i + 1);
      args[k] = v;
    }
  }
  return args;
}

function which(cmd) {
  return new Promise((resolve) => {
    const ps = spawn('which', [cmd]);
    ps.on('error', () => resolve(null));
    ps.on('exit', (code) => resolve(code === 0 ? cmd : null));
  });
}

function run(cmd, args, opts = {}) {
  return new Promise((resolve, reject) => {
    const ps = spawn(cmd, args, { stdio: 'inherit', ...opts });
    ps.on('error', reject);
    ps.on('exit', (code) => (code === 0 ? resolve() : reject(new Error(`${cmd} exited ${code}`))));
  });
}

async function ensureOutDir(p) {
  await fs.ensureDir(path.dirname(p));
}

// Extract text via: pdftoppm -> images -> tesseract
async function ocrPdfToText({ pdfPath, workDir }) {
  const ppmPrefix = path.join(workDir, 'page');
  // Convert PDF to PPM (or PNG) via poppler
  await run('pdftoppm', ['-png', pdfPath, ppmPrefix]);
  const files = (await fs.readdir(workDir)).filter((n) => n.startsWith('page-') && n.endsWith('.png')).sort();
  const outTexts = [];
  for (const fn of files) {
    const base = fn.replace(/\.png$/, '');
    const pngPath = path.join(workDir, fn);
    const txtPath = path.join(workDir, `${base}.txt`);
    await run('tesseract', [pngPath, path.join(workDir, base), '-l', 'deu']);
    const pageText = await fs.readFile(txtPath, 'utf8').catch(() => '');
    outTexts.push(pageText);
  }
  return outTexts.join('\n');
}

function extractOfferLines(raw) {
  // naive heuristic: keep non-empty trimmed lines; downstream can parse prices etc.
  return raw
    .split(/\r?\n/)
    .map((s) => s.trim().replace(/\s+/g, ' '))
    .filter((s) => s.length >= 2);
}

// ──────────────────────────────────────────────────────────────────────────────
(async () => {
  const args = parseArgs(process.argv);
  const supermarket = args.supermarket || '';
  const pdf = args.pdf || '';
  const from = args.from || '';
  const to = args.to || '';
  const out = args.out || '';

  if (!supermarket || !pdf || !from || !to || !out) {
    console.error('Usage: node ingest_pdf.mjs supermarket=<name> pdf=<path.pdf> from=YYYY-MM-DD to=YYYY-MM-DD out=<out.json>');
    process.exit(1);
  }

  // Check binaries presence (no auto-install)
  const pdftoppmBin = await which('pdftoppm');
  const tesseractBin = await which('tesseract');
  if (!pdftoppmBin || !tesseractBin) {
    console.error('\nMissing system tools. Please install on macOS:\n  brew install poppler   # provides pdftoppm\n  brew install tesseract # OCR\n');
    process.exit(2);
  }

  const pdfAbs = path.resolve(__dirname, pdf);
  if (!(await fs.pathExists(pdfAbs))) {
    console.error(`PDF not found: ${pdfAbs}`);
    process.exit(3);
  }

  const workDir = await fs.mkdtemp(path.join(os.tmpdir(), 'pdf_ocr_'));
  try {
    console.log(`🧩 Working directory: ${workDir}`);
    const fullText = await ocrPdfToText({ pdfPath: pdfAbs, workDir });
    const lines = extractOfferLines(fullText);

    const payload = {
      meta: {
        supermarket,
        sourcePdf: pdf,
        validFrom: from,
        validTo: to,
        generatedAt: new Date().toISOString(),
        host: os.hostname(),
      },
      text: {
        lines,
      },
      offers: [], // downstream can parse to structured offers
    };

    const outAbs = path.resolve(__dirname, out);
    await ensureOutDir(outAbs);
    await fs.writeJson(outAbs, payload, { spaces: 2 });
    console.log(`✅ Wrote: ${outAbs}`);
  } finally {
    // keep workDir for debugging; uncomment to cleanup automatically
    // await fs.remove(workDir).catch(() => {});
  }
})().catch((err) => {
  console.error('❌ Ingest failed:', err.message);
  process.exit(10);
});