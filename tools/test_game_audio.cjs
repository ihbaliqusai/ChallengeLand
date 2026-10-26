const { mkdirSync, readFileSync, readdirSync, writeFileSync } = require('node:fs');
const { resolve, join } = require('node:path');
const { execFileSync } = require('node:child_process');

const root = resolve(__dirname, '..');
const output = join(root, 'build', 'game-audio-tests');
const source = join(root, 'android/app/src/main/java/com/Qi7bali/challengeland');
const verification = join(root, 'android/verification');
const stubs = join(verification, 'audio_stubs');
mkdirSync(output, { recursive: true });
const files = [
  join(source, 'GameSoundController.java'),
  join(source, 'GameAudioProfile.java'),
  join(verification, 'GameSoundControllerCheck.java'),
  join(verification, 'GameAudioProfileCheck.java'),
];
const walk = directory => readdirSync(directory, { withFileTypes: true }).flatMap(entry =>
  entry.isDirectory() ? walk(join(directory, entry.name)) : [join(directory, entry.name)]);
files.push(...walk(stubs).filter(file => file.endsWith('.java')));

// Stand in for Android's generated R while compiling the real controller/profile.
const resources = [...new Set(files.flatMap(file =>
  [...readFileSync(file, 'utf8').matchAll(/R\.raw\.([a-z0-9_]+)/g)].map(match => match[1])))].sort();
const resourceFile = join(output, 'R.java');
writeFileSync(resourceFile, `package com.qi7bali.landchallengeonline;\npublic final class R {\n`
  + `  public static final class raw {\n`
  + resources.map((name, index) => `    public static final int ${name} = ${index + 1};`).join('\n')
  + '\n  }\n}\n');
files.push(resourceFile);

const command = name => process.env.JAVA_HOME
  ? join(process.env.JAVA_HOME, 'bin', name + (process.platform === 'win32' ? '.exe' : '')) : name;
execFileSync(command('javac'), ['-encoding', 'UTF-8', '-d', output, ...files], { stdio: 'inherit' });
for (const check of ['GameSoundControllerCheck', 'GameAudioProfileCheck']) {
  execFileSync(command('java'), ['-cp', output, `com.qi7bali.landchallengeonline.${check}`], { stdio: 'inherit' });
}
