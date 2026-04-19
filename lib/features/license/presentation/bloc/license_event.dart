import '../../domain/entities/license.dart';

abstract class LicenseEvent {
  const LicenseEvent();
}

/// Check the locally cached license on app start
class CheckLicense extends LicenseEvent {
  const CheckLicense();
}

/// Verify license for a mobile number against Supabase
class VerifyLicenseByMobile extends LicenseEvent {
  final String mobileNumber;
  const VerifyLicenseByMobile(this.mobileNumber);
}

/// Activate a new license with mobile number and type selection
class ActivateLicenseRequested extends LicenseEvent {
  final String mobileNumber;
  final LicenseType licenseType;
  final String deviceId;
  const ActivateLicenseRequested({
    required this.mobileNumber,
    required this.licenseType,
    required this.deviceId,
  });
}

/// Clear the license cache (logout)
class ClearLicenseCache extends LicenseEvent {
  const ClearLicenseCache();
}
