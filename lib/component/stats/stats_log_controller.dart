import 'dart:async';

import 'package:get/get.dart';
import 'package:oasx/component/stats/stats_model.dart';

class StatsLogController extends GetxController {
  final statsModelMap = <String, StatsModel>{}.obs;

  final sortedStatsList = <StatsModel>[].obs;

  /// The current time (scheduled update) triggers a UI refresh
  final now = DateTime.now().obs;

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _scheduleTick();
    // listen map to update sortedList
    ever(statsModelMap, (_) {
      final list = statsModelMap.values.toList();
      list.sort();
      sortedStatsList.assignAll(list);
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  /// 动态调整定时器
  void _scheduleTick() {
    _timer?.cancel();

    // 计算当前最小的时间差
    final diffs = statsModelMap.values
        .map((c) => DateTime.now().difference(c.time.value));
    final minDiff =
        diffs.isEmpty ? Duration.zero : diffs.reduce((a, b) => a < b ? a : b);

    Duration interval;
    if (minDiff.inMinutes <= 2) {
      interval = const Duration(seconds: 1);
    } else if (minDiff.inMinutes <= 120) {
      interval = const Duration(minutes: 1);
    } else {
      interval = const Duration(hours: 1);
    }

    _timer = Timer.periodic(interval, (_) {
      now.value = DateTime.now();
      _scheduleTick(); // 每次 tick 后重新调度
    });
  }

  void addStatsModel(StatsModel stats) {
    if (statsModelMap.containsKey(stats.name.value)) return;
    statsModelMap[stats.name.value] = stats;
    _scheduleTick();
  }

  void removeStatsModel(String statsName) {
    if (!statsModelMap.containsKey(statsName)) return;
    statsModelMap.remove(statsName);
    _scheduleTick();
  }

  void updateStatsModel(StatsModel newStats) {
    if (!statsModelMap.containsKey(newStats.name.value)) return;
    final oldStats = statsModelMap[newStats.name.value]!;
    if (oldStats.data.value != newStats.data.value) {
      oldStats.data.value = newStats.data.value;
    }
    if (oldStats.time.value != newStats.time.value) {
      oldStats.time.value = newStats.time.value;
    }
    _scheduleTick();
  }

  void addOrUpdateStatsModel(StatsModel stats) {
    if (statsModelMap.containsKey(stats.name.value)) {
      updateStatsModel(stats);
      return;
    }
    addStatsModel(stats);
  }

  StatsModel? findByName(String statesName) {
    return statsModelMap[statesName];
  }
}
