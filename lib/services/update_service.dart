import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

/// OTA Update Service for self-hosted app updates via GitHub
class UpdateService {
  static const String UPDATE_JSON_URL = 
      'https://raw.githubusercontent.com/rizkyriyadi/ready-check/main/version.json';

  /// Model for update info
  UpdateInfo? _cachedUpdateInfo;

  /// Check if an update is available
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      // Fetch version.json from GitHub
      final response = await http.get(Uri.parse(UPDATE_JSON_URL))
          .timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) {
        debugPrint('Update check failed: ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body);
      final latestVersion = json['version'] as String;
      final downloadUrl = json['update_url']?['android'] as String? ?? '';
      final releaseNotes = json['release_notes'] as String? ?? '';
      final forceUpdate = json['force_update'] as bool? ?? false;
      final changelog = (json['changelog'] as List<dynamic>?)?.cast<String>() ?? [];

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      debugPrint('Current: $currentVersion, Latest: $latestVersion');

      // Compare versions
      final isUpdateAvailable = _compareVersions(currentVersion, latestVersion) < 0;

      if (isUpdateAvailable) {
        _cachedUpdateInfo = UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
          changelog: changelog,
          forceUpdate: forceUpdate,
        );
        return _cachedUpdateInfo;
      }

      return null;
    } catch (e) {
      debugPrint('Update check error: $e');
      return null;
    }
  }

  /// Compare semantic versions (returns -1 if v1 < v2, 0 if equal, 1 if v1 > v2)
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Pad to same length
    while (parts1.length < 3) parts1.add(0);
    while (parts2.length < 3) parts2.add(0);

    for (int i = 0; i < 3; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }
    return 0;
  }

  /// Download and install APK
  Future<bool> downloadAndInstall(
    String downloadUrl, 
    Function(double) onProgress,
  ) async {
    try {
      // Request permissions
      if (Platform.isAndroid) {
        final status = await Permission.requestInstallPackages.request();
        if (!status.isGranted) {
          debugPrint('Install packages permission denied');
          return false;
        }
      }

      // Get download directory
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        debugPrint('Cannot get storage directory');
        return false;
      }

      final filePath = '${dir.path}/ready_check_update.apk';
      final file = File(filePath);

      // Delete old APK if exists
      if (await file.exists()) {
        await file.delete();
      }

      // Download APK with progress
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await http.Client().send(request);
      
      final contentLength = response.contentLength ?? 0;
      int receivedBytes = 0;
      
      final sink = file.openWrite();
      
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (contentLength > 0) {
          onProgress(receivedBytes / contentLength);
        }
      }
      
      await sink.close();

      debugPrint('APK downloaded to: $filePath');

      // Open APK for installation
      final result = await OpenFilex.open(filePath);
      debugPrint('Open result: ${result.message}');

      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('Download/Install error: $e');
      return false;
    }
  }
}

/// Update information model
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final List<String> changelog;
  final bool forceUpdate;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.changelog,
    required this.forceUpdate,
  });
}
