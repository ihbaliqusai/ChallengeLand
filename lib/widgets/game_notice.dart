import 'dart:async';

import 'package:flutter/material.dart';

enum GameNoticeTone { info, success, warning, error, friend, challenge }

extension GameNoticeStyle on GameNoticeTone {
  Color get color => switch (this) {
        GameNoticeTone.success => const Color(0xFF6EE7B7),
        GameNoticeTone.warning => const Color(0xFFFBBF24),
        GameNoticeTone.error => const Color(0xFFFB7185),
        GameNoticeTone.friend => const Color(0xFFA78BFA),
        GameNoticeTone.challenge => const Color(0xFFFBBF24),
        GameNoticeTone.info => const Color(0xFF67D9F5),
      };

  IconData get icon => switch (this) {
        GameNoticeTone.success => Icons.check_rounded,
        GameNoticeTone.warning => Icons.priority_high_rounded,
        GameNoticeTone.error => Icons.error_outline_rounded,
        GameNoticeTone.friend => Icons.person_add_alt_1_rounded,
        GameNoticeTone.challenge => Icons.sports_esports_rounded,
        GameNoticeTone.info => Icons.notifications_active_outlined,
      };

  String title(bool arabic) => switch (this) {
        GameNoticeTone.success => arabic ? 'تم بنجاح' : 'Success',
        GameNoticeTone.warning => arabic ? 'انتبه' : 'Heads up',
        GameNoticeTone.error =>
          arabic ? 'تعذّر إكمال الطلب' : 'Something went wrong',
        GameNoticeTone.friend => arabic ? 'طلب صداقة جديد' : 'Friend request',
        GameNoticeTone.challenge =>
          arabic ? 'دعوة إلى التحدي' : 'Challenge invite',
        GameNoticeTone.info => arabic ? 'تنبيه' : 'Notice',
      };
}

/// The common frame for feedback, invitations, and confirmation dialogs.
/// Its body scrolls independently so actions stay reachable in landscape.
class GameNoticeCard extends StatelessWidget {
  const GameNoticeCard({
    super.key,
    required this.content,
    this.title,
    this.tone = GameNoticeTone.info,
    this.actions = const [],
    this.onClose,
    this.progress,
    this.busy = false,
  });

