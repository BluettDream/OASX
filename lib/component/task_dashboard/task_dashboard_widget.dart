import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:oasx/component/task_dashboard/task_card_widget.dart';
import 'package:oasx/component/task_dashboard/task_dashboard_controller.dart';

class TaskDashboardWidget extends StatelessWidget {
  final String controllerTag;

  const TaskDashboardWidget({Key? key, required this.controllerTag})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TaskDashboardController>(tag: controllerTag);
    return Obx(() {
      return Wrap(
        alignment: WrapAlignment.spaceAround,
        textDirection: TextDirection.ltr,
        children: controller.sortedTaskCardList
            .map((state) =>
                TaskCardWidget(state: state, controllerTag: controllerTag))
            .toList(),
      );
    });
  }
}
