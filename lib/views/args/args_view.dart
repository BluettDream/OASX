library args;

// import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pickers/pickers.dart';
import 'package:flutter_pickers/style/default_style.dart';
import 'package:get/get.dart';
import 'package:oasx/service/theme_service.dart';
import 'package:oasx/service/websocket_service.dart';
import 'package:oasx/views/nav/view_nav.dart';
import 'package:oasx/views/overview/overview_view.dart';
import 'package:styled_widget/styled_widget.dart';
import 'dart:convert';
import 'package:expansion_tile_group/expansion_tile_group.dart';
import 'dart:async';

import 'package:oasx/api/api_client.dart';

import '../../translation/i18n_content.dart';

part './group_view.dart';
part './date_time_picker.dart';
part '../../controller/args/args_controller.dart';

class Args extends StatelessWidget {
  const Args(
      {Key? key, this.scriptName, this.taskName, this.groupDraggable = true})
      : super(key: key);
  final String? scriptName;
  final String? taskName;
  final bool groupDraggable;

  @override
  Widget build(BuildContext context) {
    return GetX<ArgsController>(builder: (controller) {
      final navController = Get.find<NavCtrl>();
      final selectedScript = navController.selectedScript.value;
      final selectedTask = navController.selectedMenu.value;
      return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: ExpansionTileGroup(
                      spaceBetweenItem: 10,
                      children: controller.groupsName.value
                          .map((name) => ExpansionTileItem(
                                initiallyExpanded: true,
                                isHasTopBorder: false,
                                isHasBottomBorder: false,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer
                                    .withValues(alpha: 0.24),
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(10)),
                                title: <Widget>[
                                  if (groupDraggable)
                                    Draggable<Map<String, dynamic>>(
                                      data: {
                                        'model': TaskItemModel(
                                            scriptName ?? selectedScript,
                                            taskName ?? selectedTask,
                                            '',
                                            groupName: name),
                                        'source': 'argsViewGroup'
                                      },
                                      feedback: _buildFeedback(context, name),
                                      child: const Icon(
                                          Icons.drag_indicator_outlined),
                                    ),
                                  Text(name.tr)
                                ].toRow(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min),
                                children: _children(name),
                              ))
                          .toList())
                  .constrained(maxWidth: 700, minWidth: 100))
          .alignment(Alignment.topCenter);
    });
  }

  List<Widget> _children(String groupName) {
    ArgsController controller = Get.find();
    GroupsModel groupsModel = controller.groupsData.value[groupName]!;
    List<Widget> result = [const Divider()];
    for (int i = 0; i < groupsModel.members.length; i++) {
      result.add(ArgumentView(
        scriptName: scriptName,
        taskName: taskName,
        setArgument: controller.setArgument,
        getGroupName: groupsModel.getGroupName,
        index: i,
      ));
    }
    return result;
  }

  Widget _buildFeedback(BuildContext context, String title) {
    final themeService = Get.find<ThemeService>();
    return Material(
      color: Colors.transparent,
      child: Text(title.tr, style: Theme.of(context).textTheme.titleMedium)
          .decorated(
            color: themeService.isDarkMode
                ? Colors.blueGrey.shade700
                : Colors.blueGrey.shade100,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(2, 2),
              ),
            ],
          )
          .width(150)
          .height(30)
          .paddingAll(8)
          .opacity(0.8),
    );
  }
}

class ArgumentView extends StatefulWidget {
  final void Function(String? config, String? task, String group,
      String argument, String type, dynamic value) setArgument;
  final String Function() getGroupName;
  final int index;
  final String? scriptName;
  final String? taskName;

  const ArgumentView(
      {required this.setArgument,
      required this.getGroupName,
      required this.index,
      Key? key,
      this.scriptName,
      this.taskName})
      : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _ArgumentViewState createState() => _ArgumentViewState();
}

class _ArgumentViewState extends State<ArgumentView> {
  Timer? timer;
  bool landscape = true;

  ArgumentModel get model {
    ArgsController controller = Get.find();
    GroupsModel? groupsModel =
        controller.groupsData.value[widget.getGroupName()];
    return groupsModel!.members[widget.index];
  }

