const fs = require('node:fs');
const source = JSON.parse(fs.readFileSync('docs/player_career_review/source_careers.json','utf8'));
const names = `Sporting CP=سبورتنغ لشبونة
Manchester United=مانشستر يونايتد
Real Madrid=ريال مدريد
Juventus=يوفنتوس
Al-Nassr=النصر
Barcelona=برشلونة
Paris Saint-Germain=باريس سان جيرمان
Inter Miami=إنتر ميامي
Santos=سانتوس
Al-Hilal=الهلال
Monaco=موناكو
Al-Mokawloon=المقاولون العرب
Basel=بازل
Chelsea=تشيلسي
Fiorentina=فيورنتينا
Roma=روما
Liverpool=ليفربول
Trabzonspor=طرابزون سبور
Bryne=برينه
Molde=مولده
Red Bull Salzburg=ريد بول سالزبورغ
Borussia Dortmund=بوروسيا دورتموند
Manchester City=مانشستر سيتي
Lyon=ليون
Al-Ittihad=الاتحاد
Dinamo Zagreb=دينامو زغرب
Zrinjski Mostar=زرينيسكي موستار
Inter Zaprešić=إنتر زابريشيتش
Tottenham Hotspur=توتنهام هوتسبير
AC Milan=ميلان
Nacional=ناسيونال
Groningen=غرونينغن
Ajax=أياكس
Atlético Madrid=أتلتيكو مدريد
Grêmio=غريميو
Malmö FF=مالمو
Inter Milan=إنتر ميلان
LA Galaxy=لوس أنجلوس غالاكسي
Flamengo=فلامنغو
Atlético Mineiro=أتلتيكو مينيرو
Querétaro=كيريتارو
Fluminense=فلومينينسي
Ravenna=رافينا
São Paulo=ساو باولو
Orlando City=أورلاندو سيتي
Arsenal=أرسنال
New York Red Bulls=نيويورك ريد بولز
Preston North End=بريستون نورث إند
Everton=إيفرتون
D.C. United=دي سي يونايتد
Derby County=ديربي كاونتي
Sevilla=إشبيلية
Monterrey=مونتيري
Zaragoza=ريال سرقسطة
Al Sadd=السد
Vissel Kobe=فيسيل كوبي
Emirates=الإمارات
Como=كومو
Rosario Central=روزاريو سنترال
Benfica=بنفيكا
Independiente=إنديبندينتي
Lille=ليل
Genk=جينك
Werder Bremen=فيردر بريمن
VfL Wolfsburg=فولفسبورغ
Napoli=نابولي
Metz=ميتز
Southampton=ساوثهامبتون
Bayern Munich=بايرن ميونخ
Leyton Orient=ليتون أورينت
Millwall=ميلوول
Norwich City=نوريتش سيتي
Leicester City=ليستر سيتي
Delta Warsaw=دلتا وارسو
Znicz Pruszków=زنيتش بروشكوف
Lech Poznań=ليخ بوزنان
Chicago Fire=شيكاغو فاير
Vancouver Whitecaps=فانكوفر وايتكابس
Schalke 04=شالكه 04
PSV=آيندهوفن
Boulogne=بولوني
Alès=أولمبيك أليس
Brest=بريست
Galatasaray=غلطة سراي
Marseille=مارسيليا
Salernitana=ساليرنيتانا
Parma=بارما
Brescia=بريشيا
Reggina=ريجينا
New York City FC=نيويورك سيتي
Padova=بادوفا
Sydney FC=سيدني إف سي
Delhi Dynamos=دلهي ديناموز
Cruzeiro=كروزيرو
Corinthians=كورينثيانز
Santa Cruz=سانتا كروز
Mogi Mirim=موغي ميريم
Palmeiras=بالميراس
Deportivo La Coruña=ديبورتيفو لاكورونيا
Olympiacos=أولمبياكوس
AEK Athens=أيك أثينا
Bunyodkor=بونيودكور
Kabuscorp=كابوسكورب
São Caetano=ساو كايتانو
Leganés=ليغانيس
Espanyol=إسبانيول
Mallorca=مايوركا
Anzhi Makhachkala=أنجي محج قلعة
Sampdoria=سامبدوريا
Antalyaspor=أنطاليا سبور
Konyaspor=قونيا سبور
Qatar SC=قطر
Le Mans=لو مان
Guingamp=غانغان
Shanghai Shenhua=شنغهاي شينهوا
Montreal Impact=مونتريال إمباكت
Phoenix Rising=فينيكس رايزينغ
ASEC Mimosas=أسيك ميموزا
Beveren=بيفيرين
Metalurh Donetsk=ميتالوره دونيتسك
Qingdao Huanghai=تشينغداو هوانغهاي
Quimper=كيمبير
Le Havre=لوهافر
Al-Ahli=الأهلي السعودي
Al-Shamal=الشمال
Heerenveen=هيرنفين
Twente=تفينتي
Al-Duhail=الدحيل
Wydad=الوداد
Botafogo=بوتافوغو
Wydad Casablanca=الوداد
Girona=جيرونا
Al Hilal=الهلال
Cobreloa=كوبريلوا
Udinese=أودينيزي
Colo-Colo=كولو كولو
River Plate=ريفر بليت
CF Montréal=سي إف مونتريال
Feyenoord=فينورد
Fenerbahçe=فنربخشة
Sagan Tosu=ساغان توسو
Sporting Gijón=سبورتنغ خيخون
Real Zaragoza=ريال سرقسطة
Valencia=فالنسيا
Melbourne City=ملبورن سيتي
New York Cosmos=نيويورك كوزموس
Bahia=باهيا
UNAM=بوماس أونام
Real Sociedad=ريال سوسيداد
Eibar=إيبار
Lanceros Boyacá=لانسيروس بوياكا
Porto=بورتو
Rayo Vallecano=رايو فاييكانو
Millonarios=مليوناريوس
Envigado=إنفيغادو
Banfield=بانفيلد
Al-Rayyan=الريان
León=ليون المكسيكي
Minnesota United=مينيسوتا يونايتد
Atlético Nacional=أتلتيكو ناسيونال
Los Angeles FC=لوس أنجلوس إف سي
Celta=سيلتا فيغو
Sha Tin=سوبريم شا تين
Albacete=ألباسيتي
Santa Ana=سانتا آنا
Boca Juniors=بوكا جونيورز
Villarreal=فياريال
Argentinos Juniors=أرجنتينوس جونيورز
Rouen=روان
Mouscron=موسكرون
TSG Hoffenheim=هوفنهايم
West Ham United=وست هام يونايتد
Newcastle United=نيوكاسل يونايتد
Beşiktaş=بشكتاش
Shanghai Greenland Shenhua=شنغهاي شينهوا
Göztepe=غوزتيبي
İstanbul Başakşehir=إسطنبول باشاك شهير
Lugano=لوغانو
Caen=كان
Dijon=ديجون
Saint-Étienne=سانت إتيان
Al-Qadsiah=القادسية
Deportivo A Coruña=ديبورتيفو لاكورونيا
Grenoble=غرونوبل
Istres=إيستر
Tours=تور
Montpellier=مونبلييه
Manisaspor=مانيسا سبور
Başakşehir=إسطنبول باشاك شهير
Al Ahli=الأهلي الإماراتي
Kasımpaşa=قاسم باشا
Vitória Guimarães=فيتوريا غيمارايش
Nice=نيس
Al-Gharafa=الغرافة
Fulham=فولهام
Noordwijk=نوردفايك
Ismaily=الإسماعيلي
Perugia=بيروجيا
Al Ahly=الأهلي المصري
West Bromwich Albion=وست بروميتش ألبيون
Neom=نيوم
Almería=ألميريا
Fatih Karagümrük=فاتح قره جمرك
Amanat Baghdad=أمانة بغداد
Lorient=لوريان
Clermont=كليرمون
Al Nassr=النصر
Lierse=ليرس
Tersana=الترسانة
Baniyas=بني ياس
Dynamo Kyiv=دينامو كييف
Adana Demirspor=أضنة دمير سبور
Al-Sailiya=السيلية
Angers=أنجيه`;
const ar = Object.fromEntries(names.split('\n').map(line=>line.split('=')));
// These replace contract-order infobox rows with actual first-team playing
// spells. A parent's name returns only when there was another playing spell.
const overrides = {
 'Luka Modrić':'Zrinjski Mostar|Inter Zaprešić|Dinamo Zagreb|Tottenham Hotspur|Real Madrid|AC Milan',
 'Kaká':'São Paulo|AC Milan|Real Madrid|AC Milan|São Paulo|Orlando City',
 'Thierry Henry':'Monaco|Juventus|Arsenal|Barcelona|New York Red Bulls|Arsenal|New York Red Bulls',
 'David Beckham':'Manchester United|Preston North End|Manchester United|Real Madrid|LA Galaxy|AC Milan|LA Galaxy|AC Milan|LA Galaxy|Paris Saint-Germain',
 'Gerard Piqué':'Manchester United|Zaragoza|Manchester United|Barcelona',
 'Kevin De Bruyne':'Genk|Werder Bremen|Chelsea|VfL Wolfsburg|Manchester City|Napoli',
 'Harry Kane':'Leyton Orient|Tottenham Hotspur|Millwall|Tottenham Hotspur|Norwich City|Leicester City|Tottenham Hotspur|Bayern Munich',
 'Andrea Pirlo':'Brescia|Inter Milan|Reggina|Inter Milan|Brescia|AC Milan|Juventus|New York City FC',
 "Samuel Eto'o":'Leganés|Real Madrid|Mallorca|Barcelona|Inter Milan|Anzhi Makhachkala|Chelsea|Everton|Sampdoria|Antalyaspor|Konyaspor|Qatar SC',
 'Yaya Touré':'ASEC Mimosas|Beveren|Metalurh Donetsk|Olympiacos|Monaco|Barcelona|Manchester City|Olympiacos|Qingdao Huanghai',
 'Achraf Hakimi':'Real Madrid|Borussia Dortmund|Inter Milan|Paris Saint-Germain',
 'Yassine Bounou':'Wydad Casablanca|Zaragoza|Girona|Sevilla|Al Hilal',
 'Alexis Sánchez':'Cobreloa|Colo-Colo|River Plate|Udinese|Barcelona|Arsenal|Manchester United|Inter Milan|Marseille|Inter Milan|Udinese|Sevilla|CF Montréal',
 'David Villa':'Sporting Gijón|Real Zaragoza|Valencia|Barcelona|Atlético Madrid|Melbourne City|New York City FC|Vissel Kobe',
 'Xabi Alonso':'Real Sociedad|Eibar|Real Sociedad|Liverpool|Real Madrid|Bayern Munich',
 'Radamel Falcao':'Lanceros Boyacá|River Plate|Porto|Atlético Madrid|Monaco|Manchester United|Chelsea|Monaco|Galatasaray|Rayo Vallecano|Millonarios',
 'James Rodríguez':'Envigado|Banfield|Porto|Monaco|Real Madrid|Bayern Munich|Real Madrid|Everton|Al-Rayyan|Olympiacos|São Paulo|Rayo Vallecano|León|Minnesota United|Atlético Nacional',
 'Gareth Bale':'Southampton|Tottenham Hotspur|Real Madrid|Tottenham Hotspur|Real Madrid|Los Angeles FC',
 'David Silva':'Eibar|Celta|Valencia|Manchester City|Real Sociedad',
 'Fernando Morientes':'Albacete|Zaragoza|Real Madrid|Monaco|Real Madrid|Liverpool|Valencia|Marseille|Santa Ana',
 'Demba Ba':'Rouen|Mouscron|TSG Hoffenheim|West Ham United|Newcastle United|Chelsea|Beşiktaş|Shanghai Shenhua|Beşiktaş|Göztepe|Shanghai Shenhua|İstanbul Başakşehir|Lugano',
 'Pierre-Emerick Aubameyang':'Dijon|Lille|Monaco|Saint-Étienne|Borussia Dortmund|Arsenal|Barcelona|Chelsea|Marseille|Al-Qadsiah|Marseille|Deportivo A Coruña',
 'Olivier Giroud':'Grenoble|Istres|Tours|Montpellier|Arsenal|Chelsea|AC Milan|Los Angeles FC|Lille',
 'Arda Turan':'Galatasaray|Manisaspor|Galatasaray|Atlético Madrid|Barcelona|Başakşehir|Galatasaray',
 'Ricardo Quaresma':'Sporting CP|Barcelona|Porto|Inter Milan|Chelsea|Inter Milan|Beşiktaş|Al Ahli|Porto|Beşiktaş|Kasımpaşa|Vitória Guimarães',
 'Sofiane Feghouli':'Grenoble|Valencia|Almería|Valencia|West Ham United|Galatasaray|Fatih Karagümrük|Amanat Baghdad',
 'Medhi Benatia':'Tours|Lorient|Clermont|Udinese|Roma|Bayern Munich|Juventus|Al-Duhail|Fatih Karagümrük',
 'Hossam Ghaly':'Al Ahly|Feyenoord|Tottenham Hotspur|Derby County|Al Nassr|Al Ahly|Lierse|Al Ahly|Al Nassr|Al Ahly',
 'Mohamed Aboutrika':'Tersana|Al Ahly|Baniyas|Al Ahly',
 'Younès Belhanda':'Montpellier|Dynamo Kyiv|Schalke 04|Nice|Galatasaray|Adana Demirspor|Al-Shamal|Al-Sailiya',
 'Nabil Bentaleb':'Tottenham Hotspur|Schalke 04|Newcastle United|Schalke 04|Angers|Lille',
};
const extras = {
 'Harry Kane':['https://www.tottenhamhotspur.com/the-club/history/legends/harry-kane'],
 'Kaká':['https://www.saopaulofc.net/tem-trikolor-voltando-pra-kasa-no-domingo/'],
 'David Villa':['https://www.mlssoccer.com/news/mls-flight-path-how-david-villa-has-starred-nycfc-spain'],
 'Kevin De Bruyne':['https://www.stamford-bridge.com/player/player.php?firstname=Kevin&id=707&surname=de+Bruyne'],
 "Samuel Eto'o":['https://www.cdleganes.com/etoo','https://as.com/futbol/2019/09/07/album/1567871835_057008.html'],
 'Yassine Bounou':['https://as.com/futbol/primera/bono-lo-que-el-cholo-se-perdio-n/'],
 'Medhi Benatia':['https://www.lequipe.fr/fiche/medhi-benatia/223060'],
 'Ronaldinho':['https://www.soccerbase.com/players/player.sd?player_id=19302'],
 'Mohamed Salah':['https://www.trabzonspor.org.tr/tr/haberler/mohamed-salah-ile-sozlesme-imzaladik-06-08-2026'],
 'Karim Benzema':['https://www.spl.com.sa/en/news/benzema-completes-move-to-rsl-leaders-al-hilal'],
 'Luka Modrić':['https://www.acmilan.com/en/news/articles/extra/2025-07-14/official-statement-luka-modric','https://www.klix.ba/sport/nogomet/prije-20-godina-luka-modric-je-u-blatu-bh-terena-upisao-svoj-prvi-nastup-u-karijeri/230810063'],
 'Yaya Touré':['https://www.officialyayatoure.com/club-career/asec-mimosas/','https://players.fcbarcelona.com/en/player/889-toure-yaya-gnegneri-yaya-toure'],
 'Riyad Mahrez':['https://thepeninsulaqatar.com/article/18/10/2026/al-shamal-held-by-lusail-on-mahrezs-debut-joselu-earns-al-sailiya-first-point'],
 'Hakim Ziyech':['https://www.botafogo.com.br/noticias/ziyech-e-glorioso'],
 'Robert Lewandowski':['https://www.chicagofirefc.com/news/a-defining-moment-in-chicago-sports-chicago-fire-fc-acquires-global-football-icon-robert-lewandowski'],
 'Pierre-Emerick Aubameyang':['https://www.rcdeportivo.es/es/noticias/pierre-emerick-aubameyang-nuevo-jugador-del-depor'],
 'Alexis Sánchez':['https://en.cfmontreal.com/news/cf-montreal-signs-alexis-sanchez-as-a-designated-player'],
 'James Rodríguez':['https://colombia.as.com/futbol/oficial-james-rodriguez-nuevo-jugador-de-atletico-nacional-f202609-n/'],
 "N'Golo Kanté":['https://www.tff.org/Default.aspx?kisiId=2885268&pageId=526'],
 'Younès Belhanda':['https://qna.org.qa/en/news/news-details?date=19%2F08%2F2026&id=al-sailiya-sign-sanda-on-loan-extend-belhanda-deal'],
 'David Silva':['https://english.dotdotnews.com/s/202610/22/AP6ad9d0cae4b02fd1c5f54862.html'],
};
const reviewed = source.map(player=>{
 let clubs = overrides[player.page]?.split('|');
 if (!clubs) clubs = player.rows
   .filter(row=>!/(?: II| B| C| 2)$/.test(row.club)&&row.club!=='Sevilla Atlético')
   .filter(row=>row.apps!=='0'||(player.page==='Riyad Mahrez'&&row.club==='Al-Shamal'))
   .map(row=>row.club.replace(/^→ /,'').replace(/ \(loan\)$/,''));
 clubs = clubs.filter((club,i)=>ar[club]!==ar[clubs[i-1]]||i===0);
 for (const club of clubs) if (!ar[club]) throw new Error('Missing translation: '+club);
 return {name:player.name,page:player.page,clubs:clubs.map(club=>ar[club]),clubsEnglish:clubs,reviewedAt:'2026-10-23',sources:[player.source,...(extras[player.page]||[])]};
});
const mediumOriginal = new Set(['ديمبا با','أحمد حجازي','سفيان فيغولي','المهدي بن عطية','حسام غالي','محمد أبو تريكة','يونس بلهندة','نبيل بن طالب','أردا توران','ريكاردو كواريزما']);
for (const player of reviewed) player.points = mediumOriginal.has(player.name) ? 400 : 200;
const additions = JSON.parse(fs.readFileSync('tools/player_career_additions_reviewed.json','utf8'));
if (reviewed.length!==73 || additions.length!==227) throw new Error('Expected 73 original and 227 new players');
const all = [...reviewed,...additions];
if (new Set(all.map(p=>p.name)).size!==all.length || new Set(all.map(p=>p.page)).size!==all.length) throw new Error('Duplicate player');
for (const points of [200,400,600]) if (all.filter(p=>p.points===points).length!==100) throw new Error(`Expected 100 careers at ${points} points`);
fs.writeFileSync('tools/player_careers_reviewed.json',JSON.stringify(all,null,2)+'\n');
console.log(`Compiled ${all.length} complete playing careers: 100 each at 200, 400 and 600 points.`);
