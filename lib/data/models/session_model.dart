class SessionModel {
  final String id;
  final String classId;
  final String name;
  final DateTime startAt;
  final DateTime endAt;
  final String code;
  final String? qrUrl;

  const SessionModel({
    required this.id,
    required this.classId,
    required this.name,
    required this.startAt,
    required this.endAt,
    required this.code,
    this.qrUrl,
  });

  factory SessionModel.fromMap(String id, Map<String, dynamic> data) {
    return SessionModel(
      id: id,
      classId: (data['classId'] ?? '') as String,
      name: (data['name'] ?? '') as String,
      startAt: DateTime.tryParse(data['startAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(
              (data['startAt']?['millisecondsSinceEpoch'] ?? 0) as int,
              isUtc: true),
      endAt: DateTime.tryParse(data['endAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(
              (data['endAt']?['millisecondsSinceEpoch'] ?? 0) as int,
              isUtc: true),
      code: (data['code'] ?? '') as String,
      qrUrl: data['qrUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'name': name,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'code': code,
      'qrUrl': qrUrl,
    };
  }
}

