"use strict";
const fs = require("node:fs"), path = require("node:path"), crypto = require("node:crypto");
const root = path.resolve(__dirname, "../../..");
const { summary, records } = require("./review_records.json");
const inventory = require("./inventory.json");
const questions = require("../../../assets/questions.json");
const byIndex = new Map(records.map(r => [r.index, r]));
const cell = text => String(text).replaceAll("|", "\\|").replace(/\r?\n/g, " ");
const actions = { confirmed: "أُبقي بعد التحقق", corrected: "صُحح أو اختُصر", replaced: "استُبدل" };
const images = inventory.media.map(index => {
  const r = byIndex.get(index), file = path.join(__dirname, "images", `${index}.jpg`);
  return { index, questionNumber: index + 1, url: r.after.Img, snapshot: `images/${index}.jpg`,
    sha256: crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex"),
    visuallyReviewed: true, action: r.action, reason: r.reason, question: r.after.Q, answer: r.after.R };
});
fs.writeFileSync(path.join(__dirname, "visual_review.json"), JSON.stringify({ date: "2026-10-21", images }, null, 2) + "\n");
const levelChanges = records.filter(r => r.before.Level !== r.after.Level);
const lines = [
  "# مراجعة الحالات المتبقية في بنك الأسئلة — 21 أكتوبر 2026",
  "",
  "انتهت مراجعة **215 سجلًا محددًا**: 123 إجابة طويلة، و77 سؤالًا مرشحًا لكشف الإجابة، و15 سؤال صورة. تغير **212 سجلًا**، وأُبقيت ثلاثة أسئلة صور كما هي بعد التحقق. بقي عدد البنك **15,427 سؤالًا**، وبقيت أسماء الحقول وأنواعها والتصنيفات كما هي.",
  "",
  "هذه مراجعة للحالات المحددة في التقرير السابق. لا تعني أن بقية البنك خضع لتحقق معرفي جديد سؤالًا بسؤال.",
  "",
  "## الإجابات الطويلة — 123 من 123",
  "",
  "أصبحت جميع الإجابات الصحيحة في هذه القائمة لا تتجاوز **30 حرفًا**. روجعت فرضية السؤال ومعناه قبل الاختصار. عندما كانت الصياغة تعتمد على وصف إنشائي أو مشهد غير مسند، استُخدم بديل محدد من التصنيف نفسه والمستوى نفسه، مثل بيانات طاقم المسلسل وأدوار الشخصيات.",
  "",
  "التقسيم: 12 في «ركز شوي»، و33 في «مسلسلات عربية»، و57 في Friends، و21 في الأنمي. صُححت فروق فعلية مثل اتجاه هدية السوار في Friends، وهوية من ادعى الاحتضار لاسترداد الخاتم، ووصف شريط زينة الكريسماس، والخلط بين العدد الوافر والعدد شبه التام.",
  "",
  "| رقم السؤال | التصنيف | النتيجة | الإجابة الحالية | المصدر |",
  "|---|---|---|---|---|",
];
function sourceLink(r) {
  const source = r.sources[0];
  return source.startsWith("https://") ? `[مرجع](${source})` : source.startsWith("visual:") ? "فحص بصري للصورة" : "تعريف مباشر أو حساب موثق";
}
for (const index of inventory.long) { const r = byIndex.get(index); lines.push(`| ${index + 1} | ${cell(r.after.Category)} | ${actions[r.action]} | ${cell(r.after.R)} | ${sourceLink(r)} |`); }
lines.push("", "## الأسئلة التي تذكر الإجابة — 77 من 77", "",
  "أعيدت صياغة الحالات الـ77 لإزالة الإجابة من السؤال. عولجت أيضًا أخطاء في بعض المقتطفات الغنائية؛ مثل «رق الحبيب» و«يا ظالمني» و«أقبل الليل» و«طيري يا طيارة». وفي سؤال «أغدا ألقاك» كان الاسم الصحيح واردًا بين الخيارات الخاطئة؛ صُحح الجواب والخيار المرافق. استُبدل سؤال عن أغنية لم يمكن توثيق عنوانها وكلماتها بسؤال موثق عن لحن تسجيل قديم لأم كلثوم.", "",
  "أوصاف «زووم» و«وضح شوي» لا ترتبط أصلًا بملفات صور في المشروع؛ أصبحت تصرح بأنها وصف مكتوب، مع الاحتفاظ بالتفاصيل التي تكفي للحل. صُححت معلومات محددة: حجر رشيد من الغرانوديوريت، والكيوي عاجز عن الطيران وله أجنحة صغيرة، وساغرادا فاميليا بازيليكا وليست كاتدرائية.", "",
  "| رقم السؤال | التصنيف | الإجابة الحالية | المصدر |", "|---|---|---|---|");
