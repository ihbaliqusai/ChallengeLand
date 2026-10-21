// Read-only inventory of shipped Flutter assets and native Android resources.
// Usage: node tools/audit_app_size.cjs [report.json]
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const shared = JSON.parse(fs.readFileSync(path.join(__dirname, 'shared_assets.json'), 'utf8'));
const relative = p => path.relative(root, p).split(path.sep).join('/');
function walk(directory) {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(file) : [file];
  });
}
const manifest = fs.readFileSync(path.join(root, 'pubspec.yaml'), 'utf8');
const declarations = [...manifest.matchAll(/^\s+-\s+(?:asset:\s+)?(assets\/[^\r\n]+)$/gm)]
  .map(match => match[1].trim());
const shipped = new Set();
for (const entry of declarations) {
  const source = path.join(root, entry);
  if (entry.endsWith('/')) {
    // Flutter directory declarations include immediate files, not descendants.
    for (const item of fs.readdirSync(source, { withFileTypes: true })) {
      if (item.isFile()) shipped.add(path.join(source, item.name));
    }
  } else if (fs.existsSync(source)) shipped.add(source);
}
const dart = walk(path.join(root, 'lib')).filter(p => p.endsWith('.dart'));
const literals = dart.flatMap(file => {
  const text = fs.readFileSync(file, 'utf8');
  return [...text.matchAll(/['"](assets\/[^'"\r\n]+)['"]/g)]
    .map(match => ({ pattern: match[1], source: relative(file) }));
});
function matches(pattern, asset) {
  const parts = pattern.split(/\$\{[^}]+\}|\$[A-Za-z_]\w*/);
  const expression = parts.map(p => p.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('.*');
  return new RegExp(`^${expression}$`).test(asset);
}
function info(file) {
  const asset = relative(file);
  const references = literals.filter(item => matches(item.pattern, asset)).map(item => item.source);
  if (/assets\/fonts\/.*\.ttf$/.test(asset)) references.push('pubspec.yaml: fonts');
  if (asset === 'assets/fonts/NotoSansArabic-OFL.txt') references.push('required font license');
  return { path: asset, bytes: fs.statSync(file).size,
    references };
}
function duplicates(files) {
  const groups = new Map();
  for (const file of files) {
    const data = fs.readFileSync(file);
    const hash = crypto.createHash('sha256').update(data).digest('hex');
    if (!groups.has(hash)) groups.set(hash, []);
    groups.get(hash).push({ path: relative(file), bytes: data.length });
  }
  return [...groups.values()].filter(group => group.length > 1)
    .map(files => ({ avoidableBytes: files[0].bytes * (files.length - 1), files }))
    .sort((a, b) => b.avoidableBytes - a.avoidableBytes);
}
const files = [...shipped].map(info).sort((a, b) => b.bytes - a.bytes);
const androidAssets = walk(path.join(root, 'android/app/src/main/assets'));
const androidResources = walk(path.join(root, 'android/app/src/main/res'));
const report = {
  generatedAt: new Date().toISOString(),
  flutter: { count: files.length, bytes: files.reduce((sum, f) => sum + f.bytes, 0),
    sharedAssets: shared,
    files, noLiteralReferenceCandidates: files.filter(f => !f.references.length),
    missingLiteralFiles: literals.filter(item => !item.pattern.includes('$') &&
      !fs.existsSync(path.join(root, item.pattern))),
    missingRuntimeAssets: literals.filter(item => !item.pattern.includes('$') &&
      fs.existsSync(path.join(root, item.pattern)) &&
      fs.statSync(path.join(root, item.pattern)).isFile() &&
      !shipped.has(path.join(root, item.pattern)) && !shared[item.pattern]),
    unbundledAssets: walk(path.join(root, 'assets')).filter(f => !shipped.has(f)).map(info),
    duplicates: duplicates([...shipped]) },
  native: { assetsBytes: androidAssets.reduce((s, f) => s + fs.statSync(f).size, 0),
    resourcesBytes: androidResources.reduce((s, f) => s + fs.statSync(f).size, 0),
    duplicates: duplicates([...androidAssets, ...androidResources]),
    crossFlutterDuplicates: duplicates([...shipped, ...androidAssets, ...androidResources])
      .filter(group => group.files.some(f => f.path.startsWith('assets/')) &&
        group.files.some(f => f.path.startsWith('android/'))) },
};
const reportArgument = process.argv.slice(2).find(arg => !arg.startsWith('--'));
if (reportArgument) {
  const output = path.resolve(root, reportArgument);
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, JSON.stringify(report, null, 2));
}
console.log(JSON.stringify({
  flutterCount: report.flutter.count, flutterBytes: report.flutter.bytes,
  candidates: report.flutter.noLiteralReferenceCandidates,
  nativeDuplicates: report.native.duplicates,
  crossCopyBytes: report.native.crossFlutterDuplicates.reduce((s, g) => s + g.avoidableBytes, 0),
}, null, 2));
if (process.argv.includes('--check')) {
  const invalid = files.filter(file => /\.(md|psd|bak)$/i.test(file.path));
  if (report.flutter.missingLiteralFiles.length || report.flutter.missingRuntimeAssets.length ||
      report.flutter.noLiteralReferenceCandidates.length || invalid.length ||
      report.native.crossFlutterDuplicates.length) {
    console.error('Asset bundle review failed:', JSON.stringify({
      missing: report.flutter.missingLiteralFiles,
      missingFromBundle: report.flutter.missingRuntimeAssets,
      unreferenced: report.flutter.noLiteralReferenceCandidates,
      nonRuntimeFiles: invalid,
      duplicateSharedAssets: report.native.crossFlutterDuplicates,
    }, null, 2));
    process.exitCode = 1;
  }
}
