const fs = require('fs');
const path = require('path');
const targets = [
 ['101-drumroll-ssss','https://www.101soundboards.com/sounds/24175941-drum-roll-ssss'],
 ['101-timpani','https://www.101soundboards.com/sounds/579322-timpani-drum-roll'],
 ['myinstants-drumroll-ssss','https://www.myinstants.com/en/instant/drum-roll-ssss-56455/'],
];
(async()=>{
 for(const [id,url] of targets) {
  try {
   const r=await fetch(url,{headers:{'User-Agent':'Mozilla/5.0'},signal:AbortSignal.timeout(20000)});
   const s=await r.text(); fs.writeFileSync(path.join(__dirname,id+'.html'),s);
   const matches=[...new Set(s.match(/https?:[^\s<>"']+\.(?:mp3|wav)(?:\?[^\s<>"']*)?/gi)||[])];
   const local=[...new Set(s.match(/[^\s<>"']+\.mp3/gi)||[])];
   console.log(JSON.stringify({id,status:r.status,length:s.length,media:matches.slice(0,12),local:local.slice(0,12),audioKeys:(s.match(/.{0,70}(?:sound_file|audio_file|sound_url|sound\.sound|audio_url|sounds\/storage).{0,180}/gi)||[]).slice(0,6)}));
  } catch(e){console.log(JSON.stringify({id,error:e.message}));}
 }
})();
