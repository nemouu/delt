/// Sync method for group synchronization
enum SyncMethod {
  bluetooth,
  wifiDirect,
  wifiNetwork, // Same WiFi network sync
  manual, // No automatic sync, export/import only
}

/// Tracks the actual sharing state of a group
enum ShareState {
  local, // Never shared, exists only on this device
  pending, // QR code generated, waiting for another device to join
  active, // Actually shared with other devices
}

/// Member role in a group
enum MemberRole {
  admin, // Can add/remove members, delete group
  member, // Can add expenses, view balances
}

/// How a member joined the group
enum JoinMethod {
  code, // Joined via invite code/QR (real user with app)
  manual, // Added manually as local placeholder (no app)
}

/// Split type for group expenses
enum SplitType {
  equal, // Divide equally
  unequal, // Custom amounts per person
  percentage, // By percentage
}

/// Type of trusted WiFi network
enum NetworkType {
  personal, // Personal network (home, office)
  groupSpecific, // Group-specific network (auto-removed with group)
}

/// Extension to convert enum to/from string for database storage
extension SyncMethodExtension on SyncMethod {
  String toStr() => toString().split('.').last;

  static SyncMethod fromStr(String str) {
    switch (str) {
      case 'bluetooth':
        return SyncMethod.bluetooth;
      case 'wifiDirect':
        return SyncMethod.wifiDirect;
      case 'wifiNetwork':
        return SyncMethod.wifiNetwork;
      case 'manual':
      default:
        return SyncMethod.manual;
    }
  }
}

extension ShareStateExtension on ShareState {
  String toStr() => toString().split('.').last;

  static ShareState fromStr(String str) {
    switch (str) {
      case 'local':
        return ShareState.local;
      case 'pending':
        return ShareState.pending;
      case 'active':
        return ShareState.active;
      default:
        return ShareState.local;
    }
  }
}

extension MemberRoleExtension on MemberRole {
  String toStr() => toString().split('.').last;

  static MemberRole fromStr(String str) {
    switch (str) {
      case 'admin':
        return MemberRole.admin;
      case 'member':
      default:
        return MemberRole.member;
    }
  }
}

extension JoinMethodExtension on JoinMethod {
  String toStr() => toString().split('.').last;

  static JoinMethod fromStr(String str) {
    switch (str) {
      case 'code':
        return JoinMethod.code;
      case 'manual':
      default:
        return JoinMethod.manual;
    }
  }
}

extension SplitTypeExtension on SplitType {
  String toStr() => toString().split('.').last;

  static SplitType fromStr(String str) {
    switch (str) {
      case 'equal':
        return SplitType.equal;
      case 'unequal':
        return SplitType.unequal;
      case 'percentage':
        return SplitType.percentage;
      default:
        return SplitType.equal;
    }
  }
}

extension NetworkTypeExtension on NetworkType {
  String toStr() => toString().split('.').last;

  static NetworkType fromStr(String str) {
    switch (str) {
      case 'personal':
        return NetworkType.personal;
      case 'groupSpecific':
      default:
        return NetworkType.groupSpecific;
    }
  }
}
