import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_settings.dart';
import '../services/rate_game_service.dart';

/// نافذة تقييم اللعبة بتصميم عالمي فاخر وموجه بذكاء (5-Star Smart Routing)
class RateGameDialog extends StatefulWidget {
  const RateGameDialog({super.key, this.isManual = false});

  final bool isManual;

  @override
  State<RateGameDialog> createState() => _RateGameDialogState();
}

class _RateGameDialogState extends State<RateGameDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  int _selectedStars = 5;
  bool _submitting = false;
  bool _feedbackSubmitted = false;
  bool _alreadyClaimedReward = false;

  final TextEditingController _feedbackController = TextEditingController();
  final Set<String> _selectedTags = <String>{};

  static const List<String> _feedbackOptions = [
    'صعوبة الأسئلة',
    'استقرار الاتصال',
    'أطوار لعب جديدة',
    'تصميم الواجهة',
    'مكافآت وتحديات',
    'أخرى',
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    RateGameService.instance.hasClaimedReward().then((claimed) {
      if (mounted) {
        setState(() => _alreadyClaimedReward = claimed);
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  int get _activeRating => _selectedStars;
  bool get _isPositiveRating => _selectedStars >= 4;

  void _onStarTap(int stars) {
    HapticFeedback.selectionClick();
    try {
      context.read<AppSettings>().playHaptic(style: 'light');
    } catch (_) {}

    setState(() {
      _selectedStars = stars;
    });
  }

  Future<void> _handlePositiveSubmit() async {
    HapticFeedback.heavyImpact();
    try {
      context.read<AppSettings>().playHaptic(style: 'heavy');
    } catch (_) {}

    setState(() => _submitting = true);

    final service = RateGameService.instance;
    await service.openStore(context);
    await service.markRated();

    if (mounted) {
      final rewardGranted = await service.grantRatingReward(context);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFFFACC15), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rewardGranted
                        ? 'شكراً جزيلاً لدعمك وتقييمك لأرض التحدي! تم منحك المكافأة 🎁'
                        : 'شكراً جزيلاً لدعمك وتقييمك المستمر لأرض التحدي! 🌟',
                    style: const TextStyle(
                      fontFamily: 'Baloo',
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F766E),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleFeedbackSubmit() async {
    if (_feedbackSubmitted) return;
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);

    final success = await RateGameService.instance.submitFeedback(
      context: context,
      rating: _selectedStars,
      tags: _selectedTags.toList(),
      message: _feedbackController.text,
    );

    if (mounted) {
      setState(() {
        _submitting = false;
        _feedbackSubmitted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
              ? 'شكراً لملاحظاتك القيمة! سنعمل بجد لتطوير اللعبة وتوفير تجربة تليق بك.'
              : 'شكراً لمشاركتك رأيك معنا!',
            style: const TextStyle(
              fontFamily: 'Baloo',
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;

    // قياسات متجاوبة تضمن ملاءمة الشاشة الأفقية تماماً بدون أي overflow
    final dialogWidth = math.min(media.size.width * (isLandscape ? 0.74 : 0.92), 650.0);
    final dialogMaxHeight = math.min(media.size.height * 0.90, isLandscape ? 385.0 : 540.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxHeight: dialogMaxHeight),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0D173C),
                  Color(0xFF090F28),
                  Color(0xFF050716),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.55),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
                  blurRadius: 36,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.75),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // خلفية إشعاعية ولمعان ديناميكي
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedBuilder(
                      animation: _animCtrl,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _RateShinePainter(_animCtrl.value),
                        );
                      },
                    ),
                  ),
                ),

                // محتوى النافذة الرئيسي المقاوم للـ Overflow
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isLandscape ? 20 : 16,
                    isLandscape ? 12 : 14,
                    isLandscape ? 20 : 16,
                    isLandscape ? 12 : 14,
                  ),
                  child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
                ),

                // زر الإغلاق الأنيق في الزاوية
                Positioned(
                  left: 10,
                  top: 10,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// التخطيط المخصص للوضع الأفقي (الأساسي للعبة)
  Widget _buildLandscapeLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // الجانب الأيمن: البادج 3D وصورة التقييم والمكافأة
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTopBadge(compact: true),
              const SizedBox(height: 8),
              _buildHeaderTitle(compact: true),
              const SizedBox(height: 8),
              _buildRewardPill(compact: true),
            ],
          ),
        ),

        const SizedBox(width: 14),

        // فاصل ناعم عمودي
        Container(
          width: 1,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.02),
                const Color(0xFFF59E0B).withValues(alpha: 0.35),
                Colors.white.withValues(alpha: 0.02),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        const SizedBox(width: 14),

        // الجانب الأيسر: النجوم التفاعلية + التفاعل مع التقييم
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // صف النجوم الخمسة التفاعلية
                _buildStarsRow(starSize: 38),
                const SizedBox(height: 6),

                // بطاقة المشاعر التعبيرية بناءً على التقييم
                _buildSentimentTag(),
                const SizedBox(height: 10),

                // المسار الإيجابي (4-5 نجوم) أو مسار الملاحظات (1-3 نجوم)
                if (_isPositiveRating) ...[
                  _buildPositiveActionArea(),
                ] else ...[
                  _buildFeedbackActionArea(compact: true),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// التخطيط العمودي المتجاوب (في حال الدوران)
  Widget _buildPortraitLayout() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTopBadge(compact: false),
          const SizedBox(height: 8),
          _buildHeaderTitle(compact: false),
          const SizedBox(height: 8),
          _buildRewardPill(compact: false),
          const SizedBox(height: 12),
          _buildStarsRow(starSize: 42),
          const SizedBox(height: 8),
          _buildSentimentTag(),
          const SizedBox(height: 14),
          if (_isPositiveRating) ...[
            _buildPositiveActionArea(),
          ] else ...[
            _buildFeedbackActionArea(compact: false),
          ],
        ],
      ),
    );
  }

  /// البادج ثلاثي الأبعاد مع النبض والأيقونة
  Widget _buildTopBadge({required bool compact}) {
    final size = compact ? 62.0 : 76.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        // وهج ذهبي خلفي
        Container(
          width: size + 16,
          height: size + 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                blurRadius: 28,
              ),
            ],
          ),
        ),
        // الدائرة الذهبية الفاخرة
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFE082),
                Color(0xFFF59E0B),
                Color(0xFFB45309),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFFFFFBEB),
              width: 2.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Image.asset(
            'assets/ui/rate.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
        ),
      ],
    );
  }

  /// عنوان النافذة الجذاب
  Widget _buildHeaderTitle({required bool compact}) {
    return Column(
      children: [
        Text(
          'ما هو تقييمك لأرض التحدي؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 15.0 : 17.5,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            shadows: const [
              Shadow(
                color: Colors.black,
                blurRadius: 4,
                offset: Offset(0, 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'رأيك يصنع الفرق ويساعدنا في تطوير اللعبة!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: compact ? 10.5 : 12.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// كبسولة المكافأة التقديرية
  Widget _buildRewardPill({required bool compact}) {
    if (_alreadyClaimedReward) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0F766E).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF2DD4BF).withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF2DD4BF), size: 15),
            SizedBox(width: 5),
            Text(
              'شكراً لدعمك وتقييمك لأرض التحدي! 🌟',
              style: TextStyle(
                color: Color(0xFFCCFBF1),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            blurRadius: 10,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🎁 هدية التقييم:',
            style: TextStyle(
              color: Color(0xFFFDE68A),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 6),
          Icon(Icons.monetization_on_rounded, color: Color(0xFFFACC15), size: 15),
          SizedBox(width: 3),
          Text(
            '+500',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(width: 7),
          Icon(Icons.diamond_rounded, color: Color(0xFF38BDF8), size: 15),
          SizedBox(width: 3),
          Text(
            '+10',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  /// صف النجوم التفاعلية الكبيرة
  Widget _buildStarsRow({required double starSize}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        final isFilled = starNumber <= _activeRating;

        return GestureDetector(
          onTap: () => _onStarTap(starNumber),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TweenAnimationBuilder<double>(
              key: ValueKey('star_${starNumber}_$isFilled'),
              tween: Tween<double>(begin: 0.85, end: 1.0),
              duration: Duration(milliseconds: 140 + (index * 40)),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: isFilled ? scale : 0.90,
                  child: child,
                );
              },
              child: Icon(
                isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                size: starSize,
                color: isFilled ? const Color(0xFFFFC107) : const Color(0xFF64748B),
                shadows: isFilled
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.55),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      }),
    );
  }

  /// وسم التعبير العاطفي بناءً على عدد النجوم المختارة
  Widget _buildSentimentTag() {
    String text;
    Color color;
    IconData icon;

    switch (_activeRating) {
      case 5:
        text = 'أسطورية! أفضل لعبة تحدي 🔥👑';
        color = const Color(0xFFF59E0B);
        icon = Icons.local_fire_department_rounded;
        break;
      case 4:
        text = 'لعبة رائعة وممتعة جداً! 🌟';
        color = const Color(0xFF10B981);
        icon = Icons.thumb_up_rounded;
        break;
      case 3:
        text = 'جيدة، ولكن أطمح للمزيد 👍';
        color = const Color(0xFF38BDF8);
        icon = Icons.sentiment_satisfied_alt_rounded;
        break;
      case 2:
        text = 'تحتاج تحسينات إضافية 🤔';
        color = const Color(0xFFFB923C);
        icon = Icons.sentiment_dissatisfied_rounded;
        break;
      case 1:
      default:
        text = 'تجربة تحتاج للكثير من التطوير 💔';
        color = const Color(0xFFF87171);
        icon = Icons.sentiment_very_dissatisfied_rounded;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  /// مسار التقييم الإيجابي العالي (4 أو 5 نجوم) -> توجيه فوري للمتجر مع المكافأة
  Widget _buildPositiveActionArea() {
    return Column(
      children: [
        // زر المتجر الذهبي ثلاثي الأبعاد
        GestureDetector(
          onTap: _submitting ? null : _handlePositiveSubmit,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFDE68A),
                  Color(0xFFF59E0B),
                  Color(0xFFD97706),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFFBEB),
                width: 1.6,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF92400E),
                  offset: Offset(0, 3.5),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black45,
                  offset: Offset(0, 5),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_submitting) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Color(0xFF78350F),
                      strokeWidth: 2.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  const Icon(
                    Icons.stars_rounded,
                    color: Color(0xFF78350F),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  _submitting ? 'جارٍ الفتح...' : 'تقييم في المتجر واستلام الهدية 🌟',
                  style: const TextStyle(
                    color: Color(0xFF451A03),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // زر التخطي / لاحقاً
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              'سأقيّم لاحقاً',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withValues(alpha: 0.30),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// مسار التقييم الأقل (1 إلى 3 نجوم) -> تجميع الملاحظات محلياً بدون إحراج المتجر
  Widget _buildFeedbackActionArea({required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ما الذي ترغب في أن نصلحه أو نطوّره في التحديث القادم؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.90),
            fontSize: compact ? 11.0 : 12.0,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),

        // شرائح الملاحظات السريعة
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 5,
          children: _feedbackOptions.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (isSelected) {
                    _selectedTags.remove(tag);
                  } else {
                    _selectedTags.add(tag);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF38BDF8)
                        : Colors.white.withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF7DD3FC) : Colors.white70,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 8),

        // حقل كتابة الملاحظة
        Container(
          height: compact ? 42 : 54,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: TextField(
            controller: _feedbackController,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'اكتب ملاحظتك للمطورين مباشرة (اختياري)...',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            maxLines: 2,
          ),
        ),

        const SizedBox(height: 8),

        // زر إرسال الملاحظات
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _submitting ? null : _handleFeedbackSubmit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_submitting) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ] else ...[
                        const Icon(Icons.send_rounded, color: Colors.white, size: 15),
                        const SizedBox(width: 5),
                      ],
                      const Text(
                        'إرسال الملاحظات للمطورين 📩',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white60,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text(
                'إلغاء',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// رسم جزيئات إشعاعية وخيوط ذهبية تضفي طابعاً فخماً على خلفية النافذة
class _RateShinePainter extends CustomPainter {
  const _RateShinePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.6),
        radius: 0.85,
        colors: [
          const Color(0xFFF59E0B).withValues(alpha: 0.12),
          const Color(0xFF38BDF8).withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // نقاط لمعان متلألئة في الخلفية
    final dotPaint = Paint()..color = const Color(0xFFFDE68A).withValues(alpha: 0.25);
    const count = 10;
    for (int i = 0; i < count; i++) {
      final seed = (i * 97 + progress * 40) % 100;
      final x = (math.sin(i * 1.5) * 0.45 + 0.5) * size.width;
      final y = ((i * 37 + progress * 30) % size.height);
      final r = (seed % 3 == 0) ? 1.8 : 1.2;
      canvas.drawCircle(Offset(x, y), r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_RateShinePainter old) => old.progress != progress;
}
