import 'package:get/get.dart';

class StatsModel implements Comparable<StatsModel> {
  final name = ''.obs;
  final data = ''.obs;
  final time = DateTime.now().obs;

  StatsModel(
    String name,
    String data,
    DateTime time,
  ) {
    this.name.value = name;
    this.data.value = data;
    this.time.value = time;
  }

  factory StatsModel.fromJson(Map<String, dynamic> json) {
    return StatsModel(
      json['name'],
      json['data'],
      DateTime.parse(json['time']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name.value,
      'data': data.value,
      'time': time.value.millisecondsSinceEpoch,
    };
  }

  @override
  int compareTo(StatsModel other) {
    return other.time.value.compareTo(time.value);
  }
}
