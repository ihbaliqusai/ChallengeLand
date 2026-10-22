const fs=require('fs'),path=require('path');const {r,edit:e,save}=require('./review_tools.cjs');
e(1831,{Q:'ما العضو الذي يحوّل الأمونيا السامة إلى يوريا للتخلص منها لاحقًا عبر البول؟',R:'الكبد',Level:'4'},'استبدال تكرار أكبر عضو داخلي بسؤال عن دورة اليوريا','deduplicate');
e(829,{Q:'أي الرئتين أكبر حجمًا عادةً عند الإنسان؟'},'إزالة أسماء الجانبين من متن السؤال');
e(7817,{Q:'ما الطائر الذي استخدمه عمال مناجم الفحم قديمًا للإنذار المبكر بوجود غازات سامة؟',Level:'4'},'حذف اسم الكناري من السؤال وإبقاء سؤال مستقل');
e(8306,{Q:'في أي عضية تتركز معظم المادة الوراثية للخلية البشرية؟'},'إزالة اسم النواة من السؤال');
e(1794,{Q:'ما المقياس اللوغاريتمي الذي طُوّر سنة 1935 للتعبير عن مقدار الزلازل المحلية؟'},'حذف اسم صاحب المقياس لأنه يكشف الجواب');
e(8277,{Q:'ما الرباط الذي يصل الحافة السفلية للرضفة بالحدبة الظنبوبية؟'},'حذف مرادف الإجابة من متن السؤال');
e(7415,{Q:'ما نوع الأشعة الذي تساعد صبغة الميلانين على امتصاصه وحماية الجلد منه؟',R:'الأشعة فوق البنفسجية',W1:'الأشعة تحت الحمراء',W2:'موجات الراديو',W3:'الموجات الدقيقة'},'سؤال محدد بإجابة قصيرة دون إعادة الوظيفة المطلوبة في السؤال');
e(7776,{Q:'ما الطائر الكبير آكل الجيف الذي تمتلك أنواع كثيرة منه رأسًا ورقبة عاريين أو قليلي الريش؟'},'حذف المثال الملتبس بالنسر الأصلع والاكتفاء بالصفة المقصودة');
e(882,{W3:'الحبار المخطط'},'الحبار الضخم من مجموعة الحبار الزجاجي فلا يصح جعل المجموعة مشتتًا');
const sources={
180:['https://www.oecdnea.org/upload/docs/application/pdf/2025-04/7683_uranium_2024_-_resources_production_and_demand_2025-04-22_14-29-2_928.pdf'],
231:['https://ismi.mpiwg-berlin.mpg.de/witness/58361'],
257:['https://www.ncbi.nlm.nih.gov/books/NBK448209/'],
600:['https://starchild.gsfc.nasa.gov/docs/StarChild/solar_system_level2/'],
810:['https://pmc.ncbi.nlm.nih.gov/articles/PMC2868182/'],
906:['https://www.redcrossblood.org/local-homepage/news/article/blood-banks-defined.html'],
1924:['https://www.ncbi.nlm.nih.gov/sites/books/NBK537082/'],
5899:['https://www.nationalacademies.org/read/10925/chapter/8'],
8371:['https://www.montereybayaquarium.org/animals-the-ocean/animals-a-to-z/sea-otter','https://nrm.dfg.ca.gov/FileHandler.ashx?DocumentID=76378']
};for(const [index,urls]of Object.entries(sources)){const edit=r.edits.find(x=>x.index===+index);if(edit)edit.sources=urls;}
r.edits.find(x=>x.index===1712).reason='استبدال سؤال مكرر عن سرعة الشاهين بسؤال مستقل عن تناظر أجسام الحيوانات.';
r.unresolved=r.unresolved.filter(x=>![1469,2072,1831].includes(x.index));
r.summary='مراجعة تحريرية جزئية توقفت بطلب المستخدم بعد انقطاع طويل وانقضاء المهلة: قُرئ 822 سؤالًا فعليًا من أصل 4469، تشمل جميع دفعات الحيوانات وعلوم وفضاء وجسم الإنسان. بقي 3647 سؤالًا في 59 دفعة لم تُقرأ. تتضمن التعديلات تصحيح حقائق وتصنيفات وصعوبة وصياغة وخيارات وإزالة تسرب الحل. جرى تحقق مصدري انتقائي للحقائق الطبية أو المشتبه بها؛ لا يُدّعى توثيق كل سؤال. قائمة unresolved تتضمن تكرارات معنوية لإحالتها للمراجعة العالمية وسؤالًا تراثيًا يحتاج مصدرًا. لم يُعدّل البنك المصدر مباشرة.';
const manifest=JSON.parse(fs.readFileSync(path.join(path.dirname(__dirname),'manifest.json'),'utf8'));
const reviewed=new Set(r.reviewedIndices);const batches=manifest.coverage.science.batches;
const remaining=batches.filter(b=>b.indices.some(i=>!reviewed.has(i))).map(b=>({file:b.file,category:b.category,count:b.indices.filter(i=>!reviewed.has(i)).length}));
fs.writeFileSync(path.join(__dirname,'remaining.json'),JSON.stringify({reviewed:reviewed.size,total:4469,remaining:4469-reviewed.size,batches:remaining},null,2)+'\n');
save();console.log(JSON.stringify({remainingBatches:remaining.length,remainingQuestions:4469-reviewed.size}));
