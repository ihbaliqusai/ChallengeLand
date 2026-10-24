const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const policy = JSON.parse(fs.readFileSync(path.join(__dirname, 'legal/privacy_policy_ar.json'), 'utf8'));
const check = process.argv.includes('--check');
const html = (value) => String(value).replace(/[&<>"']/g, (char) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
})[char]);
const dart = (value) => JSON.stringify(value).replace(/\$/g, '\\$');
const sections = [...policy.sections, { id: 'credits', ...policy.credits }];
if (new Set(sections.map((section) => section.id)).size !== sections.length) {
  throw new Error('Policy section IDs must be unique');
}
for (const section of sections) {
  if (!/^[a-z-]+$/.test(section.id) || !section.title || !section.paragraphs.length) {
    throw new Error(`Incomplete policy section: ${section.id}`);
  }
  for (const link of section.links) {
    if (new URL(link.url).protocol !== 'https:' || !link.label) throw new Error('Invalid policy link');
  }
}

function dartSection(section) {
  return `PrivacyPolicySection(\n      id: ${dart(section.id)},\n      title: ${dart(section.title)},\n      paragraphs: [\n${section.paragraphs.map((text) => `        ${dart(text)},`).join('\n')}\n      ],\n      links: [\n${section.links.map((link) => `        PrivacyPolicyLink(${dart(link.label)}, ${dart(link.url)}),`).join('\n')}\n      ],\n    )`;
}

const dartOutput = `// GENERATED FILE. Edit tools/legal/privacy_policy_ar.json and run\n// node tools/generate_privacy_policy.cjs to update every policy copy.\n\nclass PrivacyPolicyLink {\n  const PrivacyPolicyLink(this.label, this.url);\n  final String label;\n  final String url;\n}\n\nclass PrivacyPolicySection {\n  const PrivacyPolicySection({\n    required this.id,\n    required this.title,\n    required this.paragraphs,\n    required this.links,\n  });\n  final String id;\n  final String title;\n  final List<String> paragraphs;\n  final List<PrivacyPolicyLink> links;\n}\n\nabstract final class PrivacyPolicyContent {\n${['version', 'updatedAt', 'appName', 'publisher', 'contactEmail', 'policyUrl', 'deletionUrl', 'introduction'].map((key) => `  static const ${key} = ${dart(policy[key])};`).join('\n')}\n  static const highlights = <({String title, String text})>[\n${policy.highlights.map((item) => `    (title: ${dart(item.title)}, text: ${dart(item.text)}),`).join('\n')}\n  ];\n  static const sections = <PrivacyPolicySection>[\n${policy.sections.map((section) => `    ${dartSection(section)},`).join('\n')}\n  ];\n  static const credits = ${dartSection(sections.at(-1))};\n}\n`;

const css = `
:root{color-scheme:light;--ink:#202438;--muted:#62677b;--purple:#6c43df;--line:#e5e4ee;--paper:#fff;--bg:#f5f5fa}
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:24px}body{margin:0;background:var(--bg);color:var(--ink);font-family:Tahoma,"Segoe UI",Arial,sans-serif;line-height:1.9}a{color:var(--purple);text-underline-offset:4px}a:focus-visible{outline:3px solid #aa91ef;outline-offset:5px}header{background:#171b31;color:white;padding:40px max(24px,calc((100vw - 1180px)/2))}header p{max-width:820px;color:#d7d7e6}h1{font-size:clamp(28px,4vw,44px);line-height:1.5;margin:12px 0}h2{font-size:23px;line-height:1.6;margin:0 0 16px}h3{font-size:17px;margin:0 0 8px}.eyebrow{color:#cbb8ff;font-size:14px}.meta{display:flex;flex-wrap:wrap;gap:10px 26px;color:#c9ccdf;font-size:14px}.layout{max-width:1180px;padding:32px 24px 64px;margin:auto;display:grid;grid-template-columns:250px minmax(0,1fr);gap:28px;align-items:start}.toc{position:sticky;top:20px;max-height:calc(100vh - 40px);overflow:auto;padding:20px;background:var(--paper);border:1px solid var(--line);border-radius:16px}.toc a{display:block;text-decoration:none;font-size:14px;padding:6px 0}.toc h2{font-size:17px}.content{min-width:0}.section,.summary,.contact{padding:28px;background:var(--paper);border:1px solid var(--line);border-radius:16px;margin-bottom:20px}.section{scroll-margin-top:24px}.section p{font-size:16px;margin:0 0 15px}.section p:last-child{margin-bottom:0}.number{font-size:13px;font-weight:700;color:var(--purple);display:block;margin-bottom:6px}.summary{display:grid;gap:20px}.summary p{font-size:14px;color:var(--muted);margin:0}.links{display:flex;flex-wrap:wrap;gap:10px 20px;border-top:1px solid var(--line);padding-top:14px;margin-top:18px;font-size:14px}.contact{border-inline-start:4px solid var(--purple)}.button{display:inline-block;text-decoration:none;background:var(--purple);color:#fff;border-radius:10px;padding:9px 18px;margin:6px 0}.muted{color:var(--muted);font-size:14px}.email{direction:ltr;unicode-bidi:isolate;overflow-wrap:anywhere}.back{color:#d9cbff}.steps{padding-inline-start:24px}.steps li{margin-bottom:12px}footer{font-size:13px;color:var(--muted);margin-top:28px}
@media(min-width:1000px){.summary{grid-template-columns:repeat(3,minmax(0,1fr))}}@media(max-width:780px){header{padding:28px 20px}.layout{grid-template-columns:1fr;padding:20px 14px 40px;gap:16px}.toc{position:static;max-height:none}.toc a{display:inline-block;margin-inline-end:12px;padding:5px 0}.section,.summary,.contact{padding:22px}h2{font-size:21px}}@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}@media print{body{background:white;color:black}header{background:white;color:black;padding:0}.meta,header p{color:#444}.layout{display:block;padding:0;max-width:none}.toc,.back,.button{display:none}.section,.summary,.contact{border:0;padding:12px 0;margin-bottom:12px;break-inside:avoid}.links a{overflow-wrap:anywhere}h1{font-size:28px}}
`;

function page(title, description, body, toc = '') {
  return `<!DOCTYPE html>\n<!-- Generated from tools/legal/privacy_policy_ar.json. -->\n<html lang="ar" dir="rtl">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n<meta name="description" content="${html(description)}">\n<title>${html(title)} | ${html(policy.appName)}</title>\n<style>${css}</style>\n</head>\n<body>\n<header><span class="eyebrow">${html(policy.publisher)}</span><h1>${html(title)}</h1><p>${html(description)}</p><div class="meta"><span>آخر تحديث: <time datetime="${html(policy.version)}">${html(policy.updatedAt)}</time></span><span>الإصدار: ${html(policy.version)}</span><span class="email">${html(policy.contactEmail)}</span></div></header>\n<main class="layout">${toc}<div class="content">${body}<footer>${html(policy.appName)} · ${html(policy.publisher)} · ${html(policy.updatedAt)}</footer></div></main>\n</body>\n</html>\n`;
}

