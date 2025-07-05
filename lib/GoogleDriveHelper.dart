import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class GoogleDriveHelper {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveReadonlyScope],
  );

  Future<List<drive.File>> pickDriveFiles() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return [];

    final authHeaders = await account.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);

    final fileList = await driveApi.files.list(
      spaces: 'drive',
      q: "mimeType='application/pdf' or mimeType contains 'image/'",
      $fields: 'files(id, name, mimeType, webViewLink, thumbnailLink)',
    );

    return fileList.files ?? [];
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = IOClient();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}