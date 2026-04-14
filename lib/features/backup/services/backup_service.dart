import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  // ── Google Auth ──────────────────────────────────────────────────────────────
  Future<GoogleSignInAccount?> _signIn() async {
    try {
      return await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
    } catch (e) {
      return null;
    }
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    final account = await _signIn();
    if (account == null) return null;
    final headers = await account.authHeaders;
    final client = _AuthenticatedClient(headers);
    return drive.DriveApi(client);
  }

  // ── Backup to Drive ──────────────────────────────────────────────────────────
  Future<bool> backupToGoogleDrive() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      // Get DB file path
      final dbPath = await getDatabasesPath();
      final dbFile = File(path.join(dbPath, 'shop_pos.db'));
      if (!dbFile.existsSync()) return false;

      final now = DateTime.now();
      final fileName =
          'shop_pos_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.db';

      // Find or create ShopPOS folder
      final folderId = await _getOrCreateFolder(driveApi);

      // Upload file
      final fileBytes = await dbFile.readAsBytes();
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId];

      await driveApi.files.create(
        driveFile,
        uploadMedia: drive.Media(
          Stream.fromIterable([fileBytes]),
          fileBytes.length,
        ),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Restore from Drive ────────────────────────────────────────────────────────
  Future<bool> restoreFromGoogleDrive() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      // List backup files
      final folderId = await _getOrCreateFolder(driveApi);
      final fileList = await driveApi.files.list(
        q: "'$folderId' in parents and name contains 'shop_pos_backup'",
        orderBy: 'createdTime desc',
        pageSize: 1,
        $fields: 'files(id, name, createdTime)',
      );

      if (fileList.files == null || fileList.files!.isEmpty) return false;

      final latestFile = fileList.files!.first;

      // Download
      final media = await driveApi.files.get(
        latestFile.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await media.stream.forEach((chunk) => bytes.addAll(chunk));

      // Replace database file
      final dbPath = await getDatabasesPath();
      final dbFile = File(path.join(dbPath, 'shop_pos.db'));

      // Close existing DB connection
      // Note: In production, close DatabaseHelper first
      await dbFile.writeAsBytes(bytes);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── List Backups ──────────────────────────────────────────────────────────────
  Future<List<drive.File>> listBackups() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return [];
      final folderId = await _getOrCreateFolder(driveApi);
      final fileList = await driveApi.files.list(
        q: "'$folderId' in parents and name contains 'shop_pos_backup'",
        orderBy: 'createdTime desc',
        $fields: 'files(id, name, createdTime, size)',
      );
      return fileList.files ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<String> _getOrCreateFolder(drive.DriveApi driveApi) async {
    const folderName = 'ShopPOS Backups';
    final query = "mimeType='application/vnd.google-apps.folder' and name='$folderName' and trashed=false";
    final list = await driveApi.files.list(q: query, $fields: 'files(id)');

    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }

    // Create folder
    final folder = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await driveApi.files.create(folder);
    return created.id!;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}

// ── HTTP Client with auth headers ─────────────────────────────────────────────
class _AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
