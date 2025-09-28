import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:oasx/component/stats/stats_log_controller.dart';
import 'package:oasx/component/stats/stats_widget.dart';

class StatsLogWidget extends StatelessWidget {
  final String scriptName;

  const StatsLogWidget({Key? key, required this.scriptName})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StatsLogController>(tag: scriptName);
    return Obx(() {
      return Wrap(
        alignment: WrapAlignment.spaceAround,
        textDirection: TextDirection.ltr,
        children: controller.sortedStatsList
            .map((model) =>
                StatsWidget(model: model, controller: controller))
            .toList(),
      );
    });
  }
}
