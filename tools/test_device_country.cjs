const { mkdirSync, readFileSync, readdirSync, existsSync } = require('node:fs');
const { resolve, join, delimiter } = require('node:path');
const { execFileSync } = require('node:child_process');

const root = resolve(__dirname, '..');
const output = join(root, 'build', 'device-country-tests');
const properties = readFileSync(join(root, 'android/local.properties'), 'utf8');
const configuredSdk = properties.match(/^sdk\.dir=(.+)$/m)?.[1]
  .trim().replace(/\\\\/g, '\\').replace(/\\:/g, ':');
const sdk = process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT || configuredSdk;
if (!sdk) throw new Error('An Android SDK is required to compile DeviceCountry checks.');
const platforms = readdirSync(join(sdk, 'platforms'))
  .filter(name => /^android-\d+$/.test(name))
  .sort((left, right) => Number(right.slice(8)) - Number(left.slice(8)));
const androidJar = platforms.map(platform => join(sdk, 'platforms', platform, 'android.jar'))
  .find(existsSync);
if (!androidJar) throw new Error('No installed Android platform android.jar found.');

mkdirSync(output, { recursive: true });
const command = name => process.env.JAVA_HOME
  ? join(process.env.JAVA_HOME, 'bin', name + (process.platform === 'win32' ? '.exe' : '')) : name;
execFileSync(command('javac'), ['-encoding', 'UTF-8', '-cp', androidJar, '-d', output,
  join(root, 'android/app/src/main/java/com/Qi7bali/challengeland/DeviceCountry.java'),
  join(root, 'android/verification/DeviceCountryCheck.java')], { stdio: 'inherit' });
execFileSync(command('java'), ['-cp', [output, androidJar].join(delimiter),
  'com.qi7bali.landchallengeonline.DeviceCountryCheck'], { stdio: 'inherit' });
