import 'dart:convert';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String avatar;
  final String about;
  final bool isOnline;
  final DateTime? lastSeen;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatar = '',
    this.about = 'Hey there! I am using ChatApp',
    this.isOnline = false,
    this.lastSeen,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar'] ?? '',
      about: json['about'] ?? 'Hey there! I am using ChatApp',
      isOnline: json['isOnline'] ?? false,
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
      'about': about,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory UserModel.fromJsonString(String source) =>
      UserModel.fromJson(jsonDecode(source));

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? avatar,
    String? about,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      about: about ?? this.about,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
