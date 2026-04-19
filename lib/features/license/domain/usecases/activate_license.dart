import '../entities/license.dart';
import '../repositories/license_repository.dart';

class ActivateLicense {
  final LicenseRepository _repository;
  const ActivateLicense(this._repository);

  Future<License> call({
    required String mobileNumber,
    required LicenseType licenseType,
    required String deviceId,
  }) =>
      _repository.activateLicense(
        mobileNumber: mobileNumber,
        licenseType: licenseType,
        deviceId: deviceId,
      );
}
