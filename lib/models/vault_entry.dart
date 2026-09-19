import 'dart:convert';
import 'package:uuid/uuid.dart';

class VaultEntry {
  final String uid;
  String title;
  String username;
  String password;
  String url;
  String notes;
  String category;
  List<String> tags;
  bool favorite;
  String totpSecret;
  Map<String, dynamic> customFields;
  int rev;
  String? deletedAt;
  String deviceId;
  String updatedAt;
  String createdAt;

  VaultEntry({
    String? uid,
    required this.title,
    this.username = '',
    this.password = '',
    this.url = '',
    this.notes = '',
    this.category = '',
    List<String>? tags,
    this.favorite = false,
    this.totpSecret = '',
    Map<String, dynamic>? customFields,
    this.rev = 1,
    String? deletedAt,
    this.deviceId = '',
    String? updatedAt,
    String? createdAt,
  })  : uid = uid ?? const Uuid().v4().replaceAll('-', ''),
        tags = tags ?? [],
        customFields = customFields ?? {},
        deletedAt = (deletedAt != null && deletedAt.trim().isNotEmpty) ? deletedAt.trim() : null,
        updatedAt = updatedAt ?? DateTime.now().toUtc().toIso8601String(),
        createdAt = createdAt ?? DateTime.now().toUtc().toIso8601String();

  bool get isDeleted => deletedAt != null && deletedAt!.trim().isNotEmpty;

  String get displayTitle => isDeleted ? '$title (excluído)' : title;

  VaultEntry asTombstone({String deviceId = ''}) {
    return VaultEntry(
      uid: uid,
      title: title,
      username: '',
      password: '',
      url: '',
      notes: '',
      category: '',
      tags: [],
      favorite: false,
      totpSecret: '',
      customFields: {},
      rev: rev + 1,
      deletedAt: DateTime.now().toUtc().toIso8601String(),
      deviceId: deviceId,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'title': title,
      'username': username,
      'password': password,
      'url': url,
      'notes': notes,
      'category': category,
      'tags': jsonEncode(tags),
      'favorite': favorite ? 1 : 0,
      'totp_secret': totpSecret,
      'custom_fields': jsonEncode(customFields),
      'rev': rev,
      'deleted_at': deletedAt,
      'device_id': deviceId,
      'updated_at': updatedAt,
      'created_at': createdAt,
    };
  }

  Map<String, dynamic> toSyncMap() {
    return {
      'uid': uid,
      'title': title,
      'username': username,
      'password': password,
      'url': url,
      'notes': notes,
      'category': category,
      'tags': tags,
      'favorite': favorite,
      'totp_secret': totpSecret,
      'custom_fields': customFields,
      'rev': rev,
      'deleted_at': deletedAt ?? '',
      'device_id': deviceId,
      'updated_at': updatedAt,
      'created_at': createdAt,
    };
  }

  factory VaultEntry.fromMap(Map<String, dynamic> map) {
    List<String> parsedTags = [];
    if (map['tags'] != null) {
      if (map['tags'] is List) {
        parsedTags = List<String>.from(map['tags']);
      } else if (map['tags'] is String && (map['tags'] as String).isNotEmpty) {
        try {
          parsedTags = List<String>.from(jsonDecode(map['tags']));
        } catch (_) {}
      }
    }

    Map<String, dynamic> parsedCustom = {};
    if (map['custom_fields'] != null) {
      if (map['custom_fields'] is Map) {
        parsedCustom = Map<String, dynamic>.from(map['custom_fields']);
      } else if (map['custom_fields'] is String && (map['custom_fields'] as String).isNotEmpty) {
        try {
          parsedCustom = Map<String, dynamic>.from(jsonDecode(map['custom_fields']));
        } catch (_) {}
      }
    }

    final rawDeletedAt = map['deleted_at']?.toString().trim();
    final cleanDeletedAt = (rawDeletedAt != null && rawDeletedAt.isNotEmpty && rawDeletedAt != 'null')
        ? rawDeletedAt
        : null;

    return VaultEntry(
      uid: map['uid'] ?? '',
      title: map['title'] ?? '',
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      url: map['url'] ?? '',
      notes: map['notes'] ?? '',
      category: map['category'] ?? '',
      tags: parsedTags,
      favorite: map['favorite'] == 1 || map['favorite'] == true,
      totpSecret: map['totp_secret'] ?? '',
      customFields: parsedCustom,
      rev: map['rev'] is int ? map['rev'] : int.tryParse(map['rev']?.toString() ?? '1') ?? 1,
      deletedAt: cleanDeletedAt,
      deviceId: map['device_id'] ?? '',
      updatedAt: map['updated_at'],
      createdAt: map['created_at'],
    );
  }

  VaultEntry copyWith({
    String? title,
    String? username,
    String? password,
    String? url,
    String? notes,
    String? category,
    List<String>? tags,
    bool? favorite,
    String? totpSecret,
    Map<String, dynamic>? customFields,
    int? rev,
    String? deletedAt,
    String? deviceId,
    String? updatedAt,
  }) {
    return VaultEntry(
      uid: uid,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      tags: tags ?? List.from(this.tags),
      favorite: favorite ?? this.favorite,
      totpSecret: totpSecret ?? this.totpSecret,
      customFields: customFields ?? Map.from(this.customFields),
      rev: rev ?? this.rev,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt,
    );
  }
}
