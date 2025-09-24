part of overview;

enum ScriptState {
  inactive, // 0
  running, // 递增
  warning,
  updating,
}

class OverviewController extends GetxController with LogMixin {
  WebSocketChannel? channel;
  int wsConnetCount = 0;

  String name;
  var scriptState = ScriptState.updating.obs;
  final running = const TaskItemModel('', '').obs;
  final pendings = <TaskItemModel>[].obs;
  final waitings = const <TaskItemModel>[].obs;
  final wsService = Get.find<WebSocketService>();
  late final tdController = Get.find<TaskDashboardController>(tag: name);

  @override
  int get maxLines => 300;

  OverviewController({required this.name});

  @override
  Future<void> onReady() async {
    await wsService
        .connect(name: name, listener: wsListen)
        .send("get_state")
        .send("get_schedule");
    super.onReady();
  }

  @override
  Future<void> onClose() async {
    await wsService.close(
      name,
      reason: "script $name normal close",
    );
    if(Get.isRegistered<TaskDashboardController>(tag: name)){
      Get.delete<TaskDashboardController>(tag: name, force: true);
    }
    super.onClose();
  }

  void toggleScript() {
    if (scriptState.value != ScriptState.running) {
      scriptState.value = ScriptState.running;
      wsService.send(name, 'start');
      clearLog();
    } else {
      scriptState.value = ScriptState.inactive;
      wsService.send(name, 'stop');
    }
  }

  void wsListen(dynamic message) {
    if (message is! String) {
      printError(info: 'Websocket push data is not of type string and map');
      return;
    }
    if (!message.startsWith('{') || !message.endsWith('}')) {
      addLog(message);
      parseLog(message);
      return;
    }
    Map<String, dynamic> data = json.decode(message);
    if (data.containsKey('state')) {
      final newState = switch (data['state']) {
        0 => ScriptState.inactive,
        1 => ScriptState.running,
        2 => ScriptState.warning,
        3 => ScriptState.updating,
        _ => ScriptState.inactive,
      };
      if (scriptState.value != newState) {
        scriptState.value = newState;
      }
    } else if (data.containsKey('schedule')) {
      Map run = data['schedule']['running'];
      List<dynamic> pending = data['schedule']['pending'];

      List<dynamic> waiting = data['schedule']['waiting'];

      if (run.isNotEmpty) {
        running.value = TaskItemModel(run['name'], run['next_run']);
      } else {
        running.value = const TaskItemModel('', '');
      }
      pendings.value = [];
      for (var element in pending) {
        pendings.add(TaskItemModel(element['name'], element['next_run']));
      }
      waitings.value = [];
      for (var element in waiting) {
        waitings.add(TaskItemModel(element['name'], element['next_run']));
      }
    }
  }

  final onlyBattleRegList = [
    'Orochi', //八岐大蛇
    'RealmRaid', //突破
    'RyouToppa', //寮突
    'BondlingFairyland', //契灵
    'ActivityShikigami', //爬塔
    'EvoZone', //觉醒
    'Exploration', //探索
    'FallenSun', // 日轮
    'GoryouRealm', //御灵
    'sougenbi', //业原火
    'EternitySea', //永生之海
    'areaBoss', // 地鬼
    'dye_trials', //灵柒
  ].map((e) => e.toUpperCase()).toList(growable: false);

  final battleReg = '^─.*GENERAL BATTLE START';

  void parseLog(String log) {
    final runningTaskName = running.value.taskName;
    if (runningTaskName.isEmpty) return;
    final taskNameUpperReg = '^─.*${runningTaskName.toUpperCase()}';
    // 非战斗型任务根据任务名称匹配
    // 战斗型任务根据通用战斗匹配
    if ((log.contains(RegExp(taskNameUpperReg)) &&
            !onlyBattleRegList.contains(runningTaskName.toUpperCase())) ||
        (log.contains(RegExp(battleReg)) &&
            onlyBattleRegList.contains(runningTaskName.toUpperCase()))) {
      final taskCardState = tdController.findByName(runningTaskName);
      if (taskCardState != null) {
        taskCardState.count.value++;
        tdController.updateTaskCard(taskCardState);
      } else {
        tdController
            .addTaskCard(TaskCardState(name: runningTaskName, count: 1));
      }
    }
  }
}
