// import 'dart:io';
// import 'package:archive/archive_io.dart';
// import 'package:path/path.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:googleapis/drive/v3.dart' as drive;
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:googleapis_auth/googleapis_auth.dart' as auth;
// import 'package:http/http.dart' as http;
// 
// class BackupService {
//   final GoogleSignIn _googleSignIn = GoogleSignIn(
//     scopes: [drive.DriveApi.driveAppdataScope],
//   );
// 
//   Future<void> createBackup() async {
//     try {
//       final googleUser = await _googleSignIn.signIn();
//       if (googleUser == null) return;
// 
//       final authHeaders = await googleUser.authHeaders;
//       final authenticateClient = auth.authenticatedClient(
//         http.Client(),
//         auth.AccessCredentials(
//           auth.AccessToken('Bearer', authHeaders['Authorization']!.split(' ')[1], 
//           DateTime.now().add(const Duration(hours: 1)).toUtc()),
//           null,
//           [drive.DriveApi.driveAppdataScope],
//         ),
//       );
// 
//       final driveApi = drive.DriveApi(authenticateClient);
// 
//       // 1. Prepare local files
//       final dbDir = await getApplicationDocumentsDirectory();
//       final dbPath = join(dbDir.path, "iz_vault.db");
//       final backupPath = join(dbDir.path, "iz_backup.zip");
// 
//       // 2. Zip the database
//       final encoder = ZipFileEncoder();
//       encoder.create(backupPath);
//       encoder.addFile(File(dbPath));
//       encoder.close();
// 
//       // 3. Upload to Google Drive (AppData folder)
//       final fileToUpload = drive.File();
//       fileToUpload.name = "iz_backup_${DateTime.now().millisecondsSinceEpoch}.zip";
//       fileToUpload.parents = ["appDataFolder"];
// 
//       final media = drive.Media(File(backupPath).openRead(), File(backupPath).lengthSync());
//       await driveApi.files.create(fileToUpload, uploadMedia: media);
// 
//       // 4. Cleanup
//       await File(backupPath).delete();
//     } catch (e) {
//       rethrow;
//     }
//   }
// 
//   Future<void> restoreBackup() async {
//     // Similar logic but using driveApi.files.list and driveApi.files.get
//   }
// }

