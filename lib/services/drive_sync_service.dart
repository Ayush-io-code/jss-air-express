// lib/services/drive_sync_service.dart
//
// Three operations used by AppProvider:
//
//   fetchVersion()      → returns Drive file's modifiedTime string (cheap, ~1 KB response).
//                         AppProvider compares this to _lastKnownVersion to decide
//                         whether a full download is needed. If equal, skip.
//
//   pullWithVersion()   → downloads the file and returns (jsonString, modifiedTime).
//                         Used when fetchVersion() says something changed.
//
//   push(jsonData)      → uploads jsonData, returns the new modifiedTime on success.
//                         AppProvider stores this so the next poll tick skips the download.
//
// All three return null on network failure — the app just keeps its local state.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class DriveSyncService {
  static final DriveSyncService instance = DriveSyncService._();
  DriveSyncService._();

  static const _fileName  = 'jss_app_data.json';
  static const _mimeType  = 'application/json';
  static const _scope     = 'https://www.googleapis.com/auth/drive.appdata';
  static const _uploadUrl = 'https://www.googleapis.com/upload/drive/v3/files';
  static const _filesUrl  = 'https://www.googleapis.com/drive/v3/files';

  GoogleSignInAccount? _account;
  String?              _cachedFileId;

  bool    get isSignedIn => _account != null;
  String? get userEmail  => _account?.email;

  final _googleSignIn = GoogleSignIn(scopes: [_scope]);

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<bool> tryRestoreSignIn() async {
    try {
      _account = await _googleSignIn.signInSilently();
      return _account != null;
    } catch (e) {
      debugPrint('[DriveSync] silent restore failed: $e');
      return false;
    }
  }

  Future<bool> signIn() async {
    try {
      _account = await _googleSignIn.signIn();
      return _account != null;
    } catch (e) {
      debugPrint('[DriveSync] sign-in failed: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account      = null;
    _cachedFileId = null;
  }

  // ── Token ──────────────────────────────────────────────────────────────────

  Future<String?> _accessToken() async {
    if (_account == null) return null;
    try {
      final auth = await _account!.authentication;
      return auth.accessToken;
    } catch (e) {
      debugPrint('[DriveSync] token error: $e');
      return null;
    }
  }

  Map<String, String> _authHeader(String token) => {
        'Authorization': 'Bearer $token',
      };

  // ── Find file ID ───────────────────────────────────────────────────────────

  Future<String?> _findFileId(String token) async {
    if (_cachedFileId != null) return _cachedFileId;

    final uri = Uri.parse(_filesUrl).replace(queryParameters: {
      'spaces': 'appDataFolder',
      'fields': 'files(id,name)',
      'q':      "name='$_fileName'",
    });

    final res = await http.get(uri,
        headers: {..._authHeader(token), 'Content-Type': 'application/json'});

    if (res.statusCode != 200) {
      debugPrint('[DriveSync] list error: ${res.body}');
      return null;
    }

    final files = (jsonDecode(res.body)['files'] as List?) ?? [];
    if (files.isNotEmpty) _cachedFileId = files.first['id'] as String;
    return _cachedFileId;
  }

  // ── fetchVersion ───────────────────────────────────────────────────────────
  //
  // Returns the Drive file's modifiedTime string, e.g. "2026-05-11T10:23:45.000Z".
  // This is a tiny metadata-only request (~400 bytes).
  // Returns null if the file doesn't exist yet or on error.

  Future<String?> fetchVersion() async {
    final token = await _accessToken();
    if (token == null) return null;

    try {
      final fileId = await _findFileId(token);
      if (fileId == null) return null;

      final uri = Uri.parse('$_filesUrl/$fileId').replace(
          queryParameters: {'fields': 'modifiedTime'});

      final res = await http.get(uri, headers: _authHeader(token));
      if (res.statusCode != 200) return null;

      return (jsonDecode(res.body) as Map)['modifiedTime'] as String?;
    } catch (e) {
      debugPrint('[DriveSync] fetchVersion error: $e');
      return null;
    }
  }

  // ── pullWithVersion ────────────────────────────────────────────────────────
  //
  // Downloads the file content AND its modifiedTime in one go.
  // Returns a record (jsonString, modifiedTime), or null on error.

  Future<(String, String)?> pullWithVersion() async {
    final token = await _accessToken();
    if (token == null) return null;

    try {
      final fileId = await _findFileId(token);
      if (fileId == null) return null;

      // Get modifiedTime first (metadata only)
      final metaUri = Uri.parse('$_filesUrl/$fileId')
          .replace(queryParameters: {'fields': 'modifiedTime'});
      final metaRes = await http.get(metaUri, headers: _authHeader(token));
      if (metaRes.statusCode != 200) return null;
      final modifiedTime =
          (jsonDecode(metaRes.body) as Map)['modifiedTime'] as String? ?? '';

      // Download content
      final contentRes = await http.get(
          Uri.parse('$_filesUrl/$fileId?alt=media'),
          headers: _authHeader(token));
      if (contentRes.statusCode != 200) return null;

      return (contentRes.body, modifiedTime);
    } catch (e) {
      debugPrint('[DriveSync] pullWithVersion error: $e');
      return null;
    }
  }

  // ── push ───────────────────────────────────────────────────────────────────
  //
  // Creates or updates the Drive file with [jsonData].
  // Returns the new modifiedTime on success, null on failure.
  // AppProvider stores the returned version so the next poll tick can skip
  // downloading data it just uploaded.

  Future<String?> push(String jsonData) async {
    final token = await _accessToken();
    if (token == null) return null;

    try {
      final fileId = await _findFileId(token);
      String? newFileId;

      if (fileId == null) {
        // ── Create new file (multipart) ──
        final metaBytes  = utf8.encode(jsonEncode({
          'name': _fileName, 'parents': ['appDataFolder'],
        }));
        final mediaBytes = utf8.encode(jsonData);
        final boundary   = 'jss_b_${DateTime.now().millisecondsSinceEpoch}';

        final body = <int>[
          ...utf8.encode('--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n'),
          ...metaBytes,
          ...utf8.encode('\r\n--$boundary\r\nContent-Type: $_mimeType\r\n\r\n'),
          ...mediaBytes,
          ...utf8.encode('\r\n--$boundary--'),
        ];

        final res = await http.post(
          Uri.parse('$_uploadUrl?uploadType=multipart&fields=id,modifiedTime'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type':  'multipart/related; boundary=$boundary',
          },
          body: body,
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          final j = jsonDecode(res.body) as Map;
          _cachedFileId = j['id'] as String?;
          newFileId     = _cachedFileId;
          return j['modifiedTime'] as String?;
        }
        debugPrint('[DriveSync] create failed: ${res.body}');
        return null;
      } else {
        // ── Update existing file ──
        final res = await http.patch(
          Uri.parse(
              '$_uploadUrl/$fileId?uploadType=media&fields=modifiedTime'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type':  _mimeType,
          },
          body: utf8.encode(jsonData),
        );

        if (res.statusCode == 200) {
          return (jsonDecode(res.body) as Map)['modifiedTime'] as String?;
        }
        debugPrint('[DriveSync] update failed: ${res.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[DriveSync] push error: $e');
      return null;
    }
  }
}
