import 'dart:convert';

import 'package:flutter_nb_net/flutter_net.dart';
import 'package:get/get.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:oasx/api/api_interceptor.dart';

import 'package:oasx/component/dio_http_cache/dio_http_cache.dart';
import 'package:oasx/translation/i18n.dart';
import 'package:oasx/translation/i18n_content.dart';
import 'package:oasx/utils/check_version.dart';
import 'package:oasx/config/constants.dart';
import 'package:oasx/controller/settings.dart';
import './home_model.dart';
import './update_info_model.dart';

/// common result
class ApiResult<T> {
  final T? data;
  final String? error;
  final int? code;

  ApiResult({this.data, this.error, this.code});

  bool get isSuccess => error == null || error!.isEmpty;

  ApiResult.success(this.data)
      : error = null,
        code = null;

  ApiResult.failure(this.error, [this.code]) : data = null;

  factory ApiResult.fromJson(Map<String, dynamic> json) {
    return ApiResult(
      data: json["data"],
      error: json["error"],
      code: json["code"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "data": this.data,
      "error": this.error,
      "code": this.code,
    };
  }
}

class ApiClient {
  // 单例
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal() {
    NetOptions.instance
        .setConnectTimeout(const Duration(seconds: 3))
        .enableLogger(false)
        .addInterceptor(DioCacheInterceptor(
            options: CacheOptions(
          store:
              FileCacheStore(Get.find<SettingsController>().temporaryDirectory),
          policy: CachePolicy.request,
          hitCacheOnErrorExcept: [401, 403],
          maxStale: const Duration(days: 7),
          priority: CachePriority.normal,
          cipher: null,
          keyBuilder: CacheOptions.defaultCacheKeyBuilder,
          allowPostMethod: false,
        )))
        .addInterceptor(ApiInterceptor())
        .create();
  }

  // http://$address 地址的前缀开头
  String address = '127.0.0.1:22288';

  void setAddress(String address) {
    this.address = address;
    NetOptions.instance.dio.options.baseUrl = address;
  }

  /// common request method
  Future<ApiResult<T>> request<T>(
    Future<Result<dynamic>> Function() apiFn, {
    void Function(String msg, int code)? onError,
  }) async {
    try {
      final res = await apiFn();
      return res.when(
        success: (data) => ApiResult.fromJson(data),
        failure: (msg, code) {
          if (onError != null) onError(msg, code);
          return ApiResult.failure(msg, code);
        },
      );
    } catch (e) {
      printError(info: '$e');
      return ApiResult.failure(e.toString());
    }
  }

// ----------------------------------   服务端地址测试   ----------------------------------
  Future<bool> testAddress() async {
    final res = await request(() => get('/test'), onError: (msg, code) {});
    return res.isSuccess && res.data == 'success';
  }

  Future<bool> killServer() async {
    final res =
        await request(() => get('/home/kill_server'), onError: (msg, code) {});
    return res.isSuccess && res.data == 'success';
  }

// ----------------------------------   杂接口  --------------------------------------------
  Future<bool> notifyTest(String setting, String title, String content) async {
    final res = await request(() => post(
          '/home/notify_test',
          queryParameters: {
            'setting': setting,
            'title': title,
            'content': content
          },
        ));
    if (res.isSuccess && res.data == true) {
      Get.snackbar(I18n.notify_test_success.tr, '');
      return true;
    }
    Get.snackbar(I18n.notify_test_failed.tr, res.data.toString());
    return false;
  }

  Future<GithubVersionModel> getGithubVersion() async {
    final res = await request(() => get(
          updateUrlGithub,
          options: buildCacheOptions(const Duration(days: 7)),
          decodeType: GithubVersionModel(),
        ));
    return res.isSuccess ? res.data : GithubVersionModel();
  }

  Future<ReadmeGithubModel> getGithubReadme() async {
    final res = await request(() => get(
          readmeUrlGithub,
          options: buildCacheOptions(const Duration(days: 7),
              options: Options(extra: {"cache": true})),
          decodeType: ReadmeGithubModel(),
        ));
    return res.isSuccess ? res.data : ReadmeGithubModel();
  }

  Future<UpdateInfoModel> getUpdateInfo() async {
    final res = await request(() => get('/home/update_info'));
    return res.isSuccess
        ? UpdateInfoModel.fromJson(res.data)
        : UpdateInfoModel();
  }

  Future<String?> getExecuteUpdate() async {
    final res = await request(() => get('/home/execute_update'));
    if (res.isSuccess) {
      showDialog('Update', res.data.toString());
      return res.data;
    }
    return res.data;
  }

