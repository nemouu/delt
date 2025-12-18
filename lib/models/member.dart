import 'package:uuid/uuid.dart';
import 'enums.dart';

/// Member model - represents a member in a group
class Member {
  final String id;
  final String groupId;
  final String name;
  final String colorHex; // For UI differentiation (e.g., "#FF5733")
  final MemberRole role;
  final JoinMethod joinMethod; // How they joined the group
  final int addedAt;
  final String addedBy; // Member ID of who added them

  Member({
    String? id,
    required this.groupId,
    required this.name,
    required this.colorHex,
    MemberRole? role,
    JoinMethod? joinMethod,
    int? addedAt,
    required this.addedBy,
  })  : id = id ?? const Uuid().v4(),
        role = role ?? MemberRole.member,
        joinMethod = joinMethod ?? JoinMethod.manual,
        addedAt = addedAt ?? DateTime.now().millisecondsSinceEpoch;

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'name': name,
      'colorHex': colorHex,
      'role': role.toStr(),
      'joinMethod': joinMethod.toStr(),
      'addedAt': addedAt,
      'addedBy': addedBy,
    };
  }

  /// Create from database Map
  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      name: map['name'] as String,
      colorHex: map['colorHex'] as String,
      role: MemberRoleExtension.fromStr(map['role'] as String),
      joinMethod: JoinMethodExtension.fromStr(map['joinMethod'] as String),
      addedAt: map['addedAt'] as int,
      addedBy: map['addedBy'] as String,
    );
  }

  /// Convert to JSON for export/sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'name': name,
      'colorHex': colorHex,
      'role': role.toStr(),
      'joinMethod': joinMethod.toStr(),
      'addedAt': addedAt,
      'addedBy': addedBy,
    };
  }

  /// Create from JSON
  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      name: json['name'] as String,
      colorHex: json['colorHex'] as String,
      role: MemberRoleExtension.fromStr(json['role'] as String),
      joinMethod: JoinMethodExtension.fromStr(json['joinMethod'] as String),
      addedAt: json['addedAt'] as int,
      addedBy: json['addedBy'] as String,
    );
  }

  /// Create a copy with updated fields
  Member copyWith({
    String? id,
    String? groupId,
    String? name,
    String? colorHex,
    MemberRole? role,
    JoinMethod? joinMethod,
    int? addedAt,
    String? addedBy,
  }) {
    return Member(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      role: role ?? this.role,
      joinMethod: joinMethod ?? this.joinMethod,
      addedAt: addedAt ?? this.addedAt,
      addedBy: addedBy ?? this.addedBy,
    );
  }

  @override
  String toString() {
    return 'Member(id: $id, name: $name, role: $role, groupId: $groupId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Member &&
        other.id == id &&
        other.groupId == groupId &&
        other.name == name &&
        other.colorHex == colorHex &&
        other.role == role &&
        other.joinMethod == joinMethod &&
        other.addedAt == addedAt &&
        other.addedBy == addedBy;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        groupId.hashCode ^
        name.hashCode ^
        colorHex.hashCode ^
        role.hashCode ^
        joinMethod.hashCode ^
        addedAt.hashCode ^
        addedBy.hashCode;
  }
}
