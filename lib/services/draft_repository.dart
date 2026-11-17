import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository untuk mengelola penyimpanan draft lokal dan file foto permanen.
class DraftRepository {
  static const String draftKey = 'kosfinder_device_demo_draft_v1';
  final SharedPreferencesAsync _prefs;

  DraftRepository({SharedPreferencesAsync? prefs})
      : _prefs = prefs ?? SharedPreferencesAsync();

  /// Menyimpan metadata draft dalam format JSON.
  Future<void> save(Map<String, dynamic> draft) async {
    await _prefs.setString(draftKey, jsonEncode(draft));
  }

  /// Memuat metadata draft dari penyimpanan lokal.
  Future<Map<String, dynamic>?> load() async {
    final raw = await _prefs.getString(draftKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Menghapus draft lokal.
  Future<void> clear() async {
    await _prefs.remove(draftKey);
  }

  /// Memvalidasi dan menyalin foto dari cache sementara ke direktori permanen aplikasi.
  Future<String> savePermanentPhoto(XFile selected) async {
    final fileName = selected.name;
    final dotIndex = fileName.lastIndexOf('.');
    final ext =
        dotIndex != -1 ? fileName.substring(dotIndex + 1).toLowerCase() : '';

    if (ext != 'jpg' && ext != 'jpeg' && ext != 'png') {
      throw const FormatException('Foto harus berupa JPG/JPEG/PNG.');
    }

    final fileSize = await selected.length();
    if (fileSize > 5 * 1024 * 1024) {
      throw const FormatException('Ukuran foto maksimal 5 MB.');
    }

    final Directory root = await getApplicationDocumentsDirectory();
    final Directory photosDir = Directory('${root.path}/kosfinder_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final String targetPath =
        '${photosDir.path}/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await selected.saveTo(targetPath);
    return targetPath;
  }
}

