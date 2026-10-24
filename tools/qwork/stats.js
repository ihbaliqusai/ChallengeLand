// Builds reclassified.json from classified.tsv + originals, then prints a
// per-category easy/medium/hard table. Tier: 0-2 easy(200), 3-5 med(400), 6-8 hard(600).
const fs = require('fs');
const orig = JSON.parse(fs.readFileSync('questions.orig.json', 'utf8'));
const rows = fs.readFileSync('classified.tsv', 'utf8').split('\n').filter(Boolean);

const ASSET_CATS = fs.readdirSync('../../android/app/src/main/assets/categories')
  .filter(f => f.endsWith('.png')).map(f => f.replace(/\.png$/, '').trim());

const tier = lv => { const n = parseInt(lv) || 0; return n <= 2 ? 0 : n <= 5 ? 1 : 2; };

let extra = [];
if (fs.existsSync('new_questions.json')) {
  extra = JSON.parse(fs.readFileSync('new_questions.json', 'utf8'));
}

const out = [];
for (const line of rows) {
  const [id, level, , newCat, , ] = line.split('\t');
  const q = orig[+id];
  out.push({ Level: String(level), Q: q.Q, R: q.R, W1: q.W1, W2: q.W2, W3: q.W3, Category: newCat });
}
for (const q of extra) out.push(q);

fs.writeFileSync('reclassified.json', JSON.stringify(out, null, 2), 'utf8');

const stat = {};
for (const c of ASSET_CATS) stat[c] = [0, 0, 0];
for (const q of out) {
  if (!stat[q.Category]) stat[q.Category] = [0, 0, 0];
  stat[q.Category][tier(q.Level)]++;
}

console.log('category'.padEnd(20), 'easy', 'med', 'hard', 'total', ' NEED');
let totalQ = 0, missingCats = [];
const order = Object.entries(stat).sort((a, b) => (b[1][0]+b[1][1]+b[1][2]) - (a[1][0]+a[1][1]+a[1][2]));
for (const [c, [e, m, h]] of order) {
  const t = e + m + h; totalQ += t;
  if (t === 0) missingCats.push(c);
  // flag categories that can't comfortably build a 6-cell column (need >=2 per tier)
  const need = (e < 2 || m < 2 || h < 2 || t < 30) ? '  <-- needs more' : '';
  console.log(c.padEnd(20), String(e).padStart(4), String(m).padStart(3), String(h).padStart(4), String(t).padStart(5), need);
}
console.log('\nTOTAL questions:', totalQ, '| categories:', order.length, '| empty:', missingCats.join(', ') || 'none');
