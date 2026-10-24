import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../services/native_bridge_service.dart';

Future<void> showSupportContact(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF091224),
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => const SupportContactSheet(),
    );

class SupportContactSheet extends StatefulWidget {
  const SupportContactSheet({super.key});

  static const email = 'IhbaliQusai@gmail.com';

  @override
  State<SupportContactSheet> createState() => _SupportContactSheetState();
}

class _SupportContactSheetState extends State<SupportContactSheet> {
  static const _gold = Color(0xFFFFD761);
  final _message = TextEditingController();
  String _topic = 'سؤال';
  bool _opening = false;
  bool _mailOpened = false;
  bool _showCopy = false;
  String? _error;
  String? _copied;

  String get _subject => 'أرض التحدي - $_topic';

  String _body() {
    final user = context.read<AppState>().user;
    return [
      _message.text.trim(),
      '',
      'أرض التحدي',
      if (user != null) 'معرّف اللاعب: ${user.uid}',
      if (user?.displayName?.trim().isNotEmpty == true)
        'اسم اللاعب: ${user!.displayName!.trim()}',
    ].join('\n');
  }

  Future<void> _openEmail() async {
    if (_opening) return;
    if (_message.text.trim().isEmpty) {
      setState(() => _error = 'اكتب رسالتك أولاً');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _opening = true;
      _mailOpened = false;
      _error = null;
      _copied = null;
    });
    final opened =
        await context.read<NativeBridgeService>().composeSupportEmail(
              recipient: SupportContactSheet.email,
              subject: _subject,
              body: _body(),
            );
    if (!mounted) return;
    setState(() {
      _opening = false;
      _mailOpened = opened;
      _showCopy = !opened;
      if (!opened) {
        _error =
            'تعذر فتح تطبيق البريد. يمكنك نسخ البريد والرسالة وإرسالهما من بريدك.';
      }
    });
  }

  Future<void> _copy(String text, String feedback) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _copied = feedback);
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.support_agent_rounded, color: _gold),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('تواصل مع فريق العمل',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      tooltip: 'إغلاق التواصل',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70),
                    ),
                  ]),
                  const Text(
                    'لديك سؤال أو اقتراح أو واجهت مشكلة؟ اكتب لنا، ثم أكمل إرسال رسالتك عبر تطبيق البريد.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final topic in ['سؤال', 'اقتراح', 'مشكلة'])
                        ChoiceChip(
                          label: Text(topic),
                          selected: _topic == topic,
                          selectedColor: _gold.withValues(alpha: .2),
                          onSelected: _opening
                              ? null
                              : (_) => setState(() {
                                    _topic = topic;
                                    _mailOpened = false;
                                  }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('support-message'),
                    controller: _message,
                    enabled: !_opening,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 3000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'رسالتك',
                      hintText:
                          'اكتب سؤالك أو اقتراحك، أو صف المشكلة التي واجهتك…',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {
                      _error = null;
                      _mailOpened = false;
                      _copied = null;
                    }),
                  ),
                  Row(children: [
                    const Expanded(
                      child: SelectableText(SupportContactSheet.email,
                          textDirection: TextDirection.ltr,
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                    IconButton(
                      tooltip: 'نسخ البريد',
                      onPressed: () => _copy(SupportContactSheet.email,
                          'تم نسخ البريد الإلكتروني'),
                      icon: const Icon(Icons.copy_rounded,
                          color: _gold, size: 19),
                    ),
                  ]),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Color(0xFFFB7185), fontSize: 13)),
                    ),
                  if (_mailOpened)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                          'تم فتح تطبيق البريد. أكمل الإرسال من هناك لإيصال رسالتك إلى فريق العمل.',
                          style: TextStyle(
                              color: Color(0xFF6EE7B7), fontSize: 13)),
                    ),
                  if (_copied != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(_copied!,
                          style: const TextStyle(
                              color: Color(0xFF6EE7B7), fontSize: 13)),
                    ),
                  FilledButton.icon(
                    key: const ValueKey('support-open-email'),
                    onPressed: _opening ? null : _openEmail,
                    icon: _opening
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.mail_outline_rounded),
                    label: const Text('متابعة عبر البريد'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: const Color(0xFF091224),
                    ),
                  ),
                  if (_showCopy)
                    TextButton.icon(
                      onPressed: () => _copy(
                          'إلى: ${SupportContactSheet.email}\n'
                              'الموضوع: $_subject\n\n${_body()}',
                          'تم نسخ البريد والرسالة'),
                      icon: const Icon(Icons.content_copy_rounded),
                      label: const Text('نسخ البريد والرسالة'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}
