part of overview;

class TaskItemModel {
  final String scriptName;
  final taskName = ''.obs;
  final nextRun = ''.obs;
  String? groupName;

  TaskItemModel(this.scriptName, taskName, nextRun, {this.groupName = ''}) {
    this.taskName.value = taskName;
    this.nextRun.value = nextRun;
  }

  static TaskItemModel empty() {
    return TaskItemModel('', '', '');
  }

  bool isAllEmpty() {
    return taskName.isEmpty && nextRun.isEmpty;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskItemModel &&
          runtimeType == other.runtimeType &&
          scriptName == other.scriptName &&
          taskName == other.taskName &&
          nextRun == other.nextRun;

  @override
  int get hashCode => Object.hash(scriptName, taskName, nextRun);
}
