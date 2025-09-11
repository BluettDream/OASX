part of server;

class ServerController extends GetxController with LogMixin {
  final rootPathServer = ''.obs;
  final rootPathAuthenticated = true.obs;
  final showDeploy = true.obs;

  final log = ''.obs;
  final deployContent = ''.obs;
  Shell? shell;
  var shellController = ShellLinesController();

  @override
  void onInit() {
    final storage = GetStorage();
    rootPathServer.value = storage.read(StorageKey.rootPathServer.name) ??
        'Please set OAS root path';
    shell = getShell;
    shellController.stream.listen((event) {
      addLog('INFO: $event');
    });
    rootPathAuthenticated.value = authenticatePath(rootPathServer.value);
    if (rootPathAuthenticated.value) {
      readDeploy();
    }
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
    if (!rootPathAuthenticated.value) {
      return;
    }
    final storage = GetStorage();
    bool autoStartServer =
        (storage.read(StorageKey.autoStartServer.name) as bool?) ?? false;
    bool autoStartScript =
        (storage.read(StorageKey.autoStartScript.name) as bool?) ?? false;
    if (autoStartServer) {
      startServer();
    }
    final address = (storage.read(StorageKey.address.name) as String?) ?? '';
    // 配置了自动启动脚本且有address
    if (autoStartScript && address.isNotEmpty) {
      startScript();
    }
  }

  void updateRootPathServer(String value) {
    if (authenticatePath(value)) {
      rootPathAuthenticated.value = true;
    } else {
      rootPathAuthenticated.value = false;
    }
    // value = value.replaceAll('\\', '\\\\');
    rootPathServer.value = value;
    shell = getShell;
    Get.find<SettingsController>()
        .storage
        .write('rootPathServer', rootPathServer.value);
    if (rootPathAuthenticated.value) {
      readDeploy();
    }
  }

  bool authenticatePath(String root) {
    root.replaceAll('\\', '/');
    try {
      // 先是判断根目录
      Directory rootDir = Directory(root);
      if (!rootDir.existsSync()) {
        return false;
      }
      // 然后是判断python是否存在
      File python = File('${rootDir.path}/toolkit/python.exe');
      if (!python.existsSync()) {
        return false;
      }
      // 然后判断git是否存在
      File git = File('${rootDir.path}/toolkit/Git/cmd/git.exe');
      if (!git.existsSync()) {
        return false;
      }
      // 然后判断安装器是否存在
      File installer = File('${rootDir.path}/deploy/installer.py');
      if (!installer.existsSync()) {
        return false;
      }
      // 然后判断deploy是否存在
      File deploy = File('${rootDir.path}/config/deploy.yaml');
      if (!deploy.existsSync()) {
        return false;
      }
    } catch (e) {
      printError(info: e.toString());
      return false;
    }

    return true;
  }

  String get pathGit => '${rootPathServer.value}\\toolkit\\Git\\mingw64\\bin"';
  String get pathPython => '${rootPathServer.value}\\toolkit';
  String get pathAdb =>
      '${rootPathServer.value}\\toolkit\\Lib\\site-packages\\adbutils\\binaries';
  String get pathScripts => '${rootPathServer.value}\\toolkit\\Scripts';
  Map<String, String> get pathPATH => {
        'PATH':
            '${rootPathServer.value},$pathGit,$pathPython,$pathAdb,$pathScripts'
      };
  Shell get getShell => Shell(
        workingDirectory: rootPathServer.value,
        runInShell: true,
        environment: pathPATH,
        stdout: shellController.sink,
        verbose: false,
      );

  Future<void> runShell(String command) async {
    try {
      var result = await shell!.run(command);
      printInfo(info: result.errText);
    } on ShellException catch (e) {
      addLog('ERROR: ${e.toString()}');
    }
  }

  Future<void> startServer() async {
    clearLog();
    shell!.kill();
    [
      'echo OAS working directory: ',
      'pwd',
      'taskkill /f /t /im pythonw.exe',
      'python -m deploy.installer',
      'echo Start OAS',
      r'.\toolkit\pythonw.exe server.py',
    ].forEach(runShell);
  }

  Future<void> startScript() async {
    final runScriptList =
        YamlUtils.getValueFromString(deployContent.value, "Deploy.Webui.Run");
    List<String> scriptNameList =
        (runScriptList as List?)?.map((e) => e.toString()).toList() ?? [];
    if (scriptNameList.isEmpty) {
      Get.snackbar(I18n.tip.tr, I18n.not_detect_run_config.tr,
          duration: const Duration(seconds: 2));
      return;
    }
    Get.snackbar(I18n.detected_run_config_help.tr, scriptNameList.toString(),
        duration: const Duration(seconds: 4));

    final serverStarted = await checkServerStarted();
    if (!serverStarted) {
      return;
    }

    for (final scriptName in scriptNameList) {
      addLog('INFO: start $scriptName');
      await WebSocketManager.instance
          .connect(name: scriptName, force: true)
          .send("start");
    }

    final loginMap = {
      'username': GetStorage().read(StorageKey.username.name),
      'password': GetStorage().read(StorageKey.password.name),
      'address': GetStorage().read(StorageKey.address.name),
    };
    LoginController.toMain(data: loginMap);
  }

  /// 检查oas服务是否启动成功(暂定)
  /// 连续检查, 若成功连接maxRetries次则成功, 否则失败
  Future<bool> checkServerStarted(
      {int maxRetries = 5, int minWaitSeconds = 1}) async {
    int failCnt = 0, successCnt = 0, allCnt = 0, waitSeconds = minWaitSeconds;
    while (failCnt < maxRetries && successCnt < maxRetries) {
      await LoginController.login(showSnackBar: false);
      if (LoginController.logged) {
        successCnt++;
        failCnt = 0;
        // 成功一次等待时间-3s, 最低minWaitSeconds
        waitSeconds = max(minWaitSeconds, waitSeconds - 3);
        addLog(
            "INFO: [${++allCnt}]Success to connect server, remain valid times[${maxRetries - successCnt}], please wait for a moment${'. ' * 6}");
      } else {
        failCnt++;
        successCnt = 0;
        // 失败一次等待时间+3s
        waitSeconds += 3;
        addLog(
            "INFO: [${++allCnt}]Fail to connect server, remain try times[${maxRetries - failCnt}], please wait for a moment${'. ' * 6}");
      }
      await Future.delayed(Duration(seconds: waitSeconds));
    }
    return successCnt == maxRetries;
  }

  void readDeploy() {
    String filePath = '${rootPathServer.value}\\config\\deploy.yaml';
    try {
      File file = File(filePath);
      if (file.existsSync()) {
        deployContent.value = file.readAsStringSync();
        return;
      } else {
        deployContent.value = 'File not found';
        return;
      }
    } catch (e) {
      deployContent.value = 'Error reading file: $e';
      return;
    }
  }

  void writeDeploy(String value) {
    String filePath = '${rootPathServer.value}\\config\\deploy.yaml';
    deployContent.value = value;
    try {
      File file = File(filePath);
      if (file.existsSync()) {
        file.writeAsStringSync(deployContent.value);
        return;
      } else {
        deployContent.value = 'File not found';
        return;
      }
    } catch (e) {
      deployContent.value = 'Error writing file: $e';
      return;
    }
  }
}