const toc = `<nav class="toc" aria-label="فهرس سياسة الخصوصية"><h2>محتويات السياسة</h2>${sections.map((section, index) => `<a href="#${html(section.id)}">${index + 1}. ${html(section.title)}</a>`).join('')}<a href="${html(policy.deletionUrl)}">طلب حذف الحساب</a></nav>`;
const summary = `<aside class="summary" aria-label="نظرة سريعة">${policy.highlights.map((item) => `<div><h3>${html(item.title)}</h3><p>${html(item.text)}</p></div>`).join('')}</aside>`;
const sectionHtml = sections.map((section, index) => `<section class="section" id="${html(section.id)}" aria-labelledby="title-${html(section.id)}"><span class="number">${section.id === 'credits' ? 'ملحق مستقل' : `القسم ${index + 1}`}</span><h2 id="title-${html(section.id)}">${html(section.title)}</h2>${section.paragraphs.map((text) => `<p>${html(text)}</p>`).join('')}${section.links.length ? `<div class="links">${section.links.map((link) => `<a href="${html(link.url)}" rel="noopener noreferrer">${html(link.label)}</a>`).join('')}</div>` : ''}</section>`).join('\n');
const contact = `<aside class="contact"><h2>لديك طلب بخصوص بياناتك؟</h2><p>راسل فريق الخصوصية من البريد المرتبط بالحساب إن أمكن، واذكر نوع الطلب ومعرّف اللاعب. لا ترسل كلمات المرور أو رموز التحقق.</p><a class="button" href="mailto:${html(policy.contactEmail)}?subject=${encodeURIComponent('طلب خصوصية — أرض التحدي')}">مراسلة فريق الخصوصية</a> <a href="${html(policy.deletionUrl)}">حذف الحساب والبيانات</a></aside>`;
const privacyHtml = page('سياسة الخصوصية', policy.introduction, summary + sectionHtml + contact, toc);
const deleteBody = `<section class="section"><h2>من داخل اللعبة</h2><ol class="steps"><li>افتح أرض التحدي ثم افتح القائمة.</li><li>انتقل إلى «الإعدادات» ثم «حذف الحساب».</li><li>أكّد هويتك إذا طُلب ذلك، ثم أكّد طلب الحذف.</li></ol><p>حذف الحساب قد يزيل تقدمك ومقتنياتك المرتبطة به ويكون غير قابل للتراجع. ولا يحذف حساب Google نفسه أو يلغي اشتراك Google Play.</p></section><section class="section"><h2>طلب الحذف من خارج اللعبة</h2><p>يمكنك إرسال الطلب حتى إذا لم يعد التطبيق مثبتًا. استخدم البريد المرتبط بالحساب إن أمكن، واذكر معرّف اللاعب أو اسمه ونوع البيانات المطلوب حذفها.</p><p>عنوان الرسالة المقترح: «طلب حذف حساب أرض التحدي». ولحذف بعض البيانات فقط، وضّح ذلك في الرسالة.</p><p>قد نطلب معلومات محدودة للتحقق من ملكية الحساب، ونرد وفق المهل القانونية المطبقة. لا ترسل كلمة المرور أو رموز التحقق أو بيانات الدفع.</p><a class="button" href="mailto:${html(policy.contactEmail)}?subject=${encodeURIComponent('طلب حذف حساب أرض التحدي')}">إرسال طلب حذف الحساب</a><p class="email">${html(policy.contactEmail)}</p></section><section class="section"><h2>البيانات المشمولة وما قد يُحتفظ به</h2>${policy.sections.find((section) => section.id === 'deletion').paragraphs.slice(2).map((text) => `<p>${html(text)}</p>`).join('')}<p>${html(policy.sections.find((section) => section.id === 'retention').paragraphs[1])}</p><p>لتفاصيل الاحتفاظ والمزودين وحقوق الأطفال وأولياء الأمور، راجع <a href="${html(policy.policyUrl)}">سياسة الخصوصية الكاملة</a>.</p></section>`;
const deletionHtml = page('حذف الحساب والبيانات', 'طرق طلب حذف حساب أرض التحدي أو بيانات محددة، داخل اللعبة ومن خارجها.', deleteBody, `<nav class="toc" aria-label="روابط الخصوصية"><h2>أرض التحدي</h2><a href="${html(policy.policyUrl)}">سياسة الخصوصية</a><a href="mailto:${html(policy.contactEmail)}">مراسلة الفريق</a></nav>`);

const outputs = new Map([
  ['lib/core/privacy_policy_content.g.dart', dartOutput],
  ['public/privacy.html', privacyHtml],
  ['android/app/src/main/assets/privacy_policy_ar.html', privacyHtml],
  ['public/delete-account.html', deletionHtml],
]);
let differences = 0;
for (const [file, content] of outputs) {
  const target = path.join(root, file);
  if (check) {
    if (!fs.existsSync(target) || fs.readFileSync(target, 'utf8').replace(/\r\n/g, '\n') !== content) {
      console.error(`Out of date: ${file}`);
      differences++;
    }
  } else {
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, content, 'utf8');
    console.log(`Updated ${file}`);
  }
}
if (differences) process.exitCode = 1;
else if (check) console.log('All policy copies match the canonical content source.');
