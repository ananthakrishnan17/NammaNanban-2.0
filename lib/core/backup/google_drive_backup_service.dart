import '../../../features/backup/services/backup_service.dart';

/// Thin wrapper around the existing [BackupService] that provides a
/// named entry-point for Google Drive backup operations used by offline
/// license users.
class GoogleDriveBackupService {
  static final GoogleDriveBackupService instance =
      GoogleDriveBackupService._();
  GoogleDriveBackupService._();

  /// Back up the local SQLite database to Google Drive.
  Future<bool> backup() => BackupService.instance.backupToGoogleDrive();

  /// Restore the most recent backup from Google Drive.
  Future<bool> restore() => BackupService.instance.restoreFromGoogleDrive();

  /// List all available backups in Google Drive.
  Future<List<dynamic>> listBackups() => BackupService.instance.listBackups();

  /// Sign out from Google.
  Future<void> signOut() => BackupService.instance.signOut();
}
