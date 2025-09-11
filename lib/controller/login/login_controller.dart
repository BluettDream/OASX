part of login;

class LoginController extends GetxController {
  static bool logged = false;
  var username = ''.obs;
  var password = ''.obs;
  var address = ''.obs;

  GetStorage storage = GetStorage();

  @override
  Future<void> onInit() async {
    username.value = storage.read(StorageKey.username.name) ?? "";
    password.value = storage.read(StorageKey.password.name) ?? "";
    address.value = storage.read(StorageKey.address.name) ?? "";
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
    final autoStartServer =
        storage.read(StorageKey.autoStartServer.name) ?? false;
    final autoStartScript =
        storage.read(StorageKey.autoStartScript.name) ?? false;
    // 开启了自动启动服务或脚本并且没有登录过则前往server页面自动启动
    if ((autoStartServer || autoStartScript) && !logged) {
      // 延迟执行导航，以确保路由栈准备就绪
      Future.delayed(Duration.zero, () async {
        await Get.toNamed("/server");
      });
    } else if (address.value.isNotEmpty && !logged) {
      Future.delayed(Duration.zero, () async {
        await login();
      });
    }
  }

  /// 进入主页面
  static Future<void> toMain({required Map<String, dynamic> data}) async {
    GetStorage().write('username', data['username']);
    GetStorage().write('password', data['password']);
    GetStorage().write('address', data['address']);
    if (kDebugMode) {
      print(data.toString());
    }
    await login();
    if (logged) {
      Get.offAllNamed("/main");
    }
  }

  static Future<void> login({bool showSnackBar = true}) async {
    final storageAddress =
        (GetStorage().read(StorageKey.address.name) as String?) ?? '';
    if (storageAddress.isEmpty) {
      logged = false;
      return;
    }
    ApiClient().setAddress('http://$storageAddress');
    if (await ApiClient().testAddress()) {
      logged = true;
    } else {
      if (showSnackBar) {
        Get.snackbar(I18n.error.tr, 'Failed to connect to OAS server');
      }
      logged = false;
    }
  }
}
