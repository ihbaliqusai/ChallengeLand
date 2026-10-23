const fs = require('node:fs');
const path = require('node:path');
const parse5 = require(require.resolve('parse5',{paths:[path.join(process.env.APPDATA||'','npm/node_modules/firebase-tools'),'functions']}));
const players = fs.readFileSync('tools/player_career_additions.tsv','utf8').trim().split(/\r?\n/).map(line=>{
 const [points,name,page]=line.split('|'); return {points:+points,name,page};
});
const cache='build/career-source-pages'; fs.mkdirSync(cache,{recursive:true});
const attr=(n,k)=>n.attrs?.find(a=>a.name===k)?.value;
const all=(n,tag)=>[...(n.tagName===tag?[n]:[]),...(n.childNodes||[]).flatMap(c=>all(c,tag))];
const text=n=>n.nodeName==='#text'?n.value: n.tagName==='sup'?'':(n.childNodes||[]).map(text).join(' ').replace(/\s+/g,' ').trim();
async function main(){
 const results=[];let cursor=0;
 await Promise.all(Array.from({length:1},async()=>{
  while(cursor<players.length){
   const index=cursor++; const player=players[index];
   const source='https://en.wikipedia.org/wiki/'+encodeURIComponent(player.page.replaceAll(' ','_'));
   const file=path.join(cache,index+'.html');let html;
   if(fs.existsSync(file))html=fs.readFileSync(file,'utf8');else{
     let response;
     for(let attempt=0;attempt<5;attempt++){
       response=await fetch(source);
       if(response.status!==429)break;
       await new Promise(resolve=>setTimeout(resolve,5000*(attempt+1)));
     }
     if(!response.ok)throw new Error(`${player.page}: HTTP ${response.status}`);
     html=await response.text();fs.writeFileSync(file,html);
     await new Promise(resolve=>setTimeout(resolve,350));
   }
   const dom=parse5.parse(html);const tables=all(dom,'table');
   const infobox=tables.find(n=>(attr(n,'class')||'').includes('infobox'));
   const rows=[];let senior=false;
   for(const row of infobox?all(infobox,'tr'):[]){
    const content=text(row);if(content.includes('Senior career')){senior=true;continue;}if(!senior)continue;
    if(/International career|National team|Managerial career/.test(content))break;
    const cells=(row.childNodes||[]).filter(c=>['td','th'].includes(c.tagName));
    if(cells.length>=2&&/^\d{4}/.test(text(cells[0])))rows.push({years:text(cells[0]),club:text(cells[1]),apps:cells[2]?text(cells[2]):''});
   }
   const stats=[];
   for(const table of tables){
    const trs=all(table,'tr');if(!/Club/.test(trs.slice(0,3).map(text).join(' '))||!/Season/.test(trs.slice(0,3).map(text).join(' ')))continue;
    const spans=[];
    for(const row of trs){
     const grid=[];let col=0;const cells=(row.childNodes||[]).filter(c=>['td','th'].includes(c.tagName));
     const carried=()=>{while(spans[col]?.left>0){grid[col]=spans[col].value;spans[col].left--;col++;}};
     for(const cell of cells){carried();const value=text(cell);const width=+(attr(cell,'colspan')||1);const height=+(attr(cell,'rowspan')||1);for(let n=0;n<width;n++){grid[col]=value;if(height>1)spans[col]={value,left:height-1};col++;}}
     carried();
     if(/^\d{4}(?:[–\/-]\d{2,4})?$/.test(grid[1]||'') && !/Total/i.test(grid[0]||''))stats.push({club:grid[0],season:grid[1],apps:grid.at(-2),cells:grid});
    }
   }
   results[index]={...player,source,reviewedAt:'2026-10-23',rows,stats};
   if(!rows.length)console.error('MISSING '+player.page);
  }
 }));
 fs.writeFileSync('docs/player_career_review/additions_sources.json',JSON.stringify(results,null,2)+'\n');
 console.log(results.map((p,i)=>`${i+1}. ${p.page}: ${p.rows.map(r=>r.club+' ['+r.years+'; '+r.apps+']').join(' | ')}\n   STATS: ${p.stats.filter((r,i,a)=>i===0||r.club!==a[i-1].club).map(r=>r.club+' '+r.season).join(' > ')}`).join('\n'));
}
main().catch(e=>{console.error(e);process.exitCode=1});
