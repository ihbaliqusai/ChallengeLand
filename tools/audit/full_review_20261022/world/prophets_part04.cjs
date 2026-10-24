"use strict";
const fs = require("node:fs");
const path = require("node:path");
const w = require("./work.cjs");
const E = (i, c, r, s = [], k = "correction") => w.edit(i, c, r, k, s);

// --- Stories of the Prophets Batch 4 & 5 (Category 07 Batches 0210 & 0280: indices 7737 - 8828) ---
// This finalizes Category 07 (قصص الأنبياء) to 100% completion.

// Replace duplicate Jalut with Tasbeeh of mountains in evening and morning
E(7740, {
  Q: "من النبي الذي سخر الله له الجبال يسبحن بالعشي والإشراق؟",
  R: "داود عليه السلام",
  W1: "سليمان عليه السلام",
  W2: "يوسف عليه السلام",
  W3: "موسى عليه السلام",
  Level: "2"
}, "استبدال تكرار قتل جالوت بتسبيح الجبال بالعشي والإشراق في سورة ص");

E(7741, { Level: "2" }, "فهم سليمان لحكم الحرث والغنم معرفة شائعة", [], "difficulty");
E(7742, { Level: "2" }, "دعاء زكريا لذرية طيبة معرفة شائعة", [], "difficulty");
E(7743, { Level: "2" }, "يحيى سيداً وحصوراً معرفة شائعة", [], "difficulty");

// Fix prompt leak in 7750 (Yunus was listed inside the prompt)
E(7750, {
  Q: "من النبي المذكور في سورة الأنعام مع إسماعيل واليسع ولوط في قوله تعالى «وكلاً فضلنا على العالمين»؟",
  R: "يونس عليه السلام",
  W1: "إدريس عليه السلام",
  W2: "شعيب عليه السلام",
  W3: "هود عليه السلام",
  Level: "7"
}, "إزالة تسريب الجواب يونس من نص السؤال وإعادة الصياغة بدقة");

E(7751, { Level: "7" }, "ذو الكفل مع إدريس وإسماعيل في سورة الأنبياء مستوى متقدم", [], "difficulty");
E(7752, { Level: "2" }, "إدريس صديقاً نبياً ورفع مكاناً علياً معرفة شائعة", [], "difficulty");
E(7753, { Level: "1" }, "شعيب وإيفاء الكيل والميزان معرفة بديهية", [], "difficulty");
E(7754, { Level: "1" }, "صالح والناقة معرفة بديهية", [], "difficulty");
E(7758, { Level: "1" }, "هود أخو عاد معرفة بديهية", [], "difficulty");
E(7759, { Level: "1" }, "صالح أخو ثمود معرفة بديهية", [], "difficulty");
E(7761, { Level: "1" }, "إسماعيل الذبيح معرفة بديهية عامة", [], "difficulty");

// Replace duplicate 8780 (Salih's camel) with the miracle details
E(8780, {
  Q: "ما المعجزة الخارقة التي أخرجها الله لقوم ثمود من الصخرة بدعاء نبيهم صالح عليه السلام؟",
  R: "ناقة عشار",
  W1: "عصا تتحول إلى حية",
  W2: "مائدة من السماء",
  W3: "طوفان عظيم",
  Level: "1"
}, "استبدال تكرار سؤال صالح بالمعجزة المحددة وخروج الناقة من الصخرة");

E(8782, { Level: "1" }, "لوط وقومه معرفة بديهية", [], "difficulty");
E(8791, { Level: "2" }, "نداء الملائكة لزكريا وهو قائم يصلي في المحراب معرفة شائعة", [], "difficulty");
E(8792, { Level: "2" }, "تسمية يحيى ولم يجعل له من قبل سمياً معرفة شائعة", [], "difficulty");

// Replace duplicate 8794 (Ruh al-Qudus) with speaking in the cradle
E(8794, {
  Q: "من النبي الذي أنطقه الله في المهد ليبرئ أمه الطاهرة مريم عليها السلام؟",
  R: "عيسى عليه السلام",
  W1: "يحيى عليه السلام",
  W2: "موسى عليه السلام",
  W3: "إبراهيم عليه السلام",
  Level: "1"
}, "استبدال التكرار اللفظي لروح القدس بكلام عيسى في المهد دفاعاً عن أمه");

// Replace duplicate 8795 with the greatest miracle
E(8795, {
  Q: "ما المعجزة الخالدة الكبرى التي أيد الله بها خاتم الأنبياء محمدًا صلى الله عليه وسلم؟",
  R: "القرآن الكريم",
  W1: "انشقاق البحر",
  W2: "إحياء الموتى",
  W3: "الناقة العشار",
  Level: "1"
}, "استبدال التكرار اللفظي لسؤال إنزال القرآن بالسؤال عن المعجزة الخالدة");