  Future<bool> putChineseTranslate() async {
    final res = await request(() => put(
          '/home/chinese_translate',
          data: Messages().all_cn_translate,
        ));
    return res.isSuccess && res.data == true;
  }

// ----------------------------------   菜单项管理   ----------------------------------
  Future<Map<String, List<String>>> getScriptMenu() async {
    final res = await request(() => get('/script_menu'));
    return ((res.data ?? {}) as Map).map((k, v) =>
        MapEntry(k.toString(), (v as List).map((e) => e.toString()).toList()));
  }

  Future<Map<String, List<String>>> getHomeMenu() async {
    final res = await request(() => get('/home/home_menu'));
    return ((res.data ?? {}) as Map).map((k, v) =>
        MapEntry(k.toString(), (v as List).map((e) => e.toString()).toList()));
  }

// ----------------------------------   配置文件管理   ----------------------------------
  Future<List<String>> getConfigList() async {
    final res = await request(() => get('/config_list'));
    return ['Home', ...(res.data?.cast<String>() ?? [])];
  }

  Future<List<String>> getScriptList() async {
    final res = await request(() => get('/config_list'));
    return [...(res.data?.cast<String>() ?? [])];
  }

  Future<String> getNewConfigName() async {
    final res = await request(() => get('/config_new_name'));
    return res.isSuccess ? res.data : '';
  }

  Future<List<String>> configCopy(String newName, String template) async {
    final res = await request(() => post(
          '/config_copy',
          queryParameters: {'file': newName, 'template': template},
        ));
    return ['Home', ...(res.data?.cast<String>() ?? [])];
  }

  Future<List<String>> getConfigAll() async {
    final res = await request(() => get('/config_all'));
    return res.data?.cast<String>() ?? ['template'];
  }

  Future<bool> deleteConfig(String name) async {
    final res = await request(() => delete(
          '/config',
          queryParameters: {'name': name},
        ));
    return res.isSuccess && res.data;
  }

  Future<bool> renameConfig(String oldName, String newName) async {
    final res = await request(() => put(
          '/config',
          queryParameters: {'old_name': oldName, 'new_name': newName},
        ));
    return res.isSuccess && res.data;
  }

  Future<bool> copyTask(
      String taskName, String copyConfigName, String sourceConfigName) async {
    final res = await request(() => put(
          '/config/task/copy',
          queryParameters: {
            'task_name': taskName,
            'dest_config_name': copyConfigName,
            'source_config_name': sourceConfigName
          },
        ));
    return res.isSuccess && res.data;
  }

  Future<bool> copyGroup(String taskName, String groupName,
      String copyConfigName, String sourceConfigName) async {
    final res = await request(() => put(
          '/config/task/group/copy',
          queryParameters: {
            'task_name': taskName,
            'group_name': groupName,
            'dest_config_name': copyConfigName,
            'source_config_name': sourceConfigName
          },
        ));
    return res.isSuccess && res.data;
  }

// ---------------------------------   脚本实例管理   ----------------------------------

  Future<Map<String, dynamic>> getScriptTask(
      String scriptName, String taskName) async {
    final res = await request(() => get('/$scriptName/$taskName/args'));
    return res.data ?? {};
  }

  Future<bool> putScriptArg(
    String scriptName,
    String taskName,
    String groupName,
    String argumentName,
    String type,
    dynamic value,
  ) async {
    final res = await request(() => put(
          '/$scriptName/$taskName/$groupName/$argumentName/value',
          queryParameters: {'types': type, 'value': value},
        ));
    return res.isSuccess && res.data == true;
  }

  Future<bool> syncNextRun(String scriptName, String taskName,
      {String? targetDt}) async {
    final res = await request(() => put('/$scriptName/$taskName/sync_next_run',
        queryParameters: {'target_dt': targetDt}));
    return res.isSuccess && res.data == true;
  }

// ---------------------------------   Snackbar --------------------------------
  void showDialog(String title, String content) {
    Get.snackbar(title, content);
  }

  void showNetErrSnackBar() {
    Get.snackbar(I18n.network_error.tr, I18n.network_connect_timeout.tr,
        duration: const Duration(seconds: 5));
  }

  void showNetErrCodeSnackBar(String msg, int code) {
    Get.snackbar(
        I18n.network_error.tr, '${I18n.network_error_code.tr}: $code | $msg',
        duration: const Duration(seconds: 5));
  }
}
