const fs = require('node:fs');

const bankPath = 'assets/questions.json';
const careerPath = 'assets/questions_player_career.json';
const bank = JSON.parse(fs.readFileSync(bankPath, 'utf8'));
const career = JSON.parse(fs.readFileSync(careerPath, 'utf8'));
const reviewed = JSON.parse(fs.readFileSync('tools/player_careers_reviewed.json', 'utf8'));
if (career.length !== reviewed.length) throw new Error('Career bank does not match the reviewed players');
const cleanBank = bank.filter(question => question.Category !== 'مسيرة لاعب');
fs.writeFileSync(bankPath, JSON.stringify([...cleanBank, ...career], null, 2) + '\n');
console.log(`Merged ${career.length} career questions into ${bankPath}.`);
// Keep the authoritative friend challenge bank on the same complete routes.
const serverPath = 'functions/src/original_stake_questions.json';
const server = JSON.parse(fs.readFileSync(serverPath,'utf8'));
const original = server.filter(question=>question.category!=='مسيرة لاعب');
const rows = career.map(q=>({category:q.Category,text:q.Q,answers:[q.R,q.W1,q.W2,q.W3],level:q.Level,img:'',clubPath:q.ClubPath}));
fs.writeFileSync(serverPath,JSON.stringify([...original,...rows]));
console.log(`Synced ${rows.length} career questions to the server bank.`);
