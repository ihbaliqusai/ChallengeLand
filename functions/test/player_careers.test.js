const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname,'../..');
const read = p=>JSON.parse(fs.readFileSync(path.join(root,p),'utf8'));
const reviewed = read('tools/player_careers_reviewed.json');
const bank = read('assets/questions.json').filter(q=>q.Category==='مسيرة لاعب');
const { tierForLevel } = require('../src/question_tiers');

test('every career question is a unique complete reviewed route in both game banks',()=>{
  assert.equal(bank.length,300);
  assert.equal(bank.length,reviewed.length);
  assert.equal(new Set(bank.map(q=>q.R)).size,bank.length);
  assert.equal(new Set(bank.map(q=>q.Q)).size,bank.length);
  assert.deepEqual(read('assets/questions_player_career.json'),bank);
  const server = read('functions/src/original_stake_questions.json').filter(q=>q.category==='مسيرة لاعب');
  assert.equal(server.length,bank.length);
  for (const player of reviewed) {
    const q = bank.find(q=>q.R===player.name);
    assert.deepEqual(q.ClubPath,player.clubs,player.name);
    assert.equal(q.Q,player.clubs.join(' ⬅️ '),player.name);
    assert.ok(player.sources.length>0,player.name);
    assert.equal(new Set([q.R,q.W1,q.W2,q.W3]).size,4,player.name);
    assert.ok(!q.Img,player.name);
    assert.deepEqual(server.find(s=>s.answers[0]===player.name),{
      category:q.Category,text:q.Q,answers:[q.R,q.W1,q.W2,q.W3],level:q.Level,img:'',clubPath:q.ClubPath
    });
  }
});

test('career distractors share real clubs and use the strongest available overlaps',()=>{
  const players = new Map(reviewed.map(p=>[p.name,p]));
  for (const q of bank) {
    const clubs = new Set(q.ClubPath);
    const overlap = player=>new Set(player.clubs.filter(club=>clubs.has(club))).size;
    const selected = [q.W1,q.W2,q.W3].map(name=>{
      const player = players.get(name);
      assert.ok(player,`${q.R}: unreviewed distractor ${name}`);
      const count = overlap(player);
      assert.ok(count>=1,`${q.R}: ${name} has no shared club`);
      return count;
    });
    // A one-club option must never displace an available two/three-club option.
    const available = reviewed.filter(p=>p.name!==q.R).map(overlap);
    for (const minimum of new Set(available)) {
      if (minimum<2) continue;
      assert.equal(selected.filter(n=>n>=minimum).length,
        Math.min(3,available.filter(n=>n>=minimum).length),
        `${q.R}: prefer distractors sharing at least ${minimum} distinct clubs`);
    }
  }
});

test('Finidi George options include Kanu and Luque instead of unrelated stars',()=>{
  const finidi = reviewed.find(p=>p.page==='Finidi George');
  const q = bank.find(q=>q.R===finidi.name);
  const options = new Set([q.W1,q.W2,q.W3]);
  for (const page of ['Nwankwo Kanu','Albert Luque']) {
    assert.ok(options.has(reviewed.find(p=>p.page===page).name),page);
  }
  for (const page of ['Ronaldinho','Ángel Di María','Harry Kane']) {
    assert.ok(!options.has(reviewed.find(p=>p.page===page).name),page);
  }
});

test('career category adds 227 distinct players and contains 100 questions per points tier',()=>{
  const original = read('docs/player_career_review/source_careers.json');
  const originalNames = new Set(original.map(p=>p.name));
  assert.equal(originalNames.size,73);
  assert.equal(reviewed.filter(p=>!originalNames.has(p.name)).length,227);
  assert.equal(new Set(reviewed.map(p=>p.page)).size,300);
  for (const [tier,points] of [200,400,600].entries()) {
    assert.equal(bank.filter(q=>tierForLevel(q.Level)===tier).length,100,`${points} points`);
    assert.equal(reviewed.filter(p=>p.points===points).length,100);
    for (const p of reviewed.filter(p=>p.points===points)) {
      assert.equal(tierForLevel(bank.find(q=>q.R===p.name).Level),tier,p.name);
    }
  }
});

test('playing history retains real returns and excludes clubs without first-team appearances',()=>{
  const career = name=>reviewed.find(p=>p.name===name).clubs;
  assert.deepEqual(career('كريستيانو رونالدو'),['سبورتنغ لشبونة','مانشستر يونايتد','ريال مدريد','يوفنتوس','مانشستر يونايتد','النصر']);
  assert.equal(career('ديفيد بيكهام').filter(c=>c==='ميلان').length,2);
  assert.equal(career('ديفيد بيكهام').filter(c=>c==='لوس أنجلوس غالاكسي').length,3);
  assert.ok(career('ديفيد بيكهام').includes('بريستون نورث إند'));
  assert.equal(career('محمد صلاح')[0],'المقاولون العرب');
  assert.equal(career('هاري كين')[0],'ليتون أورينت');
  assert.equal(career('هاري كين').filter(c=>c==='توتنهام هوتسبير').length,3);
  assert.ok(career('المهدي بن عطية').includes('لوريان'));
  assert.ok(!career('المهدي بن عطية').includes('مارسيليا'));
  assert.ok(!career('بيير إيميريك أوباميانغ').includes('ميلان'));
  assert.ok(!career('ياسين بونو').includes('أتلتيكو مدريد'));
});

test('new career questions include playing returns, cup appearances and senior amateur clubs',()=>{
  const career = page=>reviewed.find(p=>p.page===page).clubsEnglish;
  assert.equal(career('Hernán Crespo').filter(c=>c==='Chelsea').length,2);
  assert.equal(career('Dida (footballer, born 1973)').filter(c=>c==='AC Milan').length,2);
  assert.equal(career('Johan Cruyff').filter(c=>c==='Washington Diplomats').length,2);
  assert.equal(career('Frank Lampard')[0],'Swansea City');
  assert.deepEqual(career('Philipp Lahm'),['Bayern Munich','VfB Stuttgart','Bayern Munich']);
  assert.equal(career('Marco Streller')[0],'Arlesheim');
  assert.equal(career('Marco Streller').filter(c=>c==='Basel').length,4);
  assert.ok(career('Lothar Matthäus').includes('Lokomotive Leipzig'));
  assert.ok(career('Blerim Džemaili').includes('Bolton Wanderers'));
  assert.ok(career('John Obi Mikel').includes('Kuwait SC'));
  assert.ok(career('Anthony Annan').includes('DJK Arminia Lirich'));
  assert.ok(!career('Roberto Carlos').includes('Atlético Mineiro'));
  assert.ok(!career('Frank Rijkaard').includes('Sporting CP'));
  assert.equal(career('Miroslav Klose')[0],'SG Blaubach-Diedelkopf');
  for (const page of ['Jaap Stam','Marc Overmars','Joris Mathijsen']) assert.ok(career(page).includes('Willem II'),page);
  for (const p of reviewed) {
    assert.ok(!p.clubsEnglish.some(c=>c!=='Willem II'&&/\b(?:II|B|C|U21|U23)$/.test(c)),p.name);
    assert.ok(!p.clubs.some((c,i,a)=>i>0&&c===a[i-1]),p.name);
  }
});
