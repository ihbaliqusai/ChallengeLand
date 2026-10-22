const fs = require('fs');
const path = require('path');
const dir = __dirname;
const files = fs.readdirSync(dir).filter(x=>x.endsWith('.jsonl')).sort();
const rows = files.flatMap(f=>fs.readFileSync(path.join(dir,f),'utf8').trim().split(/\r?\n/).filter(Boolean).map(JSON.parse));
const byIndex = new Map(rows.map(x=>[x.index,x]));
const outPath=path.join(dir,'review.json');
let out=fs.existsSync(outPath)?JSON.parse(fs.readFileSync(outPath,'utf8')):{reviewedIndices:[],edits:[],unresolved:[],summary:''};
function edit(index,changes,reason,kind='correction',sources=[]){
 const old=byIndex.get(index); if(!old)throw Error('Unknown '+index);
 for(const k of Object.keys(changes))if(changes[k]===old[k])delete changes[k];
 if(!Object.keys(changes).length)return;
 const prior=out.edits.find(x=>x.index===index);
 if(prior){Object.assign(prior.changes,changes);prior.reason+='؛ '+reason;prior.sources=[...new Set([...prior.sources,...sources])];if(kind!=='difficulty')prior.kind=kind;}
 else out.edits.push({index,changes,reason,sources,kind});
}
function mark(prefix){for(const f of files.filter(x=>x.startsWith(prefix)))for(const x of fs.readFileSync(path.join(dir,f),'utf8').trim().split(/\r?\n/).map(JSON.parse))out.reviewedIndices.push(x.index);out.reviewedIndices=[...new Set(out.reviewedIndices)].sort((a,b)=>a-b);}
function save(){out.edits.sort((a,b)=>a.index-b.index);out.summary=`مراجعة فعلية محفوظة تدريجياً: ${out.reviewedIndices.length} سؤالاً مقروءاً، ${out.edits.length} سجلاً معدلاً. شملت المراجعة الدقة والصعوبة والصياغة والمشتتات والتكرار. التوثيق الخارجي مخصص للمعلومات الملتبسة والمتغيرة؛ لا يعني توثيق كل سؤال على الويب.`;fs.writeFileSync(outPath,JSON.stringify(out,null,2)+'\n','utf8');}
function show(prefix){for(const f of files.filter(x=>x.startsWith(prefix))){console.log(f);for(const x of fs.readFileSync(path.join(dir,f),'utf8').trim().split(/\r?\n/).map(JSON.parse))console.log(`${x.index}|${x.Level}|${x.Q} => ${x.R} / ${x.W1} / ${x.W2} / ${x.W3}`);}}
module.exports={rows,byIndex,out,edit,mark,save,show};
if(require.main===module)show(process.argv[2]||'category_00_');
