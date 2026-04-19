import '../../../features/license/domain/entities/license.dart';
import '../../../features/license/domain/repositories/license_repository.dart';
import 'google_drive_backup_service.dart';

/// Schedules periodic Google Drive backups for Offline license users.
///
/// Backups are triggered manually via [runIfDue] (called e.g. on app
/// foreground) rather than a native background scheduler, keeping the
/// implementation dependency-free while still being practical.
class BackupScheduler {
  static final BackupScheduler instance = BackupScheduler._();
  BackupScheduler._();

  static const Duration _interval = Duration(hours: 24);

  DateTime? _lastBackupAt;

  /// Call on app foreground / startup.
  /// Runs a Drive backup if more than [_interval] has passed since the last
  /// successful backup — but only for Offline license users.
  Future<void> runIfDue(LicenseRepository licenseRepository) async {
    final license = await licenseRepository.getCachedLicense();
    if (license == null || !license.isValid) return;
    // Drive backup is only for offline users
    if (license.licenseType != LicenseType.offline) return;

    final now = DateTime.now();
    if (_lastBackupAt != null &&
        now.difference(_lastBackupAt!) < _interval) {
      return; // Not due yet
    }

    final success = await GoogleDriveBackupService.instance.backup();
    if (success) {
      _lastBackupAt = now;
    }
  }
}
