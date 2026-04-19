/// License type — decides whether billing syncs to cloud or stays local
enum LicenseType {
  offline,
  online;

  String get value => name;

  static LicenseType fromString(String? s) =>
      s == 'online' ? LicenseType.online : LicenseType.offline;

  String get label => this == LicenseType.online ? 'Online' : 'Offline';
}

/// Core license domain entity
class License {
  final String id;
  final String mobileNumber;
  final LicenseType licenseType;
  final String? deviceId;
  final DateTime activatedAt;
  final DateTime expiresAt;
  final bool isActive;
  final DateTime createdAt;

  const License({
    required this.id,
    required this.mobileNumber,
    required this.licenseType,
    this.deviceId,
    required this.activatedAt,
    required this.expiresAt,
    required this.isActive,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => isActive && !isExpired;
  int get daysLeft => expiresAt.difference(DateTime.now()).inDays;

  bool get isOnline => licenseType == LicenseType.online;
  bool get isOffline => licenseType == LicenseType.offline;

  License copyWith({
    String? id,
    String? mobileNumber,
    LicenseType? licenseType,
    String? deviceId,
    DateTime? activatedAt,
    DateTime? expiresAt,
    bool? isActive,
    DateTime? createdAt,
  }) =>
      License(
        id: id ?? this.id,
        mobileNumber: mobileNumber ?? this.mobileNumber,
        licenseType: licenseType ?? this.licenseType,
        deviceId: deviceId ?? this.deviceId,
        activatedAt: activatedAt ?? this.activatedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );
}
