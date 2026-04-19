import '../../domain/entities/license.dart';

/// Data model — maps to/from the Supabase `licenses` table and the local
/// `license_cache` SQLite table.
class LicenseModel extends License {
  const LicenseModel({
    required super.id,
    required super.mobileNumber,
    required super.licenseType,
    super.deviceId,
    required super.activatedAt,
    required super.expiresAt,
    required super.isActive,
    required super.createdAt,
  });

  // ── From Supabase row ─────────────────────────────────────────────────────
  factory LicenseModel.fromSupabase(Map<String, dynamic> map) => LicenseModel(
        id: map['id'] as String,
        mobileNumber: map['mobile_number'] as String,
        licenseType: LicenseType.fromString(map['license_type'] as String?),
        deviceId: map['device_id'] as String?,
        activatedAt: DateTime.parse(map['activated_at'] as String),
        expiresAt: DateTime.parse(map['expires_at'] as String),
        isActive: (map['is_active'] as bool?) ?? true,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  // ── To Supabase row ───────────────────────────────────────────────────────
  Map<String, dynamic> toSupabase() => {
        'id': id,
        'mobile_number': mobileNumber,
        'license_type': licenseType.value,
        'device_id': deviceId,
        'activated_at': activatedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };

  // ── From local SQLite cache row ───────────────────────────────────────────
  factory LicenseModel.fromLocalMap(Map<String, dynamic> map) => LicenseModel(
        id: map['id'] as String,
        mobileNumber: map['mobile_number'] as String,
        licenseType: LicenseType.fromString(map['license_type'] as String?),
        deviceId: map['device_id'] as String?,
        activatedAt: DateTime.parse(map['activated_at'] as String),
        expiresAt: DateTime.parse(map['expires_at'] as String),
        isActive: (map['is_active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  // ── To local SQLite cache row ─────────────────────────────────────────────
  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'mobile_number': mobileNumber,
        'license_type': licenseType.value,
        'device_id': deviceId,
        'activated_at': activatedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory LicenseModel.fromEntity(License license) => LicenseModel(
        id: license.id,
        mobileNumber: license.mobileNumber,
        licenseType: license.licenseType,
        deviceId: license.deviceId,
        activatedAt: license.activatedAt,
        expiresAt: license.expiresAt,
        isActive: license.isActive,
        createdAt: license.createdAt,
      );
}
