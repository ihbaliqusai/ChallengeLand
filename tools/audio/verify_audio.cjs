// Inspect actual decoded media, independently of the synthesis buffers.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..');
const ffmpeg=process.env.CHALLENGELAND_FFMPEG||'C:/Program Files (x86)/CoolerMaster/MasterPlus/ffmpeg.exe';
const directory=path.resolve(root,process.argv[2]||'build/audio-replacement');
const manifest=JSON.parse(fs.readFileSync(path.join(directory,'audio_provenance.json'),'utf8'));
const results=[];
for(const item of manifest.files){
 const file=path.join(directory,item.file),data=fs.readFileSync(file);
 const r=spawnSync(ffmpeg,['-hide_banner','-loglevel','error','-i',file,'-f','f32le','-ar','44100','-ac','2','pipe:1'],{maxBuffer:150*1024*1024});
 if(r.status!==0)throw new Error(item.file+': cannot decode: '+r.stderr);
 const b=r.stdout,samples=new Float32Array(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength));
 let sum=0,peak=0,nonFinite=0,onset=-1;
 for(let i=0;i<samples.length;i++){const s=samples[i];if(!Number.isFinite(s))nonFinite++;sum+=s*s;peak=Math.max(peak,Math.abs(s));if(onset<0&&Math.abs(s)>.005)onset=i/2/44100;}
 const duration=samples.length/2/44100,rmsDb=20*Math.log10(Math.sqrt(sum/samples.length));
 const sha256=crypto.createHash('sha256').update(data).digest('hex');
 if(nonFinite||peak<.01||peak>=.99||!Number.isFinite(rmsDb))throw new Error(item.file+': silent/clipped/invalid audio');
 if(Math.abs(duration-item.durationSeconds)>.06)throw new Error(item.file+': duration changed unexpectedly: '+duration);
 if(sha256!==item.sha256)throw new Error(item.file+': hash differs from provenance ledger');
 results.push({file:item.file,seconds:duration,rmsDb:Number(rmsDb.toFixed(2)),peakDb:Number((20*Math.log10(peak)).toFixed(2)),onsetSeconds:Number(onset.toFixed(4)),sha256});
}
const report={verifiedFiles:results.length,allDecoded:true,noClipping:true,allDurationsMatched:true,results};
fs.mkdirSync(path.join(root,'scratch/audio-replacement'),{recursive:true});
fs.writeFileSync(path.join(root,'scratch/audio-replacement/validation.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({verifiedFiles:results.length,allDecoded:true,noClipping:true,allDurationsMatched:true,minRmsDb:Math.min(...results.map(r=>r.rmsDb)),maxRmsDb:Math.max(...results.map(r=>r.rmsDb)),maxOnsetFx:Math.max(...results.filter(r=>r.seconds<15).map(r=>r.onsetSeconds))},null,2));
