const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const sources = path.join(__dirname, 'sources');
fs.mkdirSync(sources, { recursive: true });
const read = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const inventory = read(path.join(__dirname, 'runtime-license-inventory.local.json'));
const embedded = read(path.join(__dirname, 'artifact-notices.local.json'));
const cachePath = path.join(sources, 'native-poms.json');
const cache = fs.existsSync(cachePath) ? read(cachePath) : {};
const sha = text => crypto.createHash('sha256').update(text).digest('hex');
const clean = text => String(text || '').replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
  .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').trim();
const field = (xml, name) => clean((xml.match(new RegExp(`<${name}>([\\s\\S]*?)<\\/${name}>`)) || [])[1]);
const repos = module => module.group === 'io.flutter' ? ['https://storage.googleapis.com/download.flutter.io']
  : module.group.startsWith('com.github.') ? ['https://jitpack.io']
  : module.group.startsWith('androidx.') || module.group.startsWith('com.android.')
    || module.group.startsWith('com.google.android.') || module.group === 'com.google.firebase'
    ? ['https://dl.google.com/dl/android/maven2', 'https://repo.maven.apache.org/maven2']
    : ['https://repo.maven.apache.org/maven2', 'https://dl.google.com/dl/android/maven2'];
async function pom(module) {
  const id = `${module.group}:${module.name}:${module.version}`;
  if (cache[id]) return cache[id];
  const relative = `${module.group.replaceAll('.', '/')}/${module.name}/${module.version}/${module.name}-${module.version}.pom`;
  for (const repo of repos(module)) {
    const url = `${repo}/${relative}`;
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(20000) });
      if (response.ok) {
        const text = await response.text();
        cache[id] = { url, sha256: sha(text), text };
        return cache[id];
      }
    } catch (_) {}
  }
  const local = embedded.find(e => e.module === id && e.entry.endsWith('/pom.xml'));
  if (local) return cache[id] = { url: `artifact:${id}!/${local.entry}`, sha256: sha(local.text), text: local.text };
  return { url: '', text: '', missing: true };
}
async function metadata(module, visited = new Set()) {
  const id = `${module.group}:${module.name}:${module.version}`;
  if (visited.has(id)) return { error: 'POM parent cycle' };
  visited.add(id);
  const source = await pom(module);
  const parentXml = (source.text.match(/<parent>([\s\S]*?)<\/parent>/) || [])[1];
  const licensesXml = (source.text.match(/<licenses>([\s\S]*?)<\/licenses>/) || [])[1];
  const licenses = [...String(licensesXml || '').matchAll(/<license>([\s\S]*?)<\/license>/g)]
    .map(match => ({ name: field(match[1], 'name'), url: field(match[1], 'url') }));
  let inherited;
  if (!licenses.length && parentXml) {
    inherited = await metadata({ group: field(parentXml, 'groupId'), name: field(parentXml, 'artifactId'), version: field(parentXml, 'version') }, visited);
  }
  return { id, source: source.url, pomSha256: source.sha256, name: field(source.text.replace(/<parent>[\s\S]*?<\/parent>/, ''), 'name'),
    licenses: licenses.length ? licenses : inherited?.licenses || [],
    inheritedFrom: licenses.length ? undefined : inherited?.id, missing: source.missing || undefined };
}
(async () => {
  const results = [];
  let next = 0;
  await Promise.all(Array.from({ length: 10 }, async () => {
    while (next < inventory.modules.length) {
      const module = inventory.modules[next++];
      results.push(await metadata(module));
    }
  }));
  fs.writeFileSync(cachePath, JSON.stringify(cache, null, 2) + '\n');
  results.sort((a, b) => a.id.localeCompare(b.id));
  fs.writeFileSync(path.join(sources, 'native-components.json'), JSON.stringify({ configuration: inventory.configuration, components: results }, null, 2) + '\n');
  console.log(JSON.stringify({ components: results.length, missing: results.filter(x => x.missing || !x.licenses.length),
    licenseTypes: [...new Map(results.flatMap(x => x.licenses).map(x => [x.name, x])).values()] }, null, 2));
})().catch(error => { console.error(error); process.exit(1); });
