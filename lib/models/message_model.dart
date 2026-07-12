class Message {
  final String type;
  final Map<String, dynamic> data;

  Message({
    required this.type,
    required this.data,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      type: json["type"] ?? "",
      data: Map<String, dynamic>.from(json["data"] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "type": type,
      "data": data,
    };
  }
}