"use strict";
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const root = path.resolve(__dirname, "../..");
const file = path.join(root, "assets/questions.json");
const original = fs.readFileSync(file, "utf8");
const backup = fs.readFileSync(path.join(__dirname, "second_pass_backup/assets__questions.json"), "utf8");
assert.equal(original, backup, "Apply only once, to the backed-up pre-review bank");
const questions = JSON.parse(original), changes = [];
function update(index, values, reason) {
  const before = { ...questions[index] };
  Object.assign(questions[index], values);
  changes.push({ index, reason, before, after: { ...questions[index] } });
}
update(506, { Q: "من الشاعر صاحب ديوان «الخمائل»؟", R: "إيليا أبو ماضي", W1: "أحمد شوقي", W2: "بدر شاكر السياب", W3: "أبو القاسم الشابي" }, "Make the poetry question independently answerable");
update(746, { Q: "ما اسم البهار العطري المصنوع من اللحاء الداخلي لأشجار جنس السيناموم؟" }, "Identify the bark spice without relying on options");
update(948, { Q: "ما الشكل الهندسي المستوي الذي تبعد جميع نقاط محيطه المسافة نفسها عن مركزه؟", Level: "1" }, "Remove subjective odd-one-out and use an easy tier");
update(953, { Q: "ما الكلمة التي تعني «غير آجل» وتستخدم في عبارة «خبر ...» للدلالة على خبر فوري؟" }, "Specify the intended synonym");
update(954, { Q: "ما الصفة التي تعني خفي المعنى أو صعب الفهم، وهي ضد «واضح»؟" }, "Specify the intended antonym");
update(955, { Q: "من بين نجار ومطرقة ومنشار وإزميل، ما الكلمة التي تدل على مهنة لا على أداة؟" }, "State the full comparison and distinguishing criterion");
update(957, { Q: "إلى أي طائفة من الفقاريات ينتمي الدولفين رغم أنه يعيش في الماء؟", R: "الثدييات", W1: "الأسماك", W2: "الزواحف", W3: "البرمائيات" }, "Replace misplaced sentence-logic item with an animal question");
update(958, { Q: "من بين جذر وساق وورقة ومحرك، ما الكلمة التي لا تدل على جزء من النبات؟" }, "State the full comparison and distinguishing criterion");
update(961, { Q: "في تشبيه «جناح إلى طائر مثل عجلة إلى ...»، ما وسيلة النقل ذات الأربع عجلات المقصودة؟", R: "سيارة", W1: "دراجة هوائية", W2: "سفينة", W3: "طائرة" }, "Replace a question with multiple valid part-whole options");
update(962, { Q: "ما مصدر الفعل «استخلص» الذي يدل على الوصول إلى نتيجة؟" }, "Specify a unique word rather than choosing a synonym from hidden options");
update(964, { Q: "من بين ذهب وفضة ونحاس وقطن، ما المادة التي تعد أليافًا نباتية لا فلزًا؟" }, "State the full comparison and distinguishing criterion");
update(971, { Q: "في العبارة «تحسن فهم الطالب لأنه ذاكر جيدًا»، ما سبب تحسن فهمه؟", R: "المذاكرة الجيدة", W1: "لون الكتاب", W2: "موقع الطاولة", W3: "شكل النافذة" }, "Ask for a specific cause with a concise answer");
update(993, { Q: "ما لون البطاقة التي يرفعها حكم كرة القدم للإشارة إلى طرد لاعب؟", R: "الأحمر", W1: "الأصفر", W2: "الأزرق", W3: "الأخضر" }, "Replace misplaced box-logic question with an easy sport question");
update(1040, { Q: "إذا قسمنا كل حد على 2، فما الحد التالي بعد 100، 50، 25؟ (اكتب العدد بالأرقام واستخدم النقطة للفاصلة العشرية)", Level: "1" }, "Make the sequence rule explicit and correct easy difficulty");
update(1145, { Level: "1" }, "Basic multiplication and addition belong in the easy tier");
update(1278, { Level: "4" }, "A two-variable substitution with a decimal result is medium difficulty");
update(1402, { Q: "ما باقي قسمة 7^2026 على 1000؟ (اكتب العدد بالأرقام)", R: "649", W1: "49", W2: "343", W3: "807" }, "Replace semantic duplicate of index 1271 with a hard modular-arithmetic question");
update(12218, { Q: "ما القيمة التقريبية للنسبة الذهبية φ إلى ثلاث منازل عشرية؟ (اكتب العدد بالأرقام واستخدم النقطة للفاصلة العشرية)" }, "Use the correct mathematical term and state precision");
update(12310, { Q: "في مثلث أطوال أضلاعه 5 و12 و13 سم، ما مساحته بالسنتيمتر المربع؟ (اكتب العدد بالأرقام)", R: "30", W1: "60", W2: "32.5", W3: "65", Level: "4" }, "Remove answer explanation and use medium geometry difficulty");
update(12312, { Q: "ما مجموع أول عشرة أعداد فردية موجبة؟ (اكتب العدد بالأرقام)", R: "100", Level: "4" }, "Shorten the answer and correct the difficulty");
update(12315, { Q: "كم حرفًا مختلفًا يتكرر مرتين في كلمة «قسطنطينية»؟ (اكتب العدد بالأرقام)", R: "3", W1: "1", W2: "2", W3: "4", Level: "1" }, "Constantinople is a city, and the question asks for a count");
update(12316, { Q: "ما النظير الجمعي للعدد 7؟ (اكتب العدد بالأرقام مع الإشارة إن وجدت)", Level: "1" }, "A basic additive inverse is easy");
update(12317, { Q: "ما المقلوب الضربي للعدد 7؟ (اكتب كسرًا باستخدام /)", Level: "1" }, "A basic reciprocal is easy and needs an input-format hint");
update(12346, { Level: "4" }, "The consecutive 3-4-5 triangle is medium rather than expert difficulty");
update(12362, { Q: "يوجد 100 مصباح مطفأ مرقم من 1 إلى 100. يمر 100 شخص بالترتيب، ويعكس كل شخص حالة المصابيح التي تقبل أرقامها القسمة على رقمه. كم مصباحًا يبقى مضاءً؟ (اكتب العدد بالأرقام)", R: "10", W1: "50", W2: "100", W3: "1" }, "Repair the previously truncated answer and state the full puzzle");
update(12394, { Q: "ما معامل x^6 في متسلسلة ماكلورين للدالة e^x؟ (اكتب كسرًا مبسطًا باستخدام /)", R: "1/720", W1: "1/120", W2: "1/5040", W3: "-1/720" }, "Keep expert calculus while making the answer practical to enter");
update(12395, { Q: "ما معامل x^7 في متسلسلة ماكلورين للدالة sin(x)؟ (اكتب كسرًا مبسطًا باستخدام / ومع الإشارة)", R: "-1/5040", W1: "1/5040", W2: "-1/720", W3: "1/120" }, "Keep expert calculus while making the answer practical to enter");
update(12396, { Q: "ما معامل x^8 في متسلسلة ماكلورين للدالة cos(x)؟ (اكتب كسرًا مبسطًا باستخدام /)", R: "1/40320", W1: "-1/40320", W2: "1/5040", W3: "-1/720" }, "Keep expert calculus while making the answer practical to enter");
for (const index of [736, 1494, 1712, 2023]) update(index, { Level: "4" }, "General trivia requires medium rather than expert knowledge");
for (const index of [12375, 12376]) {
  const q = questions[index];
  const values = Object.fromEntries(["R", "W1", "W2", "W3"].map(k => [k, q[k].split("=")[1].trim()]));
  values.Q = q.Q + " (اكتب العدد بالأرقام مع الإشارة إن وجدت)";
  update(index, values, "Use a short numeric Euler-characteristic answer rather than requiring a Greek symbol");
}