E(8797, { Level: "1" }, "هود وقوم عاد معرفة بديهية", [], "difficulty");
E(8798, { Level: "1" }, "صالح وقوم ثمود معرفة بديهية", [], "difficulty");
E(8799, { Level: "2" }, "قصة ضيوف لوط عليه السلام معرفة شائعة", [], "difficulty");
E(8801, { Level: "2" }, "إسماعيل صادق الوعد معرفة شائعة", [], "difficulty");
E(8803, { Level: "1" }, "وصية يعقوب لبنيه ألا يدخلوا من باب واحد معرفة بديهية", [], "difficulty");
E(8806, { Level: "1" }, "شعيب ومدين وإيفاء الكيل معرفة بديهية", [], "difficulty");

// Replace duplicate 8808 with Staff of Moses
E(8808, {
  Q: "ما الآية التي تحولت فيها عصا موسى عليه السلام أمام سحرة فرعون لتلقف ما يأفكون؟",
  R: "ثعبان مبين",
  W1: "طائر من طين",
  W2: "ناقة عظيمة",
  W3: "ريح عاصف",
  Level: "1"
}, "استبدال تكرار شق البحر بآية العصا وتلقف سحر السحرة");

E(8811, { Level: "2" }, "داود الملك والحكمة معرفة شائعة", [], "difficulty");
E(8812, { Level: "2" }, "حكم سليمان في الحرث معرفة شائعة", [], "difficulty");

// Replace duplicate 8813 (wind) with Hoopoe of Solomon
E(8813, {
  Q: "ما الطائر الذي تفقد سليمان عليه السلام غيابه ثم أتاه بنبأ يقين عن مملكة سبأ؟",
  R: "الهدهد",
  W1: "الغراب",
  W2: "الحمامة",
  W3: "الصقر",
  Level: "1"
}, "استبدال تكرار تسخير الريح بقصة الهدهد في سورة النمل");

E(8814, { Level: "2" }, "إلياس وصنم بعل معرفة شائعة", [], "difficulty");

// Fix prompt leak in 8815
E(8815, {
  Q: "من النبي الذي خصه الله بالذكر مع يونس ولوط وإسماعيل وفضلهم جميعاً على العالمين في سورة الأنعام؟",
  R: "اليسع عليه السلام",
  W1: "إلياس عليه السلام",
  W2: "يحيى عليه السلام",
  W3: "زكريا عليه السلام",
  Level: "7"
}, "إزالة تسريب اليسع من نص السؤال وإعادة الصياغة");

E(8816, { Level: "7" }, "ذو الكفل مع إدريس وإسماعيل من الصابرين مستوى متقدم", [], "difficulty");
E(8818, { Level: "2" }, "رد أهل أيوب ومثلهم معهم معرفة شائعة", [], "difficulty");

// Replace duplicate 8819 (Zechariah sponsoring Maryam) with 3 days of silence
E(8819, {
  Q: "كم يومًا جعل الله آية لزكريا عليه السلام ألا يكلم الناس إلا رمزًا في سورة آل عمران؟",
  R: "ثلاثة أيام",
  W1: "سبعة أيام",
  W2: "عشرة أيام",
  W3: "أربعين يومًا",
  Level: "2"
}, "استبدال تكرار كفالة مريم بآية الأيام الثلاثة لزكريا في آل عمران");

E(8820, { Level: "2" }, "يحيى والحكم صبياً وأخذ الكتاب بقوة معرفة شائعة", [], "difficulty");

// --- Category 07 Batch 0280 (indices 8822 - 8828) ---
E(8825, { Level: "2" }, "دعاء لوط بالنجاة من عمل قومه معرفة شائعة", [], "difficulty");

// --- Mark all reviewed indices in category_07_0210.jsonl and category_07_0280.jsonl ---
const rec0210 = fs.readFileSync(path.join(__dirname, "category_07_0210.jsonl"), "utf8").trim().split(/\r?\n/).map(JSON.parse);
for (const x of rec0210) w.out.reviewedIndices.push(x.index);

const rec0280 = fs.readFileSync(path.join(__dirname, "category_07_0280.jsonl"), "utf8").trim().split(/\r?\n/).map(JSON.parse);
for (const x of rec0280) w.out.reviewedIndices.push(x.index);

w.out.reviewedIndices = [...new Set(w.out.reviewedIndices)].sort((a, b) => a - b);
w.save();
console.log(JSON.stringify({ reviewed: w.out.reviewedIndices.length, edits: w.out.edits.length, unresolved: w.out.unresolved.length }));
