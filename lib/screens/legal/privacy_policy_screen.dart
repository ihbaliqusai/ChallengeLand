import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/privacy_policy_content.g.dart';
import '../../services/native_bridge_service.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  static const _ink = Color(0xFF25283D);
  static const _muted = Color(0xFF656B80);
  static const _purple = Color(0xFF7047DB);
  final _search = TextEditingController();
  final _reader = ScrollController();
  final _sectionKeys = {
    for (final section in PrivacyPolicyContent.sections)
      section.id: GlobalKey(),
  };

  List<PrivacyPolicySection> get _visibleSections {
    final query = _search.text.trim().toLowerCase();
    return PrivacyPolicyContent.sections
        .where((section) =>
            query.isEmpty ||
            '${section.title} ${section.paragraphs.join(' ')}'
                .toLowerCase()
                .contains(query))
        .toList();
  }

  Future<void> _openLink(String url) async {
    final opened = await NativeBridgeService().openExternalUrl(url);
    if (!mounted || opened) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) _notice('تم نسخ الرابط لفتحه في المتصفح');
  }

  Future<void> _contact() async {
    final opened = await NativeBridgeService().composeSupportEmail(
      recipient: PrivacyPolicyContent.contactEmail,
      subject: 'طلب خصوصية — أرض التحدي',
      body: 'مرحبًا فريق أرض التحدي،\nأرغب في التواصل بشأن خصوصية بياناتي:\n\n',
    );
    if (!mounted || opened) return;
    await Clipboard.setData(
        const ClipboardData(text: PrivacyPolicyContent.contactEmail));
    if (mounted) _notice('تم نسخ بريد فريق الخصوصية');
  }

  void _notice(String message) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

  void _jumpTo(String id) {
    final sectionContext = _sectionKeys[id]?.currentContext;
    if (sectionContext == null) return;
    Scrollable.ensureVisible(
      sectionContext,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: .02,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _reader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF151B30),
          body: SafeArea(
            child: LayoutBuilder(builder: (context, area) {
              final wide = area.maxWidth >= 840 && area.maxHeight >= 420;
              final sections = _visibleSections;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: Row(children: [
                    const Icon(Icons.privacy_tip_outlined,
                        color: Color(0xFFC7B5FF), size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('سياسة الخصوصية',
                              style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          Text(
                              'أرض التحدي · آخر تحديث: '
                              '${PrivacyPolicyContent.updatedAt}',
                              style: TextStyle(
                                  color: Color(0xFFB8BFD4), fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'العودة',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white),
                    ),
                  ]),
                ),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF4F4FA),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(22)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(wide ? 20 : 14),
                      child: Column(children: [
                        Theme(
                          data: ThemeData(
                            brightness: Brightness.light,
                            fontFamily: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.fontFamily,
                            fontFamilyFallback: const ['NotoSansArabic'],
                            colorScheme:
                                ColorScheme.fromSeed(seedColor: _purple),
                          ),
                          child: TextField(
                            key: const ValueKey('privacy-search'),
                            controller: _search,
                            onChanged: (_) {
                              setState(() {});
                              if (_reader.hasClients) _reader.jumpTo(0);
                            },
                            style: const TextStyle(color: _ink, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'ابحث في سياسة الخصوصية',
                              hintStyle: const TextStyle(
                                  color: _muted, fontSize: 15),
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'مسح البحث',
                                      onPressed: () => setState(_search.clear),
                                      icon: const Icon(Icons.close_rounded)),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.all(12),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE0DFEC))),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (wide) ...[
                                SizedBox(
                                    width: 228, child: _contents(sections)),
                                const SizedBox(width: 20),
                              ],
                              Expanded(
                                child: SelectionArea(
                                  child: SingleChildScrollView(
                                    key: const ValueKey('privacy-reader'),
                                    controller: _reader,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (_search.text.isEmpty) ...[
                                          _overview(),
                                          const SizedBox(height: 16),
                                          if (!wide) ...[
                                            _contents(sections, compact: true),
                                            const SizedBox(height: 16),
                                          ],
                                        ],
                                        if (sections.isEmpty)
                                          _paper(const Text(
                                              'لا توجد نتائج. جرّب كلمة أخرى.',
                                              style: TextStyle(color: _muted))),
                                        for (final section in sections)
                                          _section(section),
                                        if (_search.text.isEmpty) ...[
                                          _contactCard(),
                                          const SizedBox(height: 16),
                                          _credits(),
                                        ],
                                        const SizedBox(height: 18),
                                        const Text(
                                            '${PrivacyPolicyContent.publisher}\n'
                                            'إصدار السياسة ${PrivacyPolicyContent.version}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: _muted,
                                                fontSize: 12,
                                                height: 1.6)),
                                        const SizedBox(height: 12),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]);
            }),
          ),
        ),
      );

  Widget _paper(Widget child) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E4EE)),
        ),
        child: child,
      );

  Widget _overview() => _paper(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('خصوصيتك، بوضوح',
              style: TextStyle(
                  color: _ink, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text(PrivacyPolicyContent.introduction,
              style: TextStyle(color: _muted, fontSize: 15, height: 1.8)),
          const SizedBox(height: 18),
          for (final highlight in PrivacyPolicyContent.highlights)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: _purple, size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: '${highlight.title}\n',
                              style: const TextStyle(
                                  color: _ink, fontWeight: FontWeight.w700)),
                          TextSpan(text: highlight.text),
                        ]),
                        style: const TextStyle(
                            color: _muted, fontSize: 14, height: 1.7))),
              ]),
            ),
        ],
      ));

  Widget _contents(List<PrivacyPolicySection> sections,
      {bool compact = false}) {
    final links = [
      for (var index = 0; index < sections.length; index++)
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: EdgeInsets.zero,
          title: Text(
              '${PrivacyPolicyContent.sections.indexOf(sections[index]) + 1}. ${sections[index].title}',
              style: const TextStyle(color: _ink, fontSize: 13)),
          onTap: () => _jumpTo(sections[index].id),
        ),
    ];
    return _paper(compact
        ? ExpansionTile(
            key: const PageStorageKey('privacy-contents'),
            tilePadding: EdgeInsets.zero,
            iconColor: _purple,
            collapsedIconColor: _purple,
            title: const Text('محتويات السياسة',
                style: TextStyle(
                    color: _purple, fontSize: 15, fontWeight: FontWeight.w700)),
            children: links,
          )
        : SingleChildScrollView(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('محتويات السياسة',
                  style: TextStyle(
                      color: _purple,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...links,
            ],
          )));
  }

  Widget _section(PrivacyPolicySection section) => Padding(
        key: _sectionKeys[section.id],
        padding: const EdgeInsets.only(bottom: 16),
        child: _paper(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('القسم ${PrivacyPolicyContent.sections.indexOf(section) + 1}',
              style: const TextStyle(
                  color: _purple, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(section.title,
              style: const TextStyle(
                  color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          ..._paragraphs(section),
        ])),
      );

  List<Widget> _paragraphs(PrivacyPolicySection section) => [
        for (final paragraph in section.paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(paragraph,
                style:
                    const TextStyle(color: _ink, fontSize: 15, height: 1.85)),
          ),
        if (section.links.isNotEmpty)
          Wrap(spacing: 12, runSpacing: 4, children: [
            for (final link in section.links)
              TextButton.icon(
                onPressed: () => _openLink(link.url),
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: Text(link.label),
                style: TextButton.styleFrom(
                    foregroundColor: _purple,
                    textStyle: const TextStyle(fontSize: 13)),
              ),
          ]),
      ];

  Widget _contactCard() => _paper(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('لديك طلب بخصوص بياناتك؟',
              style: TextStyle(
                  color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text(
              'تواصل مع الفريق لطلبات الخصوصية أو حقوق الأطفال '
              'وأولياء الأمور أو حذف البيانات. لا ترسل كلمات المرور أو رموز التحقق.',
              style: TextStyle(color: _muted, fontSize: 15, height: 1.8)),
          const SizedBox(height: 12),
          const Text(PrivacyPolicyContent.contactEmail,
              textDirection: TextDirection.ltr,
              style: TextStyle(color: _purple, fontSize: 15)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: _contact,
              style: FilledButton.styleFrom(
                  backgroundColor: _purple, foregroundColor: Colors.white),
              icon: const Icon(Icons.mail_outline_rounded, size: 18),
              label: const Text('مراسلة فريق الخصوصية'),
            ),
            OutlinedButton(
              onPressed: () => _openLink(PrivacyPolicyContent.deletionUrl),
              style: OutlinedButton.styleFrom(
                  foregroundColor: _purple,
                  side: const BorderSide(color: Color(0xFFBCA6EE))),
              child: const Text('طلب حذف الحساب'),
            ),
          ]),
        ],
      ));

  Widget _credits() => _paper(ExpansionTile(
        key: const PageStorageKey('privacy-credits'),
        tilePadding: EdgeInsets.zero,
        iconColor: _purple,
        collapsedIconColor: _purple,
        title: const Text('اعتمادات المحتوى والتراخيص',
            style: TextStyle(
                color: _ink, fontSize: 16, fontWeight: FontWeight.w700)),
        subtitle: const Text('ملحق مستقل عن سياسة معالجة البيانات',
            style: TextStyle(color: _muted, fontSize: 12)),
        children: _paragraphs(PrivacyPolicyContent.credits),
      ));
}