for (const index of inventory.reveals) { const r = byIndex.get(index); lines.push(`| ${index + 1} | ${cell(r.after.Category)} | ${cell(r.after.R)} | ${sourceLink(r)} |`); }
lines.push("", "## الصور — 15 من 15", "",
  "نُزّلت الملفات الفعلية من روابط Img وفُتحت جميعها بصريًا. أُبقيت 3 أسئلة دون تغيير، وحُدد المقصود في 4 أسئلة، واستُبدل المطلوب داخل الصورة نفسها في 8 أسئلة لتجنب العد المحجوب أو الألوان المتقاربة أو استنتاج اسم برنامج من نص صغير. لم تُنشأ صور جديدة ولم تتغير الروابط.", "",
  "| رقم السؤال | النتيجة | السؤال الحالي | الجواب |", "|---|---|---|---|");
for (const index of inventory.media) { const r = byIndex.get(index); lines.push(`| ${index + 1} | ${actions[r.action]} | ${cell(r.after.Q)} | ${cell(r.after.R)} |`); }
lines.push("", "الصور ما زالت ضمن تصنيف «دقة ملاحظة» المخفي أصلًا؛ لم يُفعّل التصنيف ولم يتغير سلوك إتاحته. تثبت بصمات SHA-256 في `tools/audit/focused_review/visual_review.json` أي ملفات جرى فحصها، لأن نجاح رابط خارجي وحده لا يثبت صحة الإجابة.", "",
  "## الأعداد والحفظ", "",
  `- ${summary.reviewed} سجلًا روجع، و${summary.changed} سجلًا تغير، و${summary.replaced} بديلًا مسجلًا بدل الأسئلة غير المناسبة أو غير المسندة. لا حذف لسجلات.`,
  "- لم يتغير حقل Category لأي سؤال. نُقل Level في 8 حالات واضحة الصعوبة، مع الالتزام بالمصفوفة المطلوبة. البدائل الكاملة احتفظت بالمستوى والتصنيف الأصليين.",
  "- نسخة البداية محفوظة في `tools/audit/focused_review/assets__questions.json.backup`، ومعها نسختا الخادم قبل هذه الجولة.",
  "- سجل شامل لكل حالة، نصها الأصلي والجديد وسبب القرار ومصدره: `tools/audit/focused_review/review_records.json`.", "",
  "| رقم السؤال | Level السابق | Level الحالي |", "|---|---|---|");
for (const r of levelChanges) lines.push(`| ${r.index + 1} | ${r.before.Level} | ${r.after.Level} |`);
lines.push("", "## التحقق وحدود المصادر", "",
  "المصادر تتنوع بين الجهات الأصلية والمراجع العلمية والمتاحف، وبيانات طواقم elCinema، ونصوص حلقات Friends، وموسوعات الأنمي التي يديرها الجمهور. الأخيرة مصادر ثانوية، وليست شهادات رسمية من أصحاب الأعمال. حُفظ مصدر كل قرار، واستُبدلت الأوصاف الإنشائية التي تعذر إسنادها بدل اعتمادها كحقائق.", "",
  "بعض المواقع تمنع التنزيل الآلي المباشر أو تعرض صيانة مؤقتة؛ لا يُعامل HTTP 200 أو 403 بوصفه اختبارًا لصحة المعلومة. استُخدمت صفحات التصفح ونتائجها المفهرسة عند الحاجة. مثلًا كانت موسوعة Digimon تحت الصيانة أثناء الفحص، لكن نتيجة صفحتها الرسمية المفهرسة تذكر اسم المطرقة. الحسابات المنطقية والعددية فُحصت أيضًا بسكربت `verify_math.cjs`.", "",
  "الفحوصات بعد التعديل: صفر أخطاء في بنية سجلات البنك، ونسختا الخادم مطابقتان للمصدر. نجح 99 اختبار خادم، و16 اختبار حملة وتصنيفات تشمل المراحل الـ100، و61,726 حالة لمطابقة الإجابات في Android والتطبيع على الخادم. نجح بناء Android Debug، وتطابقت بصمة بنك الأسئلة داخل APK مع المصدر الحالي. التفاصيل في `tools/audit/focused_review/validation.json`.", "",
  "لم يُنشر شيء تلقائيًا إلى Firebase أو المتجر في هذه الجولة.", "");
fs.writeFileSync(path.join(root, "docs/QUESTION_BANK_FOCUSED_REVIEW_AR.md"), lines.join("\n"));
console.log("Wrote the full 215-record report and 15-image visual manifest.");
