const { mkdirSync } = require('node:fs');
const { resolve, join } = require('node:path');
const { execFileSync } = require('node:child_process');
const root = resolve(__dirname, '..');
const output = join(root, 'build', 'background-answer-tests');
mkdirSync(output, { recursive: true });
const command = name => process.env.JAVA_HOME
  ? join(process.env.JAVA_HOME, 'bin', name + (process.platform === 'win32' ? '.exe' : '')) : name;
execFileSync(command('javac'), ['-encoding', 'UTF-8', '-d', output,
  join(root, 'android/app/src/main/java/com/Qi7bali/challengeland/BackgroundAnswerPolicy.java'),
  join(root, 'android/verification/BackgroundAnswerPolicyCheck.java')], { stdio: 'inherit' });
execFileSync(command('java'), ['-cp', output,
  'com.qi7bali.landchallengeonline.BackgroundAnswerPolicyCheck'], { stdio: 'inherit' });
