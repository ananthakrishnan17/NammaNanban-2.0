import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../../domain/entities/license.dart';
import '../../domain/repositories/license_repository.dart';
import '../models/license_model.dart';

class LicenseRepositoryImpl implements LicenseRepository {
  static const _kMobileNumber = 'license_mobile_number';
  static const _kLicenseType = 'license_type';
  static const _kLicenseId = 'license_id_v2';
  static const _kExpiresAt = 'license_expires_at_v2';
  static const _kIsActive = 'license_is_active';

  // ── Activate ──────────────────────────────────────────────────────────────
  @override
  Future<License> activateLicense({
    required String mobileNumber,
    required LicenseType licenseType,
    required String deviceId,
  }) async {
    // Look up existing license in Supabase by mobile number
    final existing = await SupabaseClientHelper.table('licenses')
        .select()
        .eq('mobile_number', mobileNumber)
        .eq('is_active', true)
        .maybeSingle();

    if (existing == null) {
      throw Exception(
          'No active license found for this mobile number. Contact support.');
    }

    // Check expiry
    final expiresAt = DateTime.parse(existing['expires_at'] as String);
    if (DateTime.now().isAfter(expiresAt)) {
      throw Exception('License has expired. Please renew.');
    }

    // Update license type and device_id in Supabase
    await SupabaseClientHelper.table('licenses').update({
      'license_type': licenseType.value,
      'device_id': deviceId,
      'activated_at': DateTime.now().toIso8601String(),
    }).eq('id', existing['id'] as String);

    final model = LicenseModel.fromSupabase({
      ...existing,
      'license_type': licenseType.value,
      'device_id': deviceId,
      'activated_at': DateTime.now().toIso8601String(),
    });

    await cacheLicense(model);
    return model;
  }

  // ── Verify online ─────────────────────────────────────────────────────────
  @override
  Future<License?> verifyLicense(String mobileNumber) async {
    try {
      final row = await SupabaseClientHelper.table('licenses')
          .select()
          .eq('mobile_number', mobileNumber)
          .eq('is_active', true)
          .maybeSingle();

      if (row == null) return null;

      final model = LicenseModel.fromSupabase(row);
      if (model.isExpired) return null;

      await cacheLicense(model);
      return model;
    } catch (_) {
      // Network error — fall back to cache
      return getCachedLicense();
    }
  }

  // ── Local cache ───────────────────────────────────────────────────────────
  @override
  Future<License?> getCachedLicense() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('license_cache', limit: 1);
      if (rows.isEmpty) return null;
      final model = LicenseModel.fromLocalMap(rows.first);
      return model.isExpired ? null : model;
    } catch (_) {
      // Fallback to SharedPreferences cache
      return _getCachedFromPrefs();
    }
  }

  Future<License?> _getCachedFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kLicenseId);
    if (id == null) return null;
    final expiresStr = prefs.getString(_kExpiresAt);
    if (expiresStr == null) return null;
    final expiresAt = DateTime.tryParse(expiresStr);
    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) return null;
    return LicenseModel(
      id: id,
      mobileNumber: prefs.getString(_kMobileNumber) ?? '',
      licenseType: LicenseType.fromString(prefs.getString(_kLicenseType)),
      activatedAt: DateTime.now(),
      expiresAt: expiresAt,
      isActive: prefs.getBool(_kIsActive) ?? true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> cacheLicense(License license) async {
    // Persist in local DB
    try {
      final db = await DatabaseHelper.instance.database;
      final model = LicenseModel.fromEntity(license);
      await db.delete('license_cache');
      await db.insert('license_cache', model.toLocalMap());
    } catch (_) {}

    // Persist in SharedPreferences (primary)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLicenseId, license.id);
    await prefs.setString(_kMobileNumber, license.mobileNumber);
    await prefs.setString(_kLicenseType, license.licenseType.value);
    await prefs.setString(_kExpiresAt, license.expiresAt.toIso8601String());
    await prefs.setBool(_kIsActive, license.isActive);

    // Also set legacy keys so existing SupabaseAuthService.fetchCloudUsers() works
    await prefs.setString('sb_license_id', license.id);
    await prefs.setString('sb_expires_at', license.expiresAt.toIso8601String());
  }

  @override
  Future<void> clearCache() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('license_cache');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      _kLicenseId,
      _kMobileNumber,
      _kLicenseType,
      _kExpiresAt,
      _kIsActive,
      // Also clear legacy keys
      'sb_license_id',
      'sb_license_key',
      'sb_plan',
      'sb_expires_at',
      'sb_company_name',
    ]) {
      await prefs.remove(k);
    }
  }
}
