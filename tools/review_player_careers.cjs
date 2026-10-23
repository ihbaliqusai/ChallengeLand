const fs = require('node:fs');
// Keep the original 73-player source snapshot separate from the additions.
const reviewed = JSON.parse(fs.readFileSync('docs/player_career_review/source_careers.json','utf8'));
const names = reviewed.map(player => player.name);
const pages = reviewed.map(player => player.page);
const clean = s => s.replace(/<sup\b[^>]*>[\s\S]*?<\/sup>/g,'').replace(/<[^>]+>/g,'').replace(/&#(\d+);/g,(_,n)=>String.fromCodePoint(+n)).replace(/&amp;/g,'&').replace(/&nbsp;/g,' ').replace(/\s+/g,' ').trim();
async function main() {
  const results = [];
  let cursor = 0;
  await Promise.all(Array.from({length:5}, async () => {
    while (cursor < pages.length) {
      const index = cursor++;
      const url = 'https://en.wikipedia.org/wiki/' + encodeURIComponent(pages[index].replaceAll(' ','_'));
      const response = await fetch(url);
      if (!response.ok) throw new Error(`${pages[index]}: ${response.status}`);
      const html = await response.text();
      const start = html.indexOf('Senior career');
      const section = html.slice(start, html.indexOf('</table>',start));
      const rows = [];
      for (const match of section.matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr>/g)) {
        if (/International career|National team|Managerial career/.test(clean(match[1]))) break;
        const th = match[1].match(/<th\b[^>]*>([\s\S]*?)<\/th>/);
        const td = [...match[1].matchAll(/<td\b[^>]*>([\s\S]*?)<\/td>/g)];
        if (th && td.length && /^\d{4}/.test(clean(th[1]))) rows.push({years:clean(th[1]),club:clean(td[0][1]),apps:td[1]?clean(td[1][1]):''});
      }
      if (!rows.length) console.error(`No senior rows: ${pages[index]}`);
      results[index] = {name:names[index],page:pages[index],source:url,reviewedAt:'2026-10-23',rows};
    }
  }));
  fs.mkdirSync('docs/player_career_review',{recursive:true});
  fs.writeFileSync('docs/player_career_review/source_careers.json',JSON.stringify(results,null,2)+'\n');
  console.log(results.map(x=>x.name+': '+x.rows.map(r=>`${r.club} [${r.years}; ${r.apps}]`).join(' | ')).join('\n'));
}
main().catch(e=>{console.error(e);process.exitCode=1});
