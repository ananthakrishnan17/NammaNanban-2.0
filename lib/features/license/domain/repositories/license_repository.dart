import '../entities/license.dart';

/// Abstract repository for license operations
abstract class LicenseRepository {
  /// Activate a new license for the given mobile number and type.
  /// Returns the created [License] or throws.
  Future<License> activateLicense({
    required String mobileNumber,
    required LicenseType licenseType,
    required String deviceId,
  });

  /// Verify the license associated with [mobileNumber] against Supabase.
  Future<License?> verifyLicense(String mobileNumber);

  /// Return the cached license from local storage without network.
  Future<License?> getCachedLicense();

  /// Cache the given license locally for offline use.
  Future<void> cacheLicense(License license);

  /// Clear the local license cache (e.g. on logout).
  Future<void> clearCache();
}
