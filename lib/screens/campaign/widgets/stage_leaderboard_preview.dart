import 'package:flutter/material.dart';

import '../../../models/campaign_stage.dart';
import '../../../models/stage_leaderboard_entry.dart';
import '../../../services/campaign_service.dart';
import '../stage_leaderboard_screen.dart';
import 'stage_leaderboard_row.dart';

class StageLeaderboardPreview extends StatefulWidget {
  const StageLeaderboardPreview({
    super.key,
    required this.stage,
    this.campaignService,
  });

  final CampaignStage stage;
  final CampaignService? campaignService;

  @override
  State<StageLeaderboardPreview> createState() =>
      _StageLeaderboardPreviewState();
}

class _StageLeaderboardPreviewState extends State<StageLeaderboardPreview> {
  late final CampaignService _campaignService;
  late Future<List<StageLeaderboardEntry>> _future;

  @override
  void initState() {
    super.initState();
    _campaignService = widget.campaignService ?? CampaignService();
    _future = _load();
  }

  @override
  void didUpdateWidget(StageLeaderboardPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage.id != widget.stage.id ||
        oldWidget.stage.campaignId != widget.stage.campaignId) {
      _future = _load();
    }
  }

  Future<List<StageLeaderboardEntry>> _load() {
    return _campaignService.loadStageLeaderboard(
      campaignId: widget.stage.campaignId,
      stageId: widget.stage.id,
      limit: 3,
      propagateErrors: true,
    );
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B173F).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFACC15).withValues(alpha: 0.34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard_rounded,
                  color: Color(0xFFFACC15), size: 20),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'أفضل اللاعبين',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StageLeaderboardScreen(
                      stage: widget.stage,
                      campaignService: _campaignService,
                    ),
                  ),
                ),
                child: const Text(
                  'عرض الترتيب',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<StageLeaderboardEntry>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 56,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFACC15),
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تعذر تحميل الترتيب.',
                        style: TextStyle(color: Colors.white70)),
                    TextButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                );
              }
              final entries = snapshot.data ?? const <StageLeaderboardEntry>[];
              if (entries.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'لا توجد نتائج بعد.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (var index = 0; index < entries.length; index += 1) ...[
                    StageLeaderboardRow(
                      entry: entries[index],
                      rank: index + 1,
                      compact: true,
                    ),
                    if (index != entries.length - 1) const SizedBox(height: 7),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
