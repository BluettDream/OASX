import 'package:get/get.dart';

/// 单个卡片的状态（数据模型，使用响应式变量）
class TaskCardState implements Comparable<TaskCardState> {
  RxString name;
  RxInt count;
  Rx<DateTime> time;

  TaskCardState({
    required String name,
    required int count,
  })  : name = name.obs,
        count = count.obs,
        time = DateTime.now().obs;

  @override
  int compareTo(TaskCardState other) {
    return other.time.value.compareTo(time.value);
  }
}
