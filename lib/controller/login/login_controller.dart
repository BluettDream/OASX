part of login;

class LoginController extends GetxController {
  static bool logined = false;
  var username = ''.obs;
  var password = ''.obs;
  var address = ''.obs;

  GetStorage storage = GetStorage();

  @override
  Future<void> onInit() async {
    username.value = storage.read('username') ?? "";
    password.value = storage.read('password') ?? "";
    address.value = storage.read('address') ?? "";
    ApiClient().setAddress('http://$address');
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
    final settingsStorage = Get.find<SettingsController>().storage;
    final autoStartServer =
        settingsStorage.read(StorageKey.autoStartServer.name) ?? false;
    final autoStartScript =
        settingsStorage.read(StorageKey.autoStartScript.name) ?? false;
    if ((autoStartServer || autoStartScript) &&
        Get.previousRoute != '/settings') {
      // 延迟执行导航，以确保路由栈准备就绪
      // 使用 Future.delayed 可以给 GetX 留出更多时间完成初始化
      Future.delayed(Duration.zero, () async {
        await Get.toNamed("/server");
      });
    } else if (address.value.isNotEmpty && !logined) {
      logined = true;
      // 这里也建议延迟，或者在UI层面处理
      Future.delayed(Duration.zero, () async {
        await login(address.value);
      });
    }
  }

  /// 进入主页面
  Future<void> toMain({required Map<String, dynamic> data}) async {
    storage.write('username', data['username']);
    storage.write('password', data['password']);
    storage.write('address', data['address']);
    printInfo(info: data.toString());
    await login(data['address']);
  }

  Future<void> login(String address) async {
    if (await ApiClient().testAddress()) {
      // Get.snackbar('Success', 'Successfully connected to OAS server');
      Get.offAllNamed('/main');
    } else {
      Get.snackbar('Error', 'Failed to connect to OAS server');
    }
  }
}