  @override
  Widget build(BuildContext context) {
    landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (landscape) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _title(),
          ),
          _form(),
        ],
      ).padding(bottom: 8);
    } else {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_title(), _form()]).padding(bottom: 8);
    }
    // return LayoutBuilder(builder: (context, constraints) {
    //   if (constraints.maxWidth >= 350) {
    //     return Row(
    //       crossAxisAlignment: CrossAxisAlignment.start,
    //       children: [
    //         Expanded(
    //           child: _title(),
    //         ),

    //         // const Spacer(),
    //         _form(),
    //       ],
    //     );
    //   } else {
    //     return Column(
    //         crossAxisAlignment: CrossAxisAlignment.start,
    //         children: [_title(), _form()]);
    //   }
    // });
  }

  Widget _title() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SelectableText(
        model.title.tr,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      if (model.description != null && model.description!.isNotEmpty)
        SelectableText(
          model.description!.tr,
          style: Theme.of(context).textTheme.bodySmall,
        ),
    ]);
  }

  Widget _form() {
    return switch (model.type) {
      "boolean" => Checkbox(value: model.value, onChanged: onCheckboxChanged)
          .alignment(Alignment.centerLeft)
          .constrained(width: landscape ? 200 : null),
      "string" => TextFormField(
          initialValue: model.value.toString(),
          onChanged: (value) {
            timer?.cancel();
            timer = Timer(const Duration(milliseconds: 1000),
                () => onStringChanged(value));
          }).constrained(width: landscape ? 200 : null),
      "multi_line" => TextFormField(
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          maxLines: null,
          initialValue: model.value.toString(),
          onChanged: (value) {
            timer?.cancel();
            timer = Timer(const Duration(milliseconds: 1000),
                () => onStringChanged(value));
          }).constrained(width: landscape ? 200 : null),
      "number" => TextFormField(
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[-0-9.]')),
          ],
          initialValue: model.value.toString(),
          onChanged: (value) {
            timer?.cancel();
            timer = Timer(const Duration(milliseconds: 1000),
                () => onNumberChanged(value));
          }).constrained(width: landscape ? 200 : null),
      "integer" => TextFormField(
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[-0-9]')),
          ],
          initialValue: model.value.toString(),
          onChanged: (value) {
            timer?.cancel();
            timer = Timer(const Duration(milliseconds: 1000),
                () => onIntegerChanged(value));
          }).constrained(width: landscape ? 200 : null),
      "enum" => DropdownButton<String>(
          isExpanded: !landscape,
          menuMaxHeight: Get.height * 0.5,
          value: model.value.toString(),
          items: model.enumEnum!
              .map<DropdownMenuItem<String>>((e) => DropdownMenuItem(
                  value: e.toString(),
                  child: Text(
                    e.toString().tr,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ).constrained(width: landscape ? 177 : null)))
              .toList(),
          onChanged: onEnumChanged,
        ),
      "date_time" => DateTimePicker(
          value: model.value,
          onChange: onDateTimeChanged,
        ).constrained(width: landscape ? 200 : null),
      "time_delta" => TimeDeltaPicker(
          value: ensureTimeDeltaString(model.value),
          onChange: onTimeDeltaChanged,
        ).constrained(width: landscape ? 200 : null),
      "time" => TimePicker(
          value: model.value,
          onChange: onTimeChanged,
        ).constrained(width: landscape ? 200 : null),
      _ =>
        Text(model.value.toString()).constrained(width: landscape ? 200 : null)
    };
  }

  void onCheckboxChanged(bool? value) {
    setState(() {
      widget.setArgument(widget.scriptName, widget.taskName,
          widget.getGroupName(), model.title, 'boolean', value);
      model.value = value;
    });
    showSnakbar(value);
  }

  void onStringChanged(String? value) {
    widget.setArgument(widget.scriptName, widget.taskName,
        widget.getGroupName(), model.title, 'string', value);
    showSnakbar(value);
  }

  void onNumberChanged(String? value) {
    widget.setArgument(widget.scriptName, widget.taskName,
        widget.getGroupName(), model.title, 'number', value);
    showSnakbar(value);
  }

  void onIntegerChanged(String? value) {
    widget.setArgument(widget.scriptName, widget.taskName,
        widget.getGroupName(), model.title, 'integer', value);
    showSnakbar(value);
  }

  void onEnumChanged(String? value) {
    setState(() {
      model.value = value;
      widget.setArgument(widget.scriptName, widget.taskName,
          widget.getGroupName(), model.title, 'enum', value);
    });
    showSnakbar(value);
  }

  void onDateTimeChanged(String? value) {
    setState(() {
      model.value = value;
      widget.setArgument(widget.scriptName, widget.taskName,
          widget.getGroupName(), model.title, 'date_time', value);
    });
    showSnakbar(value);
  }

  void onTimeDeltaChanged(String? value) {
    setState(() {
      model.value = value;
      widget.setArgument(widget.scriptName, widget.taskName,
          widget.getGroupName(), model.title, 'time_delta', value);
    });
    showSnakbar(value);
  }

  void onTimeChanged(String? value) {
    setState(() {
      model.value = value;
      widget.setArgument(widget.scriptName, widget.taskName,
          widget.getGroupName(), model.title, 'time', value);
    });
    showSnakbar(value);
  }

// -----------------------------------------------------------------------------
  void showSnakbar(dynamic value) {
    Get.snackbar(I18n.setting_saved.tr, "$value",
        duration: const Duration(seconds: 1));
  }
}
