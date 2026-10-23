const fs = require('node:fs');
const source = JSON.parse(fs.readFileSync('docs/player_career_review/additions_sources.json','utf8'));
const originalCompiler = fs.readFileSync('tools/compile_reviewed_careers.cjs','utf8');
const originalNames = originalCompiler.match(/const names = `([\s\S]*?)`;/)[1];
const translations = Object.fromEntries(originalNames.split('\n').map(s=>s.split('=')));
Object.assign(translations, JSON.parse(fs.readFileSync('tools/player_career_clubs_ar.json','utf8')));
// Reviewed chronological playing spells. Infoboxes list contract owners before
// loans and frequently omit the subsequent playing spell with the parent club.
const overrides = {
 'Pelé':'Santos|New York Cosmos',
 'Michel Platini':'Nancy|Saint-Étienne|Juventus',
 'Johan Cruyff':'Ajax|Barcelona|Los Angeles Aztecs|Washington Diplomats|Levante|Washington Diplomats|Ajax|Feyenoord',
 'Hernán Crespo':'River Plate|Parma|Lazio|Inter Milan|Chelsea|AC Milan|Chelsea|Inter Milan|Genoa|Parma',
 'Andriy Shevchenko':'Dynamo Kyiv|AC Milan|Chelsea|AC Milan|Dynamo Kyiv',
 'Dida (footballer, born 1973)':'Vitória|Cruzeiro|Corinthians|AC Milan|Corinthians|AC Milan|Portuguesa|Grêmio|Internacional',
 'Roberto Carlos':'União São João|Palmeiras|Inter Milan|Real Madrid|Fenerbahçe|Corinthians|Anzhi Makhachkala|Delhi Dynamos',
 'Filippo Inzaghi':'Piacenza|Leffe|Verona|Piacenza|Parma|Atalanta|Juventus|AC Milan',
 'Frank Lampard':'Swansea City|West Ham United|Chelsea|Manchester City|New York City FC',
 'Miroslav Klose':'SG Blaubach-Diedelkopf|FC 08 Homburg|Kaiserslautern|Werder Bremen|Bayern Munich|Lazio',
 'Eric Cantona':'Auxerre|Martigues|Auxerre|Marseille|Bordeaux|Montpellier|Marseille|Nîmes|Leeds United|Manchester United',
 'Giovanni van Bronckhorst':'RKC Waalwijk|Feyenoord|Rangers|Arsenal|Barcelona|Feyenoord',
 'Dirk Kuyt':'Quick Boys|Utrecht|Feyenoord|Liverpool|Fenerbahçe|Feyenoord|Quick Boys',
 'Ruud Gullit':'Haarlem|Feyenoord|PSV|AC Milan|Sampdoria|AC Milan|Sampdoria|Chelsea',
 'Frank Rijkaard':'Ajax|Real Zaragoza|AC Milan|Ajax',
 'Lothar Matthäus':'1. FC Herzogenaurach|Borussia Mönchengladbach|Bayern Munich|Inter Milan|Bayern Munich|MetroStars|Lokomotive Leipzig|1. FC Herzogenaurach',
 'Philipp Lahm':'Bayern Munich|VfB Stuttgart|Bayern Munich',
 'Álvaro Recoba':'Danubio|Nacional|Inter Milan|Venezia|Inter Milan|Torino|Panionios|Danubio|Nacional',
 'Iván Zamorano':'Cobresal|Cobreandino|Cobresal|St. Gallen|Sevilla|Real Madrid|Inter Milan|América|Colo-Colo',
 'Juan Manuel Vargas':'Universitario|Colón|Catania|Fiorentina|Genoa|Fiorentina|Real Betis|Universitario',
 'Roberto Soldado':'Real Madrid|Osasuna|Real Madrid|Getafe|Valencia|Tottenham Hotspur|Villarreal|Fenerbahçe|Granada|Levante',
 'Albert Riera':'Mallorca|Bordeaux|Espanyol|Manchester City|Espanyol|Liverpool|Olympiacos|Galatasaray|Watford|Mallorca|Zavrč|Koper',
 'Albert Luque':'Mallorca|Málaga|Mallorca|Deportivo La Coruña|Newcastle United|Ajax|Málaga',
 'Pedro Munitis':'Santoña|Racing Santander|Badajoz|Racing Santander|Real Madrid|Racing Santander|Deportivo La Coruña|Racing Santander',
 'Javier Saviola':'River Plate|Barcelona|Monaco|Sevilla|Barcelona|Real Madrid|Benfica|Málaga|Olympiacos|Verona|River Plate',
 "Andrés D'Alessandro":'River Plate|VfL Wolfsburg|Portsmouth|Zaragoza|San Lorenzo|Internacional|River Plate|Internacional|Nacional|Internacional',
 'Michael Carrick':'West Ham United|Swindon Town|West Ham United|Birmingham City|West Ham United|Tottenham Hotspur|Manchester United',
 'Joe Cole':'West Ham United|Chelsea|Liverpool|Lille|Liverpool|West Ham United|Aston Villa|Coventry City|Tampa Bay Rowdies',
 'Stewart Downing':'Middlesbrough|Sunderland|Middlesbrough|Aston Villa|Liverpool|West Ham United|Middlesbrough|Blackburn Rovers',
 'Teddy Sheringham':'Millwall|Aldershot|Djurgårdens IF|Millwall|Nottingham Forest|Tottenham Hotspur|Manchester United|Tottenham Hotspur|Portsmouth|West Ham United|Colchester United',
 'Les Ferdinand':'Southall|Hayes|Queens Park Rangers|Brentford|Beşiktaş|Queens Park Rangers|Newcastle United|Tottenham Hotspur|West Ham United|Leicester City|Bolton Wanderers|Reading',
 'Djibril Cissé':'Auxerre|Liverpool|Marseille|Sunderland|Panathinaikos|Lazio|Queens Park Rangers|Al-Gharafa|Kuban Krasnodar|Bastia|Saint-Pierroise|Yverdon',
 'Florent Malouda':'Châteauroux|Guingamp|Lyon|Chelsea|Trabzonspor|Metz|Delhi Dynamos|Wadi Degla|Delhi Dynamos|FC Differdange 03',
 'Louis Saha':'Metz|Newcastle United|Metz|Fulham|Manchester United|Everton|Tottenham Hotspur|Sunderland|Lazio',
 'Vikash Dhorasoo':'Le Havre|Lyon|Bordeaux|Lyon|AC Milan|Paris Saint-Germain',
 'Alou Diarra':'Louhans-Cuiseaux|Le Havre|Bastia|Lens|Lyon|Bordeaux|Marseille|West Ham United|Rennes|West Ham United|Charlton Athletic|Nancy',
 'Sébastien Squillaci':'Toulon|Ajaccio|Monaco|Lyon|Sevilla|Arsenal|Bastia',
 'Florent Sinama Pongolle':'Le Havre|Liverpool|Blackburn Rovers|Recreativo|Atlético Madrid|Sporting CP|Zaragoza|Saint-Étienne|Rostov|Chicago Fire|Dundee United|Chainat Hornbill|Saint-Pierroise',
 'Anthony Le Tallec':'Le Havre|Liverpool|Saint-Étienne|Liverpool|Sunderland|Sochaux|Le Mans|Auxerre|Valenciennes|Atromitos|Astra Giurgiu|Orléans|Annecy',
 'Ibrahim Ba':'Le Havre|Bordeaux|AC Milan|Perugia|AC Milan|Marseille|AC Milan|Bolton Wanderers|Çaykur Rizespor|Djurgården',
 'Hakan Yakin':'Concordia Basel|Basel|Grasshoppers|St. Gallen|Grasshoppers|Basel|VfB Stuttgart|Galatasaray|Young Boys|Al-Gharafa|Luzern|Bellinzona',
 'Marco Streller':'Arlesheim|Basel|Concordia Basel|Basel|Thun|Basel|VfB Stuttgart|1. FC Köln|VfB Stuttgart|Basel',
 'Tranquillo Barnetta':'St. Gallen|Hannover 96|Bayer Leverkusen|Schalke 04|Eintracht Frankfurt|Schalke 04|Philadelphia Union|St. Gallen',
 'Blerim Džemaili':'Zürich|Bolton Wanderers|Torino|Parma|Napoli|Galatasaray|Genoa|Bologna|Montreal Impact|Bologna|Zürich',
 'Philippe Senderos':'Servette|Arsenal|AC Milan|Arsenal|Everton|Fulham|Valencia|Aston Villa|Grasshoppers|Rangers|Houston Dynamo|Chiasso',
 'Johan Djourou':'Arsenal|Birmingham City|Arsenal|Hannover 96|Hamburger SV|Antalyaspor|SPAL|Sion|Neuchâtel Xamax|Nordsjælland',
 'Reto Ziegler':'Grasshoppers|Tottenham Hotspur|Hamburger SV|Wigan Athletic|Tottenham Hotspur|Sampdoria|Fenerbahçe|Lokomotiv Moscow|Fenerbahçe|Sassuolo|Sion|Luzern|FC Dallas|Lugano|Sion',
 'Sulley Muntari':'Udinese|Portsmouth|Inter Milan|Sunderland|Inter Milan|AC Milan|Al Ittihad|Pescara|Deportivo La Coruña|Albacete|Hearts of Oak',
 'Michael Essien':'Bastia|Lyon|Chelsea|Real Madrid|Chelsea|AC Milan|Panathinaikos|Persib Bandung|Sabail',
 'Yakubu (footballer)':'Julius Berger|Hapoel Kfar Saba|Maccabi Haifa|Portsmouth|Middlesbrough|Everton|Leicester City|Blackburn Rovers|Guangzhou R&F|Al-Rayyan|Reading|Kayserispor|Coventry City',
 'Obafemi Martins':'Reggiana|Inter Milan|Newcastle United|VfL Wolfsburg|Rubin Kazan|Birmingham City|Rubin Kazan|Levante|Seattle Sounders FC|Shanghai Shenhua|Wuhan',
 'Taye Taiwo':"Gabros International|Lobi Stars|Marseille|AC Milan|Queens Park Rangers|Dynamo Kyiv|Bursaspor|HJK Helsinki|Lausanne|AFC Eskilstuna|RoPS|Palm Beach Stars|Sant'Angelo|SalPa",
 'Asamoah Gyan':'Liberty Professionals|Udinese|Modena|Udinese|Rennes|Sunderland|Al Ain|Shanghai SIPG|Shabab Al Ahli|Kayserispor|NorthEast United|Legon Cities',
 'Khalilou Fadiga':'RFC Liège|Lommel|Club Brugge|Auxerre|Bolton Wanderers|Derby County|Bolton Wanderers|Coventry City|Gent|Germinal Beerschot',
 'Henri Camara':'ASC Jaraaf|Neuchâtel Xamax|Grasshoppers|Sedan|Wolverhampton Wanderers|Celtic|Southampton|Wigan Athletic|West Ham United|Wigan Athletic|Stoke City|Sheffield United|Atromitos|Panetolikos|AEL Kalloni|Lamia|Panetolikos|Apollon Smyrnis|Ionikos|Fostiras',
 'Diomansy Kamara':'Red Star|Catanzaro|Modena|Portsmouth|West Bromwich Albion|Fulham|Celtic|Fulham|Leicester City|Eskişehirspor|Catanzaro|NorthEast United',
 'Souleymane Camara':'Monaco|Guingamp|Monaco|Nice|Montpellier',
 'Mamadou Niang':'Troyes|Metz|Strasbourg|Marseille|Fenerbahçe|Al Sadd|Beşiktaş|Al Sadd|Arles-Avignon',
 "Dame N'Doye":"Jeanne d'Arc|Al-Sadd|Académica|Panathinaikos|OFI|Copenhagen|Lokomotiv Moscow|Hull City|Trabzonspor|Sunderland|Trabzonspor|Copenhagen",
 'Moussa Sow':'Rennes|Sedan|Rennes|Lille|Fenerbahçe|Shabab Al Ahli|Fenerbahçe|Shabab Al Ahli|Bursaspor|Gazişehir Gaziantep|Ümraniyespor',
 'Mohamed Zidan':'AB|Midtjylland|Werder Bremen|Mainz 05|Werder Bremen|Mainz 05|Hamburger SV|Borussia Dortmund|Mainz 05|Baniyas|El Entag El Harby',
 'Rabah Madjer':'NA Hussein Dey|Racing Paris|Tours|Porto|Valencia|Porto|Qatar SC',
 'Anthony Annan':'Sekondi Hasaacas|Hearts of Oak|Start|Stabæk|Rosenborg|Schalke 04|Vitesse|Osasuna|Schalke 04|HJK|1860 Munich|Stabæk|HJK|Beitar Jerusalem|Inter Turku|TPS|DJK Arminia Lirich',
 'Didier Deschamps':'Nantes|Marseille|Bordeaux|Marseille|Juventus|Chelsea|Valencia',
 'Emmanuel Adebayor':'Metz|Monaco|Arsenal|Manchester City|Real Madrid|Tottenham Hotspur|Crystal Palace|İstanbul Başakşehir|Kayserispor|Olimpia',
 'Tony Yeboah':'Asante Kotoko|Cornerstone|Okwawu United|1. FC Saarbrücken|Eintracht Frankfurt|Leeds United|Hamburger SV|Al-Ittihad Doha',
 'Roque Santa Cruz':'Olimpia|Bayern Munich|Blackburn Rovers|Manchester City|Blackburn Rovers|Betis|Málaga|Cruz Azul|Málaga|Olimpia|Libertad|Nacional (Paraguay)',
};
const extraSources = {
 'Frank Lampard':['https://www.swanseacity.com/news/world-cup-swans-frank-lampard','https://www.newyorkcityfc.com/news/frank-lampard-s-road-300'],
 'Johan Cruyff':['https://www.fcbarcelona.com/en/news/1629219/johan-cruyff-an-incomparable-legend/amp'],
 'Roberto Carlos':['https://terceirotempo.uol.com.br/noticias/achados-perdidos-completando-53-anos-roberto-carlos-teve-passagem-meteorica-pelo-galo'],
 'Lothar Matthäus':['https://rsssf.org/players/dzdmatthaeus.html','https://lok-leipzig.com/verein/geschichte/vereinshistorie'],
 'Marco Streller':['https://www.fcb.ch/fileadmin/Static_Pages/Rotblau_Magazin/2015/rotblau_15_2015.pdf','https://www.national-football-teams.com/player/6417/Marco_Streller.html'],
 'Miroslav Klose':['https://fck.de/blog/45-geburtstag-miroslav-klose/','https://www.fifa.com/de/articles/miroslav-kloses-deutschland-debut-dfb-nationalmannschaft-25-jahre'],
 'Anthony Annan':['https://www.fupa.net/player/anthony-annan-45506','https://www.arminia-lirich.de/wp-content/uploads/2015/08/Chronik_1920-2024b.pdf','https://schalke04.de/verein/tradition/alle-spiele-alle-tore/europapokal/champions-league-20132014/'],
 'Taye Taiwo':['https://www.national-football-teams.com/player/8595/Taye_Taiwo.html'],
 'Hakan Yakin':['https://www.national-football-teams.com/player/6441/Hakan_Yakin.html'],
 'Robert Pires':['https://archivesreimsfootball.fr/personnalites/pires-robert'],
 'Lilian Thuram':['https://www.fff.fr/equipe-nationale/joueur/8540-thuram-lilian/fiche.html'],
 'Mamadou Niang':['https://www.ogol.com.br/jogador/mamadou-niang/3827'],
 "Dame N'Doye":['https://www.oncloudseven.com/1001-dame-ndoye/'],
 'Emmanuel Adebayor':['https://africacheck.org/fr/fact-checks/meta-programme-fact-checks/Sport-football-Togo-Emmanuel-Adebayor-retraite'],
 'Sabri Lamouchi':['https://www.national-football-teams.com/player/10687/Sabri_Lamouchi.html'],
};
const zeroLeagueIncluded = new Set(['Blerim Džemaili:Bolton Wanderers','John Obi Mikel:Kuwait SC']);
const aliases = {
 Milan:'AC Milan', 'AS Monaco':'Monaco', 'Internazionale':'Inter Milan',
 Betis:'Real Betis', 'HFC Haarlem':'Haarlem', 'FC Basel':'Basel',
 'Deportivo la Coruña':'Deportivo La Coruña', 'Wolfsburg':'VfL Wolfsburg',
 '1. FC Kaiserslautern':'Kaiserslautern', 'SV Salzburg':'Austria Salzburg',
 'Al Jazira':'Al-Jazira', 'Gimnasia LP':'Gimnasia La Plata',
 'GCB Mascara':'GC Mascara', 'GCR Mascara':'GC Mascara',
 'MP Oran':'MC Oran', "Mouloudia d'Oran":'MC Oran','M. Oran / MC Oran':'MC Oran',
 'MP Alger':'MC Alger', Goa:'FC Goa',
};
const excludedYouth = {
 'Petr Čech':['Viktoria Plzeň'], 'Alan Shearer':['Southampton'],
};
const reserve = club=>club!=='Willem II' && (/(?: II| B| C| 2| \(A\))$/.test(club)||['Bilbao Athletic','Basconia','Dynamo-2 Kyiv','Shakhtar-2 Donetsk','Sevilla Atlético'].includes(club));
const records = source.map(p=>{
 let clubs = overrides[p.page]?.split('|') || p.rows
  .filter(r=>!reserve(r.club.replace(/^→ /,'').replace(/ \(loan\)$/, '')))
  .filter(r=>!(excludedYouth[p.page]?.includes(r.club)&&r.apps===''))
  .filter(r=>r.apps!=='0'||zeroLeagueIncluded.has(p.page+':'+r.club))
  .map(r=>r.club.replace(/^→ /,'').replace(/ \(loan\)$/,''));
 clubs=clubs.map(c=>aliases[c]||c).filter((c,i,a)=>i===0||c!==a[i-1]);
 return {name:p.name,page:p.page,points:p.points,clubsEnglish:clubs,reviewedAt:p.reviewedAt,sources:[p.source,...(extraSources[p.page]||[])]};
});
const missing=[...new Set(records.flatMap(p=>p.clubsEnglish).filter(c=>!translations[c]))].sort();
if(missing.length){console.log(missing.join('\n'));process.exitCode=1;}else{
 for(const p of records)p.clubs=p.clubsEnglish.map(c=>translations[c]);
 fs.writeFileSync('tools/player_career_additions_reviewed.json',JSON.stringify(records,null,2)+'\n');
 console.log(`Compiled ${records.length} new complete playing careers.`);
}
