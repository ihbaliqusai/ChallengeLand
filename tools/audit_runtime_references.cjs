// Read-only source reachability audit. Candidates always need manual review:
// platform callbacks, XML inflation, reflection and channel routes are entrypoints.
// node tools/audit_runtime_references.cjs [--check] [report.json]
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const walk = directory => fs.readdirSync(directory, {withFileTypes: true}).flatMap(entry =>
  entry.isDirectory() ? walk(path.join(directory, entry.name)) : [path.join(directory, entry.name)]);
const relative = file => path.relative(root, file).replaceAll('\\', '/');
const read = file => fs.readFileSync(file, 'utf8');
const native = [...walk(path.join(root, 'android/app/src/main/java')),
  ...walk(path.join(root, 'android/app/src/main/kotlin'))].filter(file => /\.(java|kt)$/.test(file));
const xml = walk(path.join(root, 'android/app/src/main/res')).filter(file => file.endsWith('.xml'));
const manifest = read(path.join(root, 'android/app/src/main/AndroidManifest.xml'));
const nativeText = new Map(native.map(file => [file, read(file)]));
const xmlText = xml.map(file => read(file).replace(/tools:context="[^"]*"/g, ''));
const nativeDependencies = new Map(native.map(file => [file, []]));
const nativeRoots = new Set();
// Keep generated Flutter registration: the embedding discovers it reflectively.
const frameworkEntrypoints = new Set(['GeneratedPluginRegistrant']);
const nativeCandidates = native.flatMap(file => {
  const name = path.basename(file).replace(/\.(java|kt)$/, '');
  const identifier = new RegExp('\\b' + name + '\\b');
  const references = native.filter(other => other !== file && identifier.test(nativeText.get(other)));
  for (const caller of references) nativeDependencies.get(caller).push(file);
  const xmlReference = xmlText.some(content => identifier.test(content));
  // A manifest-only activity can be obsolete, whereas services and receivers
  // are called by Android/Firebase without a Java caller. Report both for review.
  const systemComponent = new RegExp('<(?:service|receiver|provider)\\b[^>]*android:name="\\.' + name + '"').test(manifest);
  if (name === 'MainActivity' || frameworkEntrypoints.has(name) || systemComponent || xmlReference) nativeRoots.add(file);
  if (references.length || xmlReference || frameworkEntrypoints.has(name)) return [];
  if (systemComponent) return [];
  return [{file: relative(file), name, declaredInManifest: identifier.test(manifest)}];
});
const nativeReachable = new Set();
function visitNative(file) {
  if (nativeReachable.has(file)) return;
  nativeReachable.add(file);
  for (const dependency of nativeDependencies.get(file) || []) visitNative(dependency);
}
for (const entrypoint of nativeRoots) visitNative(entrypoint);
const dart = walk(path.join(root, 'lib')).filter(file => file.endsWith('.dart'));
const dependencies = new Map(dart.map(file => [file,
  [...read(file).matchAll(/\b(?:import|export|part)\s+['"]([^'"]+)['"]/g)].map(match => match[1])
    .filter(uri => !uri.startsWith('dart:') && (!uri.startsWith('package:') || uri.startsWith('package:challenge_land/')))
    .map(uri => uri.startsWith('package:challenge_land/')
      ? path.join(root, 'lib', uri.slice('package:challenge_land/'.length))
      : path.resolve(path.dirname(file), uri))]));
const reachable = new Set();
function visit(file) {
  if (reachable.has(file)) return;
  reachable.add(file);
  for (const dependency of dependencies.get(file) || []) visit(dependency);
}
visit(path.join(root, 'lib/main.dart'));
const report = {nativeSourceFiles: native.length, nativeCandidates,
  nativeUnreachable: native.filter(file => !nativeReachable.has(file)).map(relative),
  dartSourceFiles: dart.length, dartUnreachable: dart.filter(file => !reachable.has(file)).map(relative)};
const destination = process.argv.slice(2).find(argument => !argument.startsWith('--'));
if (destination) fs.writeFileSync(path.resolve(destination), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report, null, 2));
if (process.argv.includes('--check') && (nativeCandidates.length || report.nativeUnreachable.length || report.dartUnreachable.length)) process.exitCode = 1;
