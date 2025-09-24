import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/component/task_dashboard/task_card_state.dart';
import 'package:oasx/component/task_dashboard/task_dashboard_controller.dart';
import 'package:oasx/utils/time_utils.dart';
import 'package:styled_widget/styled_widget.dart';

class TaskCardWidget extends StatelessWidget {
  final TaskCardState state;
  final String controllerTag;

  const TaskCardWidget({
    Key? key,
    required this.state,
    required this.controllerTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TaskDashboardController>(tag: controllerTag);
    return <Widget>[
      // 左面
      Icon(
        Icons.circle_rounded,
        color: _generateColor(state.name.value),
        size: 12,
      ).marginOnly(top: 6),
      const SizedBox(width: 2),
      // 右面
      <Widget>[
        // 上面
        Obx(() => Text(
              "${state.count.value}",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold), // 加粗
            )),
        // 下面
        Obx(() => Text(
              "${state.name.value.tr}-${TimeUtils.formatRelativeTime(state.time.value, controller.now.value)}",
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1, // 单行显示
              overflow: TextOverflow.ellipsis, // 超出部分显示省略号
            )),
      ]
          .toColumn(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
          )
          .flexible(),
    ]
        .toRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min)
        .constrained(minWidth: 125, minHeight: 40)
        .parent(({required Widget child}) => IntrinsicWidth(child: child))
        .paddingAll(1); // 整体内边距
  }

  /// 根据名称生成随机颜色,保证同一个名称颜色相同
  Color _generateColor(String input) {
    final Random random = Random(input.hashCode);
    return Color.fromARGB(
      255,
      random.nextInt(200) + 56,
      random.nextInt(200) + 56,
      random.nextInt(200) + 56,
    );
  }
}
