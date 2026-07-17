class Message {
  final String type;
  final Map<String, dynamic> data;
  final Object? payload;

  Message({required this.type, this.data = const {}, Object? payload})
    : payload = payload ?? data;

  factory Message.fromJson(Map<String, dynamic> json) {
    // Normalize incoming JSON: prefer `data` object, but also accept
    // messages that put fields like `cid`, `plate`, `time` at top-level.
    final rawData = json["data"];
    final Map<String, dynamic> data = rawData is Map
        ? rawData.map<String, dynamic>(
            (key, value) => MapEntry(key.toString(), value),
          )
        : <String, dynamic>{};

    // If sender placed common fields at top-level, merge them into data.
    for (final key in ["cid", "fix", "plate", "time"]) {
      if ((json.containsKey(key)) && !data.containsKey(key)) {
        data[key] = json[key];
      }
    }

    final Object payload = rawData is List
        ? rawData.map(_normalizeListValue).toList()
        : data;

    return Message(type: json["type"] ?? "", data: data, payload: payload);
  }

  Map<String, dynamic> toJson() {
    return {"type": type, "data": payload};
  }

  static Object? _normalizeListValue(Object? value) {
    if (value is Map) {
      return value.map<String, dynamic>(
        (key, childValue) =>
            MapEntry(key.toString(), _normalizeListValue(childValue)),
      );
    }

    if (value is List) {
      return value.map(_normalizeListValue).toList();
    }

    return value;
  }
}
