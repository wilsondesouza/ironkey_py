import 'dart:convert';

class SyncConflict {
  final int? id;
  final String entryUid;
  final String deviceId;
  final Map<String, dynamic> detail;
  final bool resolved;
  final String createdAt;

  SyncConflict({
    this.id,
    required this.entryUid,
    required this.deviceId,
    required this.detail,
    this.resolved = false,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'entry_uid': entryUid,
      'device_id': deviceId,
      'detail_json': jsonEncode(detail),
      'resolved': resolved ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory SyncConflict.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsedDetail = {};
    if (map['detail_json'] != null) {
      if (map['detail_json'] is Map) {
        parsedDetail = Map<String, dynamic>.from(map['detail_json']);
      } else if (map['detail_json'] is String && (map['detail_json'] as String).isNotEmpty) {
        try {
          parsedDetail = Map<String, dynamic>.from(jsonDecode(map['detail_json']));
        } catch (_) {}
      }
    }

    return SyncConflict(
      id: map['id'] as int?,
      entryUid: map['entry_uid'] as String? ?? '',
      deviceId: map['device_id'] as String? ?? '',
      detail: parsedDetail,
      resolved: map['resolved'] == 1 || map['resolved'] == true,
      createdAt: map['created_at'] as String?,
    );
  }
}
