import 'user_model.dart';

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String avatar;
  final String createdBy;
  final List<String> memberIds;
  final List<UserModel> members;
  final DateTime createdAt;

  const GroupModel({
    required this.id,
    required this.name,
    this.description = '',
    this.avatar = '',
    required this.createdBy,
    this.memberIds = const [],
    this.members = const [],
    required this.createdAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      avatar: json['avatar'] ?? '',
      createdBy: json['createdBy'] ?? '',
      memberIds: List<String>.from(json['memberIds'] ?? []),
      members: (json['members'] as List?)
              ?.map((m) => UserModel.fromJson(m is Map<String, dynamic> ? m : {}))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'G';
  }
}