  final Widget content;
  final Widget? title;
  final GameNoticeTone tone;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final double? progress;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar' ||
        Directionality.of(context) == TextDirection.rtl;
    final accent = tone.color;
    final theme = Theme.of(context);
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final buttonText = TextStyle(
        fontFamily: theme.textTheme.bodyMedium?.fontFamily,
        fontWeight: FontWeight.w800,
        fontSize: 14);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.scale(scale: 0.94 + value * 0.06, child: child),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF172341), Color(0xFF0C1329), Color(0xFF10152D)],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.13), blurRadius: 36),
              const BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 32,
                  offset: Offset(0, 16)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Material(
              type: MaterialType.transparency,
              child: Theme(
                data: theme.copyWith(
                  filledButtonTheme: FilledButtonThemeData(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF0B1328),
                      minimumSize: const Size(110, 46),
                      textStyle: buttonText,
                      shape: shape,
                    ),
                  ),
                  elevatedButtonTheme: ElevatedButtonThemeData(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF0B1328),
                      minimumSize: const Size(110, 46),
                      textStyle: buttonText,
                      shape: shape,
                    ),
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFCBD5E1),
                      minimumSize: const Size(88, 46),
                      textStyle: buttonText,
                      shape: shape,
                    ),
                  ),
                  outlinedButtonTheme: OutlinedButtonThemeData(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3B4562)),
                      minimumSize: const Size(100, 46),
                      textStyle: buttonText,
                      shape: shape,
                    ),
                  ),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        accent.withValues(alpha: 0),
                        accent,
                        accent.withValues(alpha: 0),
                      ]),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                          height: 32,
                          child: Stack(alignment: Alignment.center, children: [
                            Text(arabic ? 'أرض التحدي' : 'CHALLENGE LAND',
                                style: TextStyle(
                                    color: accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: arabic ? 0 : 2.2)),
                            if (onClose != null)
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: Semantics(
                                  label: arabic ? 'إغلاق' : 'Close',
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                    onPressed: onClose,
                                    icon: const Icon(Icons.close_rounded,
                                        size: 19, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                              ),
                          ]),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent.withValues(alpha: 0.24),
                                accent.withValues(alpha: 0.06)
                              ],
                            ),
                            border: Border.all(
                                color: accent.withValues(alpha: 0.4)),
                          ),
                          child: Icon(tone.icon, color: accent, size: 30),
                        ),
                        const SizedBox(height: 14),
                        DefaultTextStyle.merge(
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              height: 1.35,
                              fontWeight: FontWeight.w800),
                          child: title ?? Text(tone.title(arabic)),
                        ),
                        const SizedBox(height: 10),
                        DefaultTextStyle.merge(
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 14,
                              height: 1.65,
                              fontWeight: FontWeight.w500),
                          child: content,
                        ),
                      ]),
                    ),
                  ),
                  if (actions.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                      decoration: const BoxDecoration(
                        color: Color(0x30000000),
                        border:
                            Border(top: BorderSide(color: Color(0x18FFFFFF))),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: actions,
                      ),
                    ),
                  if (busy || progress != null)
                    LinearProgressIndicator(
                      value: busy ? null : progress!.clamp(0.0, 1.0),
                      minHeight: 3,
                      color: accent,
                      backgroundColor: accent.withValues(alpha: 0.08),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps existing message content, actions and timing while presenting every
/// former snackbar in the same centered game card, including above dialogs.
class GameNoticeMessenger {
  GameNoticeMessenger._(this._overlay, this._themes, this._direction);

  static final _instances = Expando<GameNoticeMessenger>();
  final OverlayState _overlay;
  CapturedThemes _themes;
  TextDirection _direction;
  OverlayEntry? _entry;
  Timer? _timer;

  static GameNoticeMessenger of(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final themes = InheritedTheme.capture(from: context, to: overlay.context);
    final direction = Directionality.of(context);
    final instance = _instances[overlay] ??=
        GameNoticeMessenger._(overlay, themes, direction);
    instance._themes = themes;
    instance._direction = direction;
    return instance;
  }

  void hideCurrentSnackBar() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  void showSnackBar(SnackBar message, {GameNoticeTone? tone}) {
    if (!_overlay.mounted) return;
    hideCurrentSnackBar();
    final resolvedTone = tone ?? _toneFor(message);
    final duration = message.duration;
    Timer? expiry;
    final entry = OverlayEntry(builder: (context) {
      final action = message.action;
      return _NoticeLifetime(
          onDispose: () => expiry?.cancel(),
          child: _themes.wrap(Directionality(
            textDirection: _direction,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    child: GameNoticeCard(
                      key: ObjectKey(message),
                      tone: resolvedTone,
                      content: message.content,
                      onClose: hideCurrentSnackBar,
                      actions: action == null
                          ? const []
                          : [
                              FilledButton(
                                onPressed: () {
                                  hideCurrentSnackBar();
                                  action.onPressed();
                                },
                                child: Text(action.label),
                              ),
                            ],
                      progress: null,
                    ),
                  ),
                ),
              ),
            ),
          )));
    });
    _entry = entry;
    _overlay.insert(entry);
    message.onVisible?.call();
    // Actionable messages stay available to assistive technologies.
    if (!(message.action != null &&
        MediaQuery.accessibleNavigationOf(_overlay.context))) {
      expiry = _timer = Timer(duration, hideCurrentSnackBar);
    }
  }

  void show(String message, {GameNoticeTone tone = GameNoticeTone.info}) {
    showSnackBar(SnackBar(content: Text(message)), tone: tone);
  }

  GameNoticeTone _toneFor(SnackBar message) {
    final text = _plainText(message.content).toLowerCase();
    if (RegExp(r'تعذر|تعذّر|فشل|خطأ|غير صحيح|failed|error').hasMatch(text)) {
      return GameNoticeTone.error;
    }
    if (RegExp(
            r'لا يوجد|غير متوفر|تحتاج|أولًا|أولاً|لا يمكنك|لم يكتمل|not enough|offline')
        .hasMatch(text)) {
      return GameNoticeTone.warning;
    }
    if (RegExp(r'^تم|^أُرسلت|^شكرا|^شكراً|بنجاح|مبروك|success|copied')
        .hasMatch(text)) {
      return GameNoticeTone.success;
    }
    return GameNoticeTone.info;
  }

  static String _plainText(Widget widget) {
    if (widget is Text) {
      return widget.data ?? widget.textSpan?.toPlainText() ?? '';
    }
    if (widget is Flex) return widget.children.map(_plainText).join(' ');
    if (widget is Flexible) return _plainText(widget.child);
    return '';
  }
}

class _NoticeLifetime extends StatefulWidget {
  const _NoticeLifetime({required this.onDispose, required this.child});
  final VoidCallback onDispose;
  final Widget child;
  @override
  State<_NoticeLifetime> createState() => _NoticeLifetimeState();
}

class _NoticeLifetimeState extends State<_NoticeLifetime> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Uses the common frame without changing existing dialog results or callbacks.
class GameAlertDialog extends AlertDialog {
  const GameAlertDialog({
    super.key,
    super.title,
    super.content,
    super.actions,
    super.backgroundColor,
    super.shape,
    super.contentPadding,
    super.titlePadding,
    super.actionsPadding,
    super.actionsAlignment,
    super.scrollable,
    this.tone = GameNoticeTone.info,
  });

  final GameNoticeTone tone;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: GameNoticeCard(
          title: title,
          tone: tone,
          content: content ?? const SizedBox.shrink(),
          actions: actions ?? const [],
        ),
      );
}
