// Reproducible replacement soundtrack: CC0 source recordings and original DSP.
// Usage: node tools/audio/build_audio.cjs [--apply]
// No audio from the previous recordings is sampled or used as synthesis input.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const sourceDir = path.join(__dirname, 'sources');
const stage = path.join(root, 'build/audio-replacement');
const rawDir = path.join(root, 'android/app/src/main/res/raw');
const ffmpeg = process.env.CHALLENGELAND_FFMPEG || 'C:/Program Files (x86)/CoolerMaster/MasterPlus/ffmpeg.exe';
const rate = 44100;
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const retainedUnverifiedFiles=JSON.parse(fs.readFileSync(path.join(__dirname,'retained_assets.json'),'utf8'));
const retainedNames=new Set(retainedUnverifiedFiles.map(item=>item.file));
fs.mkdirSync(stage, {recursive:true});
function ff(args, binary=false) {
  const result=spawnSync(ffmpeg,['-hide_banner','-loglevel','error',...args],{encoding:binary?null:'utf8',maxBuffer:150*1024*1024});
  if(result.status!==0)throw new Error(String(result.stderr||result.error));
  return result.stdout;
}
const sourceInfo = {
  'unsolved-investigation.ogg':{title:'Unsolved Investigation',author:'isaiah658',url:'https://opengameart.org/content/unsolved-investigation'},
  'suspense.ogg':{title:'Suspense',author:'wipics',url:'https://opengameart.org/content/suspense-0'},
  'opening-theme.flac':{title:'Opening Theme [Action/Suspense]',author:'nene',url:'https://opengameart.org/content/opening-theme-actionsuspense'},
  'kenney_confirmation_001.ogg':{title:'Interface Sounds / confirmation_001',author:'Kenney',url:'https://kenney.nl/assets/interface-sounds'},
  'kenney_confirmation_002.ogg':{title:'Interface Sounds / confirmation_002',author:'Kenney',url:'https://kenney.nl/assets/interface-sounds'},
  'kenney_error_003.ogg':{title:'Interface Sounds / error_003',author:'Kenney',url:'https://kenney.nl/assets/interface-sounds'},
  'kenney_open_004.ogg':{title:'Interface Sounds / open_004',author:'Kenney',url:'https://kenney.nl/assets/interface-sounds'},
};
const decoded = new Map();
function decode(file) {
  if(!decoded.has(file)){
    const b=ff(['-i',path.join(sourceDir,file),'-vn','-ar',String(rate),'-ac','2','-f','f32le','pipe:1'],true);
    decoded.set(file,new Float32Array(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)));
  }
  return decoded.get(file);
}
function mixStock(out,file,{start=0,gain=1,loop=false}={}) {
  const input=decode(file), frames=input.length/2, offset=Math.round(start*rate);
  let first=offset;
  if(!loop)while(first<Math.min(frames,offset+rate)&&Math.max(Math.abs(input[first*2]),Math.abs(input[first*2+1]))<0.001)first++;
  for(let i=0;i<out.length/2;i++){
    const pos=loop?(offset+i)%frames:first+i;
    if(pos>=frames)break;
    // Tiny fades on each repeated source boundary prevent clicks.
    const edge=loop?Math.min(1,pos/(rate*.012),(frames-1-pos)/(rate*.012)):1;
    out[i*2]+=input[pos*2]*gain*Math.max(0,edge);
    out[i*2+1]+=input[pos*2+1]*gain*Math.max(0,edge);
  }
}
function tone(out,start,duration,midi,gain=.2,kind='bell',pan=0){
  const begin=Math.round(start*rate),length=Math.round(duration*rate),freq=440*2**((midi-69)/12);
  const l=Math.sqrt((1-pan)/2),r=Math.sqrt((1+pan)/2);
  for(let j=0;j<length&&begin+j<out.length/2;j++){
    const t=j/rate,attack=Math.min(1,t/(kind==='pad'?.12:.009));
    const release=Math.min(1,(length-j)/(rate*(kind==='pad'?.6:.11)));
    const phase=2*Math.PI*freq*t;
    let value;
    if(kind==='bell')value=(Math.sin(phase+1.4*Math.exp(-t*6)*Math.sin(phase*2.71))+.15*Math.sin(phase*2))*Math.exp(-t*3.6);
    else if(kind==='pad')value=(Math.sin(phase)+.38*Math.sin(phase*1.002)+.17*Math.sin(phase*2))/1.55;
    else if(kind==='horn')value=(Math.sin(phase)+.4*Math.sin(phase*2)+.2*Math.sin(phase*3)+.08*Math.sin(phase*4))*Math.exp(-t*.8);
    else value=Math.sin(phase);
    value*=gain*attack*release;
    out[(begin+j)*2]+=value*l;out[(begin+j)*2+1]+=value*r;
  }
}
let seed=8197345;
function noise(){seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;return (seed>>>0)/2147483648-1;}
function drum(out,start,duration,gain=.15,low=false){
  const begin=Math.round(start*rate),count=Math.round(duration*rate);let previous=0;
  for(let j=0;j<count&&begin+j<out.length/2;j++){
    const t=j/rate,n=noise(),filtered=low?(previous*.87+n*.13):(n-previous*.65);previous=n;
    const pitch=low?Math.sin(2*Math.PI*(63*t+8*(1-Math.exp(-t*30)))):0;
    const v=(filtered*.55+pitch*.6)*gain*Math.exp(-t/(duration*.21))*Math.min(1,t/.002);
    out[(begin+j)*2]+=v;out[(begin+j)*2+1]+=v;
  }
}
function fanfare(out,short=false){
  const notes=short?[76,79,83,88]:[72,76,79,84,79,88];
  notes.forEach((note,i)=>tone(out,i*(short?.11:.16),short?.7:1.5,note,.25,'bell',(i%2?1:-1)*.15));
  if(!short)[[60,64,67],[65,69,72],[67,71,74],[60,64,67]].forEach((chord,i)=>chord.forEach(n=>tone(out,.1+i*.56,1.8,n,.045,'horn')));
}
function victoryScore(out){
  const beat=60/112,bar=beat*4,roots=[50,47,55,57,50,54,55,57];
  const melody=[[74,78,81,85,83],[71,74,78,81,78],[79,83,86,83,81],[81,85,88,86,85]];
  for(let b=0;b*bar<out.length/2/rate;b++){
    const s=b*bar,rootNote=roots[b%roots.length];
    [0,4,7].forEach((n,i)=>tone(out,s,bar+.3,rootNote+n,.045,'pad',(i-1)*.4));
    [0,.75,1.5,2.25,3.25].forEach((p,i)=>tone(out,s+p*beat,beat*.7,melody[b%4][i],.1,'horn',i%2?.13:-.13));
    for(let k=0;k<4;k++){tone(out,s+k*beat,beat*.7,rootNote-12,.1,'sine');drum(out,s+k*beat,.11,.032,k%2===0);}
    if(b%4===0)tone(out,s,.8,rootNote+24,.05,'bell');
  }
}
function whooshImpact(out){
  let low=0;for(let i=0;i<Math.min(out.length/2,rate*.65);i++){
    const t=i/rate;low=.82*low+.18*noise();const swell=t<.2?Math.sin(t/.2*Math.PI/2):Math.exp(-(t-.2)*10);
    const v=low*.35*swell;out[i*2]+=v;out[i*2+1]+=v;
  }drum(out,.18,.75,.55,true);tone(out,.2,1.5,35,.18,'sine');
}
function synth(out,kind){
  const duration=out.length/2/rate;
  if(kind==='beep'){tone(out,0,.11,85,.35,'sine');}
  else if(kind==='urgent'){[0,.16].forEach(s=>tone(out,s,.09,91,.3,'sine'));}
  else if(kind==='correct'){mixStock(out,'kenney_confirmation_002.ogg',{gain:.22});fanfare(out);}
  else if(kind==='wrong'){
    mixStock(out,'kenney_error_003.ogg',{gain:.35});[55,51,48].forEach((n,i)=>tone(out,i*.22,1.2,n,.18,'horn'));drum(out,0,.4,.12,true);
  }else if(kind==='level'){mixStock(out,'kenney_confirmation_001.ogg',{gain:.3});fanfare(out,true);}
  else if(kind==='found'){mixStock(out,'kenney_open_004.ogg',{gain:.2});[76,83,88].forEach((n,i)=>tone(out,i*.16,.7,n,.25,'bell'));}
  else if(kind==='slam'){whooshImpact(out);}
  else if(kind==='roll'){for(let t=0;t<duration;t+=.085){drum(out,t,.11,.16);if(Math.round(t/.085)%4===0)drum(out,t,.2,.1,true);}}
  else if(kind==='phone'){
    for(let s=0;s<duration;s+=2.4)for(const offset of [0,.43]){
      tone(out,s+offset,.31,75,.12,'sine');tone(out,s+offset,.31,80,.1,'sine');
    }
  }else if(kind==='chatter'){
    // Wordless formant-like robot syllables, never a recording or voice clone.
    for(let s=0,syllable=0;s<duration;s+=.19,syllable++){
      const base=[43,46,41,45,48,42,47][syllable%7];
      tone(out,s,.14,base,.22,'horn');tone(out,s,.13,base+19,.1,'horn');tone(out,s,.12,base+31,.055,'sine');
    }
  }else if(kind==='victory'){victoryScore(out);fanfare(out);}
}
const configs=[
  ['beep',.36,'تنبيه عداد الوقت','beep'],['beep1',.55,'تنبيه الثواني الأخيرة','urgent'],
  ['blabla',3.55,'ثرثرة آلية غير لفظية للاتصال بالصديق','chatter'],
  ['commerical_break',10.71,'فاصل وانتقال',null,'opening-theme.flac',0],
  ['correct_answer',7.73,'إجابة صحيحة','correct'],['drum1',12.61,'ترقب كشف الإجابة','roll'],
  ['lets_play',10.32,'بدء اللعب',null,'opening-theme.flac',14],
  ['main_theme_0',160.34,'خلفية ترقب هادئة',null,'unsolved-investigation.ogg'],
  ['main_theme_1',160.34,'خلفية ترقب متوسطة',null,'suspense.ogg'],
  ['main_theme_2',167.13,'مساعدة الجمهور',null,'suspense.ogg'],
  ['main_theme_3',160.34,'خلفية التفكير بعد المساعدة',null,'unsolved-investigation.ogg'],
  ['main_theme_4',34.22,'احتفال نهاية اللعبة','victory'],
  ['match_opponent_found',1.37,'العثور على منافس','found'],['match_versus_slam',2.38,'ظهور المواجهة','slam'],
  ['new_level',1.78,'فوز مرحلة أو تقدم','level'],['phone_friend',46.63,'نغمة الاتصال بالصديق','phone'],
  ['s_1000000',160.21,'احتفال الفوز الكبير','victory'],
  ['s_64000',160.34,'خلفية ترقب عالية',null,'suspense.ogg'],['wrong_answer',5.83,'إجابة خاطئة','wrong'],
];
const records=[];
for(const [name,duration,role,kind,stock,start=0] of configs){
  if(retainedNames.has(name+'.mp3'))continue;
  const frames=Math.round(duration*rate),out=new Float32Array(frames*2);
  seed=crypto.createHash('sha256').update(name).digest().readUInt32LE(0);
  if(stock){
    mixStock(out,stock,{start,loop:duration>100});
    if(name==='main_theme_2'||name==='main_theme_3'||name==='s_64000')for(let t=.1;t<duration;t+=(name==='s_64000'?.5:1))drum(out,t,.12,.025,true);
  }else synth(out,kind);
  // Gentle edges and a consistent music/effect level, with ample MP3 headroom.
  const music=duration>30&&kind!=='phone';let sum=0,peak=0;
  for(let i=0;i<frames;i++){
    const fadeIn=Math.min(1,i/(rate*.008));
    const fadeOut=Math.min(1,(frames-1-i)/(rate*(kind==='roll'?.012:duration>5?.15:.04)));
    const envelope=Math.max(0,Math.min(fadeIn,fadeOut));
    for(let c=0;c<2;c++){const j=i*2+c;out[j]*=envelope;sum+=out[j]*out[j];peak=Math.max(peak,Math.abs(out[j]));}
  }
  if(peak<.0001)throw new Error('Silent generated asset '+name);
  const rms=Math.sqrt(sum/out.length),target=10**((music?-23:-20)/20),gain=Math.min(target/rms,.73/peak);
  for(let i=0;i<out.length;i++)out[i]*=gain;
  const pcm=path.join(stage,name+'.f32');fs.writeFileSync(pcm,Buffer.from(out.buffer));
  const output=path.join(stage,name+'.mp3');
  ff(['-y','-f','f32le','-ar',String(rate),'-ac','2','-i',pcm,'-map_metadata','-1','-c:a','libmp3lame','-b:a','96k','-ar',String(rate),'-ac','2','-metadata','title=ChallengeLand - '+name,'-metadata','comment=CC0 sources and original procedural design; see audio_provenance.json',output]);
  fs.unlinkSync(pcm);
  const sources=[];if(stock)sources.push(stock);
  const extras={correct:'kenney_confirmation_002.ogg',wrong:'kenney_error_003.ogg',level:'kenney_confirmation_001.ogg',found:'kenney_open_004.ogg'};
  if(extras[kind])sources.push(extras[kind]);
  records.push({file:name+'.mp3',role,durationSeconds:duration,sampleRate:rate,channels:2,bytes:fs.statSync(output).size,sha256:hash(output),sources:sources.map(file=>({...sourceInfo[file],file,license:'CC0-1.0',licenseUrl:'https://creativecommons.org/publicdomain/zero/1.0/',sourceSha256:hash(path.join(sourceDir,file))})),originalProceduralDesign:!!kind,sourceStartSeconds:stock?start:undefined,loopPrepared:duration>100||kind==='roll',processing:'44100 Hz stereo; duration matched to previous asset; level normalization; short edge fades; MP3 96 kbps. No samples from previous recordings.'});
  console.log('Prepared '+name+'.mp3 ('+duration+'s)');
}
const provenance={version:1,updatedAt:'2026-10-26',generator:'tools/audio/build_audio.cjs',note:'The original DSP components are generated for this project, without external voice recordings or imitation of any performer. CC0 components are listed per file. Durations preserve gameplay timing; compositions are new alternatives, not replicas of television themes. Restored previous recordings are listed separately with their actual license status.',files:records,retainedLicensedFiles:['main_theme_320bit_chosic.mp3','sneaky_snitch.mp3'],retainedUnverifiedFiles};
fs.writeFileSync(path.join(stage,'audio_provenance.json'),JSON.stringify(provenance,null,2)+'\n');
if(process.argv.includes('--apply')){
  for(const item of retainedUnverifiedFiles)if(hash(path.join(rawDir,item.file))!==item.sha256)throw new Error('Retained recording changed: '+item.file);
  const baselinePath=path.join(root,'docs/audio-replacement-before.json');
  if(!fs.existsSync(baselinePath))fs.writeFileSync(baselinePath,JSON.stringify([...records.map(r=>r.file),...provenance.retainedLicensedFiles,...retainedUnverifiedFiles.map(item=>item.file)].map(file=>({file,sha256:hash(path.join(rawDir,file)),bytes:fs.statSync(path.join(rawDir,file)).size})),null,2)+'\n');
  for(const r of records)fs.copyFileSync(path.join(stage,r.file),path.join(rawDir,r.file));
  fs.copyFileSync(path.join(stage,'audio_provenance.json'),path.join(rawDir,'audio_provenance.json'));
  console.log('Applied '+records.length+' replacement MP3s and provenance ledger.');
}
module.exports={configs,sourceInfo};
