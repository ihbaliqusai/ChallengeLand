// Pure Java regression suite: no production Firebase connection or Android device needed.
const { mkdirSync } = require('node:fs');
const { resolve, join } = require('node:path');
const { execFileSync } = require('node:child_process');
const root = resolve(__dirname, '..');
const output = join(root, 'build', 'online-duel-tests');
mkdirSync(output, { recursive: true });
const jdk = process.env.JAVA_HOME;
const command = name => jdk ? join(jdk, 'bin', name + (process.platform === 'win32' ? '.exe' : '')) : name;
const native = join(root, 'android/app/src/main/java/com/Qi7bali/challengeland');
execFileSync(command('javac'), ['-encoding', 'UTF-8', '-d', output,
  join(native, 'OnlineDuelState.java'), join(native, 'OnlineMatchmakingState.java'),
  join(__dirname, 'online_duel/OnlineDuelStateTest.java')], { stdio: 'inherit' });
execFileSync(command('java'), ['-cp', output,
  'com.qi7bali.landchallengeonline.OnlineDuelStateTest'], { stdio: 'inherit' });
