import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._();
  SubscriptionService._();

  static const String _keyExpiryDate = 'sub_expiry_date';
  static const String _keyIsActive = 'sub_is_active';
  static const String _keyLicenseKey = 'sub_license_key';
  static const int monthlyPrice = 200; // ₹200/month

  // ── Check subscription status ──────────────────────────────────────────────
  Future<SubscriptionStatus> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString(_keyExpiryDate);

    if (expiryStr == null) return SubscriptionStatus.notActivated;

    final expiry = DateTime.parse(expiryStr);
    final now = DateTime.now();
    final daysLeft = expiry.difference(now).inDays;

    if (now.isAfter(expiry)) return SubscriptionStatus.expired;
    if (daysLeft <= 2) return SubscriptionStatus.expiringSoon;
    return SubscriptionStatus.active;
  }

  Future<DateTime?> getExpiryDate() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString(_keyExpiryDate);
    if (expiryStr == null) return null;
    return DateTime.parse(expiryStr);
  }

  Future<int> getDaysLeft() async {
    final expiry = await getExpiryDate();
    if (expiry == null) return 0;
    final diff = expiry.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  // ── Activate / Renew with License Key ────────────────────────────────────
  // In production: validate key via your backend API
  // Here: simple offline key validation for demo
  Future<bool> activateWithKey(String licenseKey) async {
    final isValid = _validateKey(licenseKey);
    if (!isValid) return false;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Check if already active — extend from current expiry
    final existingExpiry = prefs.getString(_keyExpiryDate);
    DateTime startFrom = now;
    if (existingExpiry != null) {
      final existing = DateTime.parse(existingExpiry);
      if (existing.isAfter(now)) startFrom = existing;
    }

    final newExpiry = startFrom.add(const Duration(days: 30));
    await prefs.setString(_keyExpiryDate, newExpiry.toIso8601String());
    await prefs.setBool(_keyIsActive, true);
    await prefs.setString(_keyLicenseKey, licenseKey);
    return true;
  }

  // ── FOR TESTING: activate 30 days free trial ─────────────────────────────
  Future<void> activateFreeTrial() async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.now().add(const Duration(days: 30));
    await prefs.setString(_keyExpiryDate, expiry.toIso8601String());
    await prefs.setBool(_keyIsActive, true);
  }

  // ── Simple key validation (replace with server validation in production) ──
  bool _validateKey(String key) {
    // Key format: SHOP-XXXX-XXXX-XXXX (16 alphanumeric after SHOP-)
    final regex = RegExp(r'^SHOP-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$');
    return regex.hasMatch(key.toUpperCase());
  }

  Future<void> clearSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyExpiryDate);
    await prefs.remove(_keyIsActive);
    await prefs.remove(_keyLicenseKey);
  }
}

enum SubscriptionStatus {
  notActivated,
  active,
  expiringSoon, // <= 2 days left
  expired,
}

extension SubscriptionStatusExt on SubscriptionStatus {
  bool get isLocked =>
      this == SubscriptionStatus.expired ||
          this == SubscriptionStatus.notActivated;
  bool get needsReminder => this == SubscriptionStatus.expiringSoon;
}
