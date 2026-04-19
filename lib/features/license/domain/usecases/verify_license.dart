import '../entities/license.dart';
import '../repositories/license_repository.dart';

class VerifyLicense {
  final LicenseRepository _repository;
  const VerifyLicense(this._repository);

  /// Tries network first, falls back to cache.
  Future<License?> call(String mobileNumber) =>
      _repository.verifyLicense(mobileNumber);
}
