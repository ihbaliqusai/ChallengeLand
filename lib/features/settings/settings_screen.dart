import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../state/auth_provider.dart';
import '../../state/settings_provider.dart';
import '../home/widgets/game_page_shell.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: DimmedHomeBackground(opacity: 0.72)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _SettingsPanel(
                    settings: settings,
                    playerId: user?.uid,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _CloseButton(onPressed: () => Navigator.pop(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.settings, required this.playerId});

  final SettingsProvider settings;
  final String? playerId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEB20FF), Color(0xFF8E04D9), Color(0xFF7700CC)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7A3FF), width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.48),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'SETTINGS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 2,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF5D0875).withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _SwitchRow(
                  icon: Icons.music_note_rounded,
                  label: 'الصوت',
                  value: settings.soundOn,
                  onChanged: settings.setSound,
                ),
                const SizedBox(height: 12),
                _SliderRow(
                  icon: Icons.volume_up_rounded,
                  enabled: settings.soundOn,
                  value: settings.soundVolume,
                  onChanged: settings.setSoundVolume,
                ),
                const SizedBox(height: 18),
                _SwitchRow(
                  icon: Icons.vibration_rounded,
                  label: 'Haptics',
                  value: settings.vibrationOn,
                  onChanged: settings.setVibration,
                ),
                const SizedBox(height: 12),
                _SwitchRow(
                  icon: Icons.visibility_rounded,
                  label: 'Color Blind Assist',
                  value: settings.notificationsOn,
                  onChanged: settings.setNotifications,
                  muted: true,
                ),
                const SizedBox(height: 12),
                const _LanguageRow(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _ConnectBanner(),
          const SizedBox(height: 14),
          _PlayerIdRow(playerId: playerId ?? 'guest-player'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PurpleButton(label: 'مزامنة التقدم', onPressed: () {}),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PurpleButton(label: 'PRIVACY POLICY', onPressed: () {}),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PurpleButton(label: 'SEND LOG', wide: true, onPressed: () {}),
          const SizedBox(height: 12),
          _PurpleButton(
            label: 'SIGN OUT',
            wide: true,
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final bool enabled;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 118,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFF00), Color(0xFFFFA900)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 48,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 2)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 12,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
              activeTrackColor: const Color(0xFFFFD000),
              inactiveTrackColor: const Color(0xFF5B546F),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: enabled ? Colors.white : Colors.white54,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF38084D).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 2,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 96,
              height: 46,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: value
                    ? const Color(0xFF53E51B)
                    : const Color(0xFF8D789B),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Align(
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          if (muted)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.28),
                size: 30,
              ),
            ),
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF38084D).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Language',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 2,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE526FF), Color(0xFFFF63F3)],
              ),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFFF8BFF), width: 1.5),
            ),
            child: const Center(
              child: Text(
                'ENGLISH   ...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 2,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectBanner extends StatelessWidget {
  const _ConnectBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 124,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF710097), Color(0xFFD117F7), Color(0xFF53006D)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4B0062), width: 2),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'SAVE YOUR PROGRESS & MORE!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 2,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BlueButton(label: 'CONNECT', onPressed: () {}),
          ),
        ],
      ),
    );
  }
}

class _PlayerIdRow extends StatelessWidget {
  const _PlayerIdRow({required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.only(left: 18, right: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4E6EF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE992FF), width: 3),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'player ID: $playerId - 5.527 / 1 - 64',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF4B3D50),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 54,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFC456), Color(0xFF9E4D20)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF5B224B), width: 2),
            ),
            child: const Icon(Icons.content_paste_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _PurpleButton extends StatelessWidget {
  const _PurpleButton({
    required this.label,
    required this.onPressed,
    this.wide = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wide ? double.infinity : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Ink(
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE929FF), Color(0xFFA900D5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFF67FF), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 2,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlueButton extends StatelessWidget {
  const _BlueButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Ink(
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF33B7FF), Color(0xFF086CE4)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF004FBA), width: 2),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 2,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Ink(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFF0C247A),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 5),
          ),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 48),
        ),
      ),
    );
  }
}
