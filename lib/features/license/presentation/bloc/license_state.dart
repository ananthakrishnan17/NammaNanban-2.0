import '../../domain/entities/license.dart';

abstract class LicenseState {
  const LicenseState();
}

/// Initial state before any check is performed
class LicenseInitial extends LicenseState {
  const LicenseInitial();
}

/// License is being checked/verified
class LicenseLoading extends LicenseState {
  const LicenseLoading();
}

/// A valid license was found (from cache or network)
class LicenseValid extends LicenseState {
  final License license;
  const LicenseValid(this.license);
}

/// No valid license found — show activation screen
class LicenseNotFound extends LicenseState {
  const LicenseNotFound();
}

/// License has expired
class LicenseExpired extends LicenseState {
  final License license;
  const LicenseExpired(this.license);
}

/// License successfully activated
class LicenseActivated extends LicenseState {
  final License license;
  const LicenseActivated(this.license);
}

/// An error occurred (network, validation, etc.)
class LicenseError extends LicenseState {
  final String message;
  const LicenseError(this.message);
}
