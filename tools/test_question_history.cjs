// The production Java selector and identity run without Firebase or an Android device.
const { mkdirSync, writeFileSync } = require('node:fs');
const { resolve, join } = require('node:path');
const { execFileSync } = require('node:child_process');
const { questionKey } = require('../functions/src/question_identity');
const root = resolve(__dirname, '..');
const output = join(root, 'build/question-history-tests');
mkdirSync(output, { recursive: true });
const bank = [...require('../assets/questions.json'),
  { Q: 'مَا عَاصِمَةُ إِيطَالْيَا؟', Category: 'test', Level: '0' },
  { Q: 'ما نتيجة ٢ + ٣؟', Category: 'test', Level: '0' },
  { Q: 'خمن الفيلم: 🐼 + 🥋 + 🍜', Category: 'test', Level: '0' },
  { Q: '𝟠 + １ = ؟', Category: 'test', Level: '0' },
];
const b64 = value => Buffer.from(String(value || ''), 'utf8').toString('base64');
const fixture = join(output, 'identities.tsv');
writeFileSync(fixture, bank.map(q => [questionKey(q), b64(q.Q), b64(q.Img), b64(q.Category), q.Level || '0',
  ...(q.ClubPath || []).map(b64)].join('\t')).join('\n'));
const jdk = process.env.JAVA_HOME;
const command = name => jdk ? join(jdk, 'bin', name + (process.platform === 'win32' ? '.exe' : '')) : name;
const native = join(root, 'android/app/src/main/java/com/Qi7bali/challengeland');
execFileSync(command('javac'), ['-encoding', 'UTF-8', '-d', output,
  ...['Question.java', 'QuestionIdentity.java', 'QuestionSelection.java', 'CategoryConfig.java', 'CampaignBoardRules.java'].map(name => join(native, name)),
  join(__dirname, 'question_history/QuestionSelectionTest.java')], { stdio: 'inherit' });
execFileSync(command('java'), ['-cp', output, 'com.qi7bali.landchallengeonline.QuestionSelectionTest', fixture], { stdio: 'inherit' });
