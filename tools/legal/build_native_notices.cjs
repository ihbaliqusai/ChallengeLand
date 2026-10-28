const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const sourcesDir = path.join(__dirname, 'sources');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const components = read(path.join(sourcesDir, 'native-components.json')).components;
const raw = read(path.join(__dirname, 'artifact-notices.local.json'));
const sha = text => crypto.createHash('sha256').update(text).digest('hex');
const normalize = text => text.replace(/^\uFEFF/, '').replaceAll('\r\n', '\n').trim();
const evidencePath = path.join(sourcesDir, 'upstream-notices.json');
const evidence = fs.existsSync(evidencePath) ? read(evidencePath) : {};
const groups = new Map();
const embeddedByName = new Map();
function decodeLegalBytes(bytes) {
  try { return new TextDecoder('utf-8', { fatal: true }).decode(bytes); } catch (_) {}
  // A few upstream concatenated notices contain legacy Windows smart quotes
  // within otherwise UTF-8 text. Preserve those bytes without losing characters.
  let result = '';
  const legacy = new TextDecoder('windows-1252');
  for (let index = 0; index < bytes.length;) {
    const first = bytes[index];
    const width = first < 0x80 ? 1 : first >= 0xC2 && first <= 0xDF ? 2
      : first >= 0xE0 && first <= 0xEF ? 3 : first >= 0xF0 && first <= 0xF4 ? 4 : 0;
    const chunk = bytes.subarray(index, index + width);
    try {
      if (!width || chunk.length !== width) throw new Error('legacy');
      result += new TextDecoder('utf-8', { fatal: true }).decode(chunk);
      index += width;
    } catch (_) { result += legacy.decode(bytes.subarray(index, ++index)); }
  }
  return result;
}
function add(packages, text, source) {
  text = normalize(text);
  if (text.length < 100 || text.includes('\u0000')) throw new Error(`Invalid license text: ${source}`);
  const key = sha(text);
  if (!groups.has(key)) groups.set(key, { packages: new Set(), text, sources: new Set(), sha256: key });
  const group = groups.get(key);
  packages.forEach(name => group.packages.add(name));
  group.sources.add(source);
}
async function upstream(url) {
  if (!evidence[url]) {
    const response = await fetch(url, { signal: AbortSignal.timeout(20000) });
    if (!response.ok) throw new Error(`Could not fetch upstream license ${response.status}: ${url}`);
    const text = await response.text();
    evidence[url] = { sha256: sha(text), text };
  }
  return evidence[url].text;
}
function findEmbedded(name) {
  const entry = [...embeddedByName].find(([label]) => label.toLowerCase() === name.toLowerCase());
  if (!entry) throw new Error(`Missing embedded ${name} notice`);
  return entry[1];
}
function artifactSource(module, entry) {
  const component = components.find(x => x.id === module);
  return component?.source ? `${component.source}#embedded-${encodeURIComponent(entry)}` : `artifact:${module}!/${entry}`;
}
const esc = value => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
(async () => {
  // Preserve every body in vendor-supplied concatenated notices. Some shipped
  // JSON byte offsets are stale, so split by the actual indexed headings and
  // fall back to the complete original document if any heading is absent.
  for (const record of raw.filter(x => x.entry === 'third_party_licenses.txt')) {
    const metadata = raw.find(x => x.module === record.module && x.entry === 'third_party_licenses.json');
    const index = metadata ? JSON.parse(metadata.text) : {};
    const bytes = record.base64 ? Buffer.from(record.base64, 'base64') : Buffer.from(record.text, 'utf8');
    const original = decodeLegalBytes(bytes);
    const headings = Object.keys(index).map(name => {
      const heading = `\n\n${name}:\n\n`;
      const start = original.indexOf(heading);
      return { name, start, content: start + heading.length };
    }).sort((a, b) => a.start - b.start);
    if (headings.length && headings.every(x => x.start >= 0)
        && !original.slice(0, headings[0].start).trim()) {
      for (let i = 0; i < headings.length; i++) {
        const { name, content } = headings[i];
        const text = original.slice(content, headings[i + 1]?.start ?? original.length);
        const source = artifactSource(record.module, record.entry);
        add([name], text, source);
        if (!embeddedByName.has(name)) embeddedByName.set(name, { text, source });
      }
    } else {
      add([record.module], original, artifactSource(record.module, record.entry));
    }
  }
  for (const record of raw.filter(x => !x.entry.endsWith('/pom.xml')
      && x.entry !== 'third_party_licenses.txt' && x.entry !== 'third_party_licenses.json'
      && !x.entry.endsWith('.class'))) {
    add([record.module], record.text, artifactSource(record.module, record.entry));
  }

  const apacheUrl = 'https://www.apache.org/licenses/LICENSE-2.0.txt';
  const apache = await upstream(apacheUrl);
  const ringUrl = 'https://raw.githubusercontent.com/HotBitmapGG/RingProgressBar/8d7e892387045399584904722b572859aa342964/README.md';
  const ringText = (await upstream(ringUrl)).split('## License')[1];
  const picassoSource = 'https://raw.githubusercontent.com/square/picasso/picasso-parent-2.5.2/picasso/src/main/java/com/squareup/picasso/Picasso.java';
  const circleSource = 'https://raw.githubusercontent.com/hdodenhof/CircleImageView/v2.1.0/circleimageview/src/main/java/de/hdodenhof/circleimageview/CircleImageView.java';
  const sourceHeader = text => (text.match(/^\/\*([\s\S]*?)\*\//) || [])[1]?.replace(/^ \* ?/gm, '').trim();
  const overrides = {
    'com.github.HotBitmapGG:RingProgressBar:V1.2.2': { text: ringText + '\n\n' + apache, source: ringUrl },
    'com.squareup.picasso:picasso:2.5.2': { text: sourceHeader(await upstream(picassoSource)) + '\n\n' + apache, source: picassoSource },
    'de.hdodenhof:circleimageview:2.1.0': { text: sourceHeader(await upstream(circleSource)) + '\n\n' + await upstream('https://raw.githubusercontent.com/hdodenhof/CircleImageView/v2.1.0/LICENSE.txt'), source: circleSource },
    'org.reactivestreams:reactive-streams:1.0.4': { text: await upstream('https://raw.githubusercontent.com/reactive-streams/reactive-streams-jvm/v1.0.4/LICENSE'), source: 'https://raw.githubusercontent.com/reactive-streams/reactive-streams-jvm/v1.0.4/LICENSE' },
    'com.google.protobuf:protobuf-javalite:3.25.5': { text: await upstream('https://raw.githubusercontent.com/protocolbuffers/protobuf/v25.5/LICENSE'), source: 'https://raw.githubusercontent.com/protocolbuffers/protobuf/v25.5/LICENSE' },
  };
  const flutterLicense = fs.readFileSync('D:/flutter/LICENSE', 'utf8');
  const coverage = [];
  for (const component of components) {
    const labels = [component.id];
    if (component.name && !component.name.includes('${')) labels.push(component.name);
    let selected;
    if (overrides[component.id]) selected = overrides[component.id];
    else if (component.id.startsWith('io.flutter:')) selected = {
      text: flutterLicense, source: 'https://github.com/flutter/flutter/blob/3.32.8/LICENSE',
    };
    else if (component.licenses.some(l => /Apache/i.test(l.name))) selected = { text: apache, source: component.source };
    else if (component.licenses.some(l => /Android Software/i.test(l.name))) selected = findEmbedded('Android SDK Platforms');
    else if (component.id.startsWith('org.checkerframework:')) {
      const notice = raw.find(x => x.module === component.id && x.entry === 'META-INF/LICENSE.txt');
      selected = { text: notice.text, source: artifactSource(component.id, notice.entry) };
    } else if (component.id.startsWith('org.codehaus.mojo:animal-sniffer-annotations:')) selected = findEmbedded('Animal Sniffer');
    else if (component.id.startsWith('androidx.datastore:datastore-preferences-external-protobuf:')) selected = findEmbedded('Protocol Buffers');
    else if (component.licenses.some(l => /Play Core|Play Integrity/.test(l.name))) {
      const notice = raw.find(x => x.module === component.id && x.entry === 'LICENSE');
      selected = { text: notice.text, source: artifactSource(component.id, notice.entry) };
    } else throw new Error(`Unresolved runtime component: ${component.id}`);
    add(labels, selected.text, selected.source);
    coverage.push({ id: component.id, licenseNames: component.licenses.map(l => l.name),
      pom: component.source, noticeSource: selected.source, noticeSha256: sha(normalize(selected.text)) });
  }
  fs.writeFileSync(evidencePath, JSON.stringify(evidence, null, 2) + '\n');
  const entries = [...groups.values()].map(group => ({ packages: [...group.packages].sort(), text: group.text,
    source: [...group.sources].sort()[0], sources: [...group.sources].sort(), sha256: group.sha256 }))
    .sort((a, b) => a.packages[0].localeCompare(b.packages[0]));
  const manifest = { generatedAt: '2026-10-28', configuration: 'releaseRuntimeClasspath',
    componentCount: components.length, entries };
  const flutterOutput = path.join(root, 'assets/licenses');
  const nativeOutput = path.join(root, 'android/app/src/main/assets/licenses');
  fs.mkdirSync(flutterOutput, { recursive: true });
  fs.mkdirSync(nativeOutput, { recursive: true });
  const json = JSON.stringify(manifest, null, 2) + '\n';
  fs.writeFileSync(path.join(flutterOutput, 'third_party_notices.json'), json);
  const fonts = [['Baloo', 'Baloo-OFL.txt'], ['Noto Sans Arabic', 'NotoSansArabic-OFL.txt'], ['Barlow Condensed', 'BarlowCondensed-OFL.txt']]
    .map(([name, file]) => ({ packages: [name], text: fs.readFileSync(path.join(root, 'assets/fonts', file), 'utf8') }));
  const html = `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>تراخيص المكتبات والخطوط</title><style>body{font:16px/1.7 system-ui,sans-serif;margin:0;background:#10182d;color:#edf1fb;padding:20px}main{max-width:1000px;margin:auto}h1{color:#ffce73;font-size:24px}details{border:1px solid #3b4b64;border-radius:12px;padding:12px;margin:12px 0;background:#17243b}summary{cursor:pointer;overflow-wrap:anywhere}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:13px/1.6 monospace;direction:ltr;text-align:left}a{color:#93d5ff;overflow-wrap:anywhere}</style></head><body><main><h1>تراخيص المكتبات والخطوط</h1><p>النصوص الأصلية للرخص وإشعارات أصحابها متاحة دون اتصال بالإنترنت. لا تغير هذه الإشعارات ملكية التطبيق أو رخصة شيفرته.</p>${[...fonts, ...entries].map(entry => `<details><summary dir="auto">${entry.packages.map(esc).join(' · ')}</summary><pre>${esc(entry.text)}</pre>${entry.source?.startsWith('https://') ? `<p dir="ltr"><a href="${esc(entry.source)}">Source</a></p>` : ''}</details>`).join('\n')}</main></body></html>\n`;
  fs.writeFileSync(path.join(nativeOutput, 'index.html'), html);
  fs.writeFileSync(path.join(sourcesDir, 'native-license-coverage.json'), JSON.stringify({ generatedAt: '2026-10-28',
    componentCount: coverage.length, distinctNoticeCount: entries.length, coverage }, null, 2) + '\n');
  console.log(JSON.stringify({ components: components.length, distinctNotices: entries.length,
    manifestBytes: Buffer.byteLength(json), nativeHtmlBytes: Buffer.byteLength(html), coverageComplete: true }, null, 2));
})().catch(error => { console.error(error); process.exit(1); });
