part of overview;

class OverviewController extends GetxController with LogMixin {
  String name;
  final scriptService = Get.find<ScriptService>();
  late final scriptModel = scriptService.findScriptModel(name)!;
  final isWaitingLoading = false.obs;
  final isPendingLoading = false.obs;

  OverviewController({required this.name});

  @override
  void onInit() {
    super.onInit();
  }

  @override
  Future<void> onClose() async {
    // close log
    super.onClose();
  }

  Future<void> toggleScript() async {
    if (scriptModel.state.value != ScriptState.running) {
      scriptService.startScript(name);
      clearLog();
    } else {
      scriptService.stopScript(name);
    }
  }

  Future<void> onMoveToPending(TaskItemModel model) async {
    isPendingLoading.value = true;
    final nextRun =
        formatDateTime(DateTime.now().subtract(const Duration(days: 1)));
    final argsController = Get.find<ArgsController>();
    final updateRet =
        await argsController.updateScriptTask(name, model.taskName.value, true);
    if (!updateRet) {
      Get.snackbar(I18n.error.tr, 'Enable task fail',
          duration: const Duration(seconds: 2));
      isWaitingLoading.value = false;
      return;
    }
    final syncRet = await argsController.updateScriptTaskNextRun(
        name, model.taskName.value, nextRun);
    if (updateRet && syncRet) {
      Get.snackbar(I18n.tip.tr, I18n.success.tr,
          duration: const Duration(seconds: 2));
    } else {
      Get.snackbar(I18n.error.tr, '', duration: const Duration(seconds: 2));
    }
    isPendingLoading.value = false;
  }

  Future<void> onMoveToWaiting(TaskItemModel model) async {
    isWaitingLoading.value = true;
    final updateRet = await Get.find<ArgsController>()
        .updateScriptTask(name, model.taskName.value, true);
    if (!updateRet) {
      Get.snackbar(I18n.error.tr, 'Enable task fail',
          duration: const Duration(seconds: 2));
      isWaitingLoading.value = false;
      return;
    }
    final syncRet = await ApiClient().syncNextRun(name, model.taskName.value);
    if (updateRet && syncRet) {
      Get.snackbar(I18n.tip.tr, I18n.success.tr,
          duration: const Duration(seconds: 2));
    } else {
      Get.snackbar(I18n.error.tr, '', duration: const Duration(seconds: 2));
    }
    isWaitingLoading.value = false;
  }

  Future<bool> disableScriptTask(TaskItemModel model) async {
    final ret = await Get.find<ArgsController>()
        .updateScriptTask(model.scriptName, model.taskName.value, false);
    return ret;
  }
}
