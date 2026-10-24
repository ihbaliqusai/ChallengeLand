import 'package:flutter/material.dart';

import '../core/trophy_league.dart';

/// The same player-facing rules are available from profile and statistics.
void showProgressionGuide(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF091224),
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.85,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(children: [
                const Expanded(
                    child: Text('دليل التقدم والمكافآت',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900))),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'إغلاق',
                    color: Colors.white,
                    icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 12),
              const _GuideSection(
                title: 'المستوى ورتبة الخبرة',
                text:
                    'نقاط الخبرة تراكمية ولا تنقص بالخسارة. كل مستوى يقربك من رتبة خبرة جديدة ويفتح شخصيات إضافية. رتبة الخبرة مستقلة عن الدوري.',
              ),
              const _GuideSection(
                title: 'الخبرة في جميع أطوار اللعب',
                text: 'الإجابة الصحيحة: 10 XP • الخاطئة: 3 XP.\n'
                    'إتمام مباراة فردية أو حملة: الفوز 80، التعادل 40، الخسارة 20 XP.\n'
                    'الفرق المحلية على الجهاز نفسه: 40 XP للإتمام المشترك، وتُجمع خبرة إجابات جميع الفرق للحساب نفسه.\n'
                    'إتمام مباراة أونلاين: الفوز 100، التعادل 50، الخسارة 30 XP.\n'
                    'مكافآت نجوم الحملة إضافية. الانسحاب لا يمنح مكافأة إتمام.\n'
                    'لا تُمنح مكافأة الإتمام أو الكؤوس لمباراة بلا أي إجابة محتسبة.',
              ),
              const _GuideSection(
                title: 'الكؤوس والدوري',
                text:
                    'تتراكم الكؤوس من نتائج المباريات في جميع الأطوار. رصيدك الحالي يحدد الدوري ودرجته، وأفضل رصيد يحتفظ بأعلى إنجاز وصلت إليه. كل مباراة تحتسب مرة واحدة، والتعادل في الأطوار التنافسية لا يغير الكؤوس.',
              ),
              const _GuideSection(
                title: 'مكافأة الفرق المحلية',
                text:
                    'إتمام مباراة فرق محلية مع إجابة محتسبة واحدة على الأقل يمنح الحساب +6 كؤوس كمكافأة مشاركة مشتركة. تُسجل النتيجة تعادلاً للحساب، فلا تُحسب فوزاً شخصياً ولا تزيد سلسلة الفوز. التعادل في بقية الأطوار يمنح 0 كؤوس.',
              ),
              for (final rule in TrophyProgression.rules)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(rule.icon, color: rule.color),
                  title: Text(rule.label,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13)),
                  trailing: Text(rule.value,
                      style: TextStyle(
                          color: rule.color, fontWeight: FontWeight.bold)),
                ),
              const _GuideSection(
                title: 'لوحة الصدارة',
                text:
                    'سباق الكؤوس يرتب اللاعبين حسب رصيدهم الحالي. صدارة المستوى ترتبهم حسب إجمالي الخبرة XP، بما في ذلك التقدم داخل المستوى نفسه. تعرض كل قائمة أفضل 200 لاعب.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xFFFACC15),
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(text,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.7)),
        ]),
      );
}
