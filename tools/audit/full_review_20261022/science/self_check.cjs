const fs=require('fs'),path=require('path');const {r}=require('./review_tools.cjs');
const p=path.dirname(__dirname);const source=JSON.parse(fs.readFileSync(path.join(p,'backup/assets__questions.json'),'utf8'));
const rows=Array.isArray(source)?source:source.questions;
const manifest=JSON.parse(fs.readFileSync(path.join(p,'manifest.json'),'utf8'));
const categories=new Set(Object.values(manifest.coverage).flatMap(x=>x.categories));
const norm=s=>s.normalize('NFKC').replace(/[\u064B-\u065F\u0670\u0640]/g,'').replace(/[أإآ]/g,'ا').replace(/ى/g,'ي').replace(/ة/g,'ه').replace(/[^\p{L}\p{N}]/gu,'').toLowerCase();
const issues=[];const edited=new Map(r.edits.map(x=>[x.index,x]));const reviewed=new Set(r.reviewedIndices);
for(const e of r.edits){const orig=rows[e.index];if(!orig){issues.push({index:e.index,issue:'missing index'});continue;}const q={...orig,...e.changes};if(!reviewed.has(e.index))issues.push({index:e.index,issue:'edit not reviewed'});if(!categories.has(q.Category))issues.push({index:e.index,issue:'invalid category',value:q.Category});const vals=['R','W1','W2','W3'].map(k=>q[k]);if(new Set(vals.map(norm)).size!==4)issues.push({index:e.index,issue:'duplicate option',values:vals});if(norm(q.Q).includes(norm(q.R))&&norm(q.R).length>3)issues.push({index:e.index,issue:'answer substring',Q:q.Q,R:q.R});if(!/^[0-8]$/.test(q.Level))issues.push({index:e.index,issue:'level'});}
const same=new Map();for(const i of reviewed){const q={...rows[i],...(edited.get(i)?.changes||{})};const key=norm(q.Q);if(!same.has(key))same.set(key,[]);same.get(key).push(i);}for(const inds of same.values())if(inds.length>1)issues.push({issue:'same question',indices:inds});
fs.writeFileSync(path.join(__dirname,'self_check.json'),JSON.stringify(issues,null,2));console.log(JSON.stringify({reviewed:reviewed.size,edits:r.edits.length,issues},null,2));
