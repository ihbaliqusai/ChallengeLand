// Final builder: apply reclassification, re-level the ألغاز puzzle block by type,
// append authored questions, drop duplicates, write questions.json + a report.
const fs = require('fs');

const ASSETS = '../../android/app/src/main/assets';
// The runtime loads the Flutter bundle copy (../../assets/questions.json) first, with the
// Android assets copy as fallback, so we write the same authoritative file to BOTH.
const OUT_FILES = ['../../assets/questions.json', ASSETS + '/questions.json'];
const orig = JSON.parse(fs.readFileSync('questions.root.json', 'utf8'));
const rows = fs.readFileSync('classified.tsv', 'utf8').split('\n').filter(Boolean);
const extra = [];
for (const f of fs.readdirSync('.').filter(f => /^new_questions.*\.json$/.test(f)).sort()) {
  extra.push(...JSON.parse(fs.readFileSync(f, 'utf8')));
}
console.log('authored question files merged:', extra.length, 'questions');

const ASSET_CATS = fs.readdirSync(ASSETS + '/categories')
  .filter(f => f.endsWith('.png')).map(f => f.replace(/\.png$/, '').trim());

const norm = s => (s || '')
  .replace(/[ً-ْ]/g, '').replace(/[أإآ]/g, 'ا').replace(/ة/g, 'ه')
  .replace(/ى/g, 'ي').replace(/[؟?!.،,\s]+/g, ' ').trim();

// Heuristic difficulty for a riddle/logic puzzle based on its wording.
function relevelRiddle(q) {
  const n = norm(q.Q);
  // multi-constraint ordering, truth-teller logic, advanced math/CS -> hard
  if (/(قبل .* وبعد|بعد .* وقبل|الترتيب الصحيح|عباره واحده فقط|عبارتان صحيحتان|واحد فقط (صادق|صحيح)|من الصادق|من الاول|من في (الوسط|المنتصف)|نتيجه مؤكده|نتيجه صحيحه|لا يمكن الجزم|فرضيه|حدسيه|مبرهنه|مشكله التوقف|اي ترتيب صحيح|اي موضع|المركز (الجديد|الثالث|الخامس)|دالا?ه|اوازكي|اوكازاكي)/.test(n)) return '6';
  // arithmetic word problems, sequences, ratios, rates -> medium
  if (/(سرعه|كم يقطع|عمال|ينجز|ينجزون|نسبه|% |بالمئه|المتوسط|متوسط|محيط|مساح[هة]|اعمار|عمر (الاب|سلمى|ريم)|ضعف|ثلث|ربع|اذا كان ثمن|اذا كان سعر|سعر|دينار|لتر|كم يساوي|العدد التالي|النمط|متتالي|باقي قسم|مربع العدد|اقل ب|اكثر ب|كم (يوم|دقيق|ساع)|الساعه|بعد .* يوم|بعد .* دقيق|التشابه|اكمل العلاقه)/.test(n)) return '4';
  // classic short "what is the thing" riddles -> easy
  return '1';
}

const out = [];
for (const line of rows) {
  const [id, level, , newCat] = line.split('\t');
  const q = orig[+id];
  let lv = String(level);
  if (newCat === 'ألغاز') lv = relevelRiddle(q);
  out.push({ Level: lv, Q: q.Q, R: q.R, W1: q.W1, W2: q.W2, W3: q.W3, Category: newCat });
}
for (const q of extra) out.push({ Level: String(q.Level), Q: q.Q, R: q.R, W1: q.W1, W2: q.W2, W3: q.W3, Category: q.Category });

// De-duplicate by normalized question text (keep first).
const seen = new Set();
const dedup = [];
let dropped = 0;
for (const q of out) {
  const k = norm(q.Q);
  if (seen.has(k)) { dropped++; continue; }
  seen.add(k); dedup.push(q);
}

// Validate categories all map to an existing artwork file.
const badCat = dedup.filter(q => !ASSET_CATS.includes(q.Category));
if (badCat.length) {
  console.log('!! questions with unknown category:', [...new Set(badCat.map(q => q.Category))]);
}

for (const out of OUT_FILES) fs.writeFileSync(out, JSON.stringify(dedup, null, 2), 'utf8');

const tier = lv => { const n = parseInt(lv) || 0; return n <= 2 ? 0 : n <= 5 ? 1 : 2; };
const stat = {};
for (const c of ASSET_CATS) stat[c] = [0, 0, 0];
for (const q of dedup) stat[q.Category][tier(q.Level)]++;

console.log('Wrote', dedup.length, 'questions (dropped', dropped, 'duplicates).\n');
console.log('category'.padEnd(22), 'easy', 'med', 'hard', 'total', 'flag');
const order = Object.entries(stat).sort((a, b) => (b[1][0]+b[1][1]+b[1][2]) - (a[1][0]+a[1][1]+a[1][2]));
const report = [];
for (const [c, [e, m, h]] of order) {
  const t = e + m + h;
  const flag = (e < 2 || m < 2 || h < 2 || t < 30) ? 'LOW' : 'ok';
  console.log(c.padEnd(22), String(e).padStart(4), String(m).padStart(3), String(h).padStart(4), String(t).padStart(5), '', flag);
  report.push({ category: c, easy: e, medium: m, hard: h, total: t });
}
fs.writeFileSync('report.json', JSON.stringify(report, null, 2), 'utf8');
console.log('\nTOTAL:', dedup.length);
