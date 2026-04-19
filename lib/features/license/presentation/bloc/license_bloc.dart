import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/activate_license.dart';
import '../../domain/usecases/check_license_status.dart';
import '../../domain/usecases/verify_license.dart';
import '../../domain/repositories/license_repository.dart';
import 'license_event.dart';
import 'license_state.dart';

class LicenseBloc extends Bloc<LicenseEvent, LicenseState> {
  final CheckLicenseStatus _checkLicenseStatus;
  final VerifyLicense _verifyLicense;
  final ActivateLicense _activateLicense;
  final LicenseRepository _repository;

  LicenseBloc({
    required CheckLicenseStatus checkLicenseStatus,
    required VerifyLicense verifyLicense,
    required ActivateLicense activateLicense,
    required LicenseRepository repository,
  })  : _checkLicenseStatus = checkLicenseStatus,
        _verifyLicense = verifyLicense,
        _activateLicense = activateLicense,
        _repository = repository,
        super(const LicenseInitial()) {
    on<CheckLicense>(_onCheckLicense);
    on<VerifyLicenseByMobile>(_onVerifyByMobile);
    on<ActivateLicenseRequested>(_onActivate);
    on<ClearLicenseCache>(_onClearCache);
  }

  Future<void> _onCheckLicense(
    CheckLicense event,
    Emitter<LicenseState> emit,
  ) async {
    emit(const LicenseLoading());
    final license = await _checkLicenseStatus();
    if (license == null) {
      emit(const LicenseNotFound());
    } else if (license.isExpired) {
      emit(LicenseExpired(license));
    } else {
      emit(LicenseValid(license));
    }
  }

  Future<void> _onVerifyByMobile(
    VerifyLicenseByMobile event,
    Emitter<LicenseState> emit,
  ) async {
    emit(const LicenseLoading());
    try {
      final license = await _verifyLicense(event.mobileNumber);
      if (license == null) {
        emit(const LicenseNotFound());
      } else if (license.isExpired) {
        emit(LicenseExpired(license));
      } else {
        emit(LicenseValid(license));
      }
    } catch (e) {
      emit(LicenseError(e.toString()));
    }
  }

  Future<void> _onActivate(
    ActivateLicenseRequested event,
    Emitter<LicenseState> emit,
  ) async {
    emit(const LicenseLoading());
    try {
      final license = await _activateLicense(
        mobileNumber: event.mobileNumber,
        licenseType: event.licenseType,
        deviceId: event.deviceId,
      );
      emit(LicenseActivated(license));
    } catch (e) {
      final message = e is Exception
          ? e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')
          : e.toString();
      emit(LicenseError(message));
    }
  }

  Future<void> _onClearCache(
    ClearLicenseCache event,
    Emitter<LicenseState> emit,
  ) async {
    await _repository.clearCache();
    emit(const LicenseNotFound());
  }
}