questions.forEach((q, index) => {
  let text = q.Q;
  if (/[a-z]/i.test(q.R) && /[ء-ي]/.test(q.R)) text = text.replace("(اكتب بالإنجليزية)", "(تتضمن الإجابة أحرفًا إنجليزية)");
  if (/^[\d٠-٩۰-۹]+(?:[.,٫][\d٠-٩۰-۹]+)?$/.test(q.R) && !/أرقام|ارقام|عدداً|رقماً/.test(text)) text += " (اكتب العدد بالأرقام واستخدم النقطة للفاصلة العشرية إن وجدت)";
  if (text !== q.Q) update(index, { Q: text }, "Clarify numeric or mixed-language answer input");
  if (q.Category === "خمن الأغنية") {
    const values = Object.fromEntries(["R", "W1", "W2", "W3"].map(k => [k, q[k].split(" - ")[0].trim()]));
    assert.equal(new Set(Object.values(values)).size, 4, `Song choices must remain distinct at ${index}`);
    values.Q = q.Q.replace("المقصودة من هذه الكلمات:", "المقصودة من معنى هذا التلميح:").replace(/[\u064b-\u0652\u0670\u0640]/g, "");
    update(index, values, "Keep the artist hint, remove heavy diacritics and shorten song answers to their titles");
  }
});
assert.equal(questions.length, JSON.parse(backup).length);
const indent = /\n( +)\{/.exec(original)?.[1].length || 2;
fs.writeFileSync(file, JSON.stringify(questions, null, indent) + (original.endsWith("\n") ? "\n" : ""));
fs.writeFileSync(path.join(__dirname, "second_pass_changes.json"), JSON.stringify(changes, null, 2) + "\n");
console.log(`Updated ${new Set(changes.map(c => c.index)).size} records; preserved ${questions.length} questions.`);
