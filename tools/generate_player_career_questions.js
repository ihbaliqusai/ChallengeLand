const fs = require('node:fs');
const careers = JSON.parse(fs.readFileSync('tools/player_careers_reviewed.json','utf8'));
// One complete playing career per player; never generate partial subsequences.
const ordered = [...careers].sort((a,b)=>a.points-b.points||a.clubs.length-b.clubs.length);
const levelsForPoints = {200:['0','1','2'],400:['4','5','6'],600:['3','7','8']};
const counters = {200:0,400:0,600:0};
if (careers.length!==300) throw new Error('Expected 300 reviewed careers');
for (const points of [200,400,600]) if (careers.filter(p=>p.points===points).length!==100) throw new Error(`Expected 100 careers at ${points} points`);
const questions = ordered.map(career=>{
  const levels = levelsForPoints[career.points];
  if (!levels) throw new Error(`Invalid points: ${career.name}`);
  const options = ordered.filter(player=>player.name!==career.name)
    .sort((a,b)=>Math.abs(a.clubs.length-career.clubs.length)-Math.abs(b.clubs.length-career.clubs.length));
  if (career.clubs.length<2 || !career.sources.length) throw new Error(`Incomplete review: ${career.name}`);
  return {
    Level: levels[counters[career.points]++%3],
    Q: career.clubs.join(' ⬅️ '),
    R: career.name,
    W1: options[0].name, W2: options[1].name, W3: options[2].name,
    Category: 'مسيرة لاعب',
    ClubPath: career.clubs,
  };
});
if (new Set(questions.map(q=>q.Q)).size!==questions.length) throw new Error('Ambiguous career route');
fs.writeFileSync('assets/questions_player_career.json',JSON.stringify(questions,null,2)+'\n');
const lines = ['# مراجعة مسيرة لاعب','',
  'تاريخ المراجعة: 23 أكتوبر 2026. المجموع 300 سؤال كامل لـ300 لاعب مختلف: 73 سؤالاً سابقاً و227 سؤالاً جديداً. لكل فئة من فئات 200 و400 و600 نقطة مئة سؤال بالضبط.','',
  'المعيار المعتمد: الأندية التي شارك اللاعب مع فريقها الأول في مباريات رسمية، بما فيها الإعارات والعودة للعب بعد الإعارة. تُستبعد فرق الشباب والرديف والعقود بلا مشاركة رسمية والمباريات الودية. لا يُكرر النادي إذا تحول الانتقال من إعارة إلى شراء دون مغادرة فعلية.','',
  'ملاحظات: يبدأ مودريتش بزرينيسكي، وكين بليتون أورينت، ودي بروينه بجينك ثم بريمن ثم تشيلسي. تُستبعد مرحلة ميلان من مسيرة أوباميانغ لعدم المشاركة الرسمية. أُدرجت لوريان في مسيرة بن عطية بسبب مشاركته في كأس الرابطة رغم عدم اللعب بالدوري. أُدرج الشمال لمحرز بعد توثيق مشاركته في 17 أكتوبر 2026. لا يُدرج رافينا لرونالدينيو أو شا تين لدافيد سيلفا قبل ثبوت أول مشاركة رسمية؛ انتقال اللاعب لا يكفي وفق المعيار الذي اختاره المستخدم.','',
  'المصادر أدناه مخصصة للمراجعة وليست جزءاً من نص السؤال في اللعبة. انتقالات اللاعبين المستمرين تحتاج تحديثاً لاحقاً بعد هذا التاريخ.',''];
for (const player of careers) {
  lines.push(`## ${player.name} — ${player.points} نقطة`,'',player.clubs.join(' ⬅️ '),'',...player.sources.map((url,i)=>`- [مصدر ${i+1}](${url})`),'');
}
fs.writeFileSync('docs/PLAYER_CAREER_REVIEW_AR.md',lines.join('\n')+'\n');
console.log(`Wrote ${questions.length} unique full-career questions and the source report.`);
