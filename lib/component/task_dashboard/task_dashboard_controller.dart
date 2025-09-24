import 'dart:async';

import 'package:get/get.dart';
import 'package:oasx/component/task_dashboard/task_card_state.dart';

class TaskDashboardController extends GetxController {

  final taskCardMap = <String, TaskCardState>{}.obs;

  final sortedTaskCardList = <TaskCardState>[].obs;

  /// The current time (scheduled update) triggers a UI refresh
  final now = DateTime.now().obs;

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _scheduleTick();
    // listen map to update sortedList
    ever(taskCardMap, (_) {
      final list = taskCardMap.values.toList();
      list.sort();
      sortedTaskCardList.assignAll(list);
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
    final diffs =
        taskCardMap.values.map((c) => DateTime.now().difference(c.time.value));
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

  void addTaskCard(TaskCardState task) {
    if (taskCardMap.containsKey(task.name.value)) return;
    taskCardMap[task.name.value] = task;
    _scheduleTick();
  }

  void removeTaskCard(String taskName) {
    if (!taskCardMap.containsKey(taskName)) return;
    taskCardMap.remove(taskName);
    _scheduleTick();
  }

  void updateTaskCard(TaskCardState task) {
    if (!taskCardMap.containsKey(task.name.value)) return;
    taskCardMap[task.name.value]!.count.value = task.count.value;
    taskCardMap[task.name.value]!.time.value = DateTime.now(); // 更新时间
    _scheduleTick();
  }

  void addOrUpdateTaskCard(TaskCardState task) {
    if (taskCardMap.containsKey(task.name.value)) {
      updateTaskCard(task);
      return;
    }
    addTaskCard(task);
  }

  TaskCardState? findByName(String taskName) {
    return taskCardMap[taskName];
  }
}
