class Message {
  final String type;
  final Map<String, dynamic> data;

  Message({
    required this.type,
    this.data = const {},
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Normalize incoming JSON: prefer `data` object, but also accept
    // messages that put fields like `uid`, `plate`, `time` at top-level.
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(json["data"] ?? {});

    // If sender placed common fields at top-level, merge them into data
    for (final key in ["uid", "cardId", "plate", "time"]) {
      if ((json.containsKey(key)) && !data.containsKey(key)) {
        data[key] = json[key];
      }
    }

    return Message(
      type: json["type"] ?? "",
      data: data,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "type": type,
      "data": data,
    };
  }
}