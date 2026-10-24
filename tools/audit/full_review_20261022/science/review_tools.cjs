const fs=require('fs'),path=require('path');
const base=__dirname;
const reviewPath=path.join(base,'review.json');
let r=fs.existsSync(reviewPath)?JSON.parse(fs.readFileSync(reviewPath,'utf8')):{reviewedIndices:[],edits:[],unresolved:[],summary:'مراجعة تحريرية جارية؛ الفهارس المدرجة فقط قرئت فعليًا.'};
function edit(index,changes,reason,kind='correction',sources=[]){const old=r.edits.find(x=>x.index===index); if(old){Object.assign(old.changes,changes);old.reason+='؛ '+reason;old.sources=[...new Set([...old.sources,...sources])];if(kind!=='correction')old.kind=kind;} else r.edits.push({index,changes,reason,sources,kind});}
function done(file){for(const l of fs.readFileSync(path.join(base,file),'utf8').trim().split(/\r?\n/)){r.reviewedIndices.push(JSON.parse(l).index);}r.reviewedIndices=[...new Set(r.reviewedIndices)].sort((a,b)=>a-b);}
function save(){r.edits.sort((a,b)=>a.index-b.index);fs.writeFileSync(reviewPath,JSON.stringify(r,null,2)+'\n');console.log(JSON.stringify({reviewed:r.reviewedIndices.length,edits:r.edits.length,unresolved:r.unresolved.length}));}
module.exports={r,edit,done,save};
