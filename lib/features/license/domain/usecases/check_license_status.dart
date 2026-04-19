import '../entities/license.dart';
import '../repositories/license_repository.dart';

/// Returns the current license from cache, optionally re-verifying online.
class CheckLicenseStatus {
  final LicenseRepository _repository;
  const CheckLicenseStatus(this._repository);

  Future<License?> call() => _repository.getCachedLicense();
}
