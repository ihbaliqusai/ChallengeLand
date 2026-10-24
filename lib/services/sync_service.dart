import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

/// يُعنى بمزامنة الوقت مع خادم Firebase وإدارة حالة الاتصال.
class SyncService {
  SyncService({FirebaseDatabase? database})
    : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  // الفارق بين وقت الخادم ووقت الجهاز (مللي ثانية).
  // موجب = الخادم أسرع، سالب = الجهاز أسرع.
  int _serverTimeOffset = 0;

  /// يُعايَر مرة واحدة لكل جلسة عبر .info/serverTimeOffset.
  Future<void> calibrateOffset() async {
    final snap = await _db.ref('.info/serverTimeOffset').get();
    _serverTimeOffset = (snap.value as num?)?.toInt() ?? 0;
  }

  /// الوقت الحالي بتوقيت الخادم (epoch ms).
  int get serverNow =>
      DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;

  /// الثواني المتبقية في الجولة بناءً على وقت الخادم.
  int computeRemainingSeconds(int roundStartedAt, int roundDuration) {
    final elapsed = (serverNow - roundStartedAt) ~/ 1000;
    final remaining = roundDuration - elapsed;
    return remaining.clamp(0, roundDuration);
  }

  /// Stream يصدر الثواني المتبقية كل ثانية حتى ينتهي الوقت.
  Stream<int> buildRoundTimer(int roundStartedAt, int roundDuration) {
    return Stream.periodic(
      const Duration(seconds: 1),
      (_) => computeRemainingSeconds(roundStartedAt, roundDuration),
    ).takeWhile((remaining) => remaining > 0).asBroadcastStream();
  }

  /// يُطلق callback عند كل تغيير في حالة الاتصال.
  StreamSubscription<DatabaseEvent> onConnectionChange(
    void Function(bool connected) callback,
  ) {
    return _db.ref('.info/connected').onValue.listen((event) {
      callback(event.snapshot.value == true);
    });
  }
}
