import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud_config.dart';

/// Hasil unggah foto ke Supabase Storage.
class PhotoUploadResult {
  final String storagePath;
  final String publicUrl;

  const PhotoUploadResult(this.storagePath, this.publicUrl);
}

/// Service untuk mengunggah foto ke Supabase Storage.
class PhotoUploadService {
  final SupabaseClient? client;

  PhotoUploadService({this.client});

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  /// Mengunggah file foto ke Supabase Storage pada bucket 'kosfinder-demo'.
  Future<PhotoUploadResult> upload(File photo) async {
    if (!CloudConfig.enabled) {
      throw StateError('Integrasi Supabase belum dikonfigurasi.');
    }

    final ext = photo.path.split('.').last.toLowerCase();
    if (ext != 'jpg' && ext != 'jpeg' && ext != 'png') {
      throw const FormatException('Foto harus berupa JPG/JPEG/PNG.');
    }

    final length = await photo.length();
    if (length > 5 * 1024 * 1024) {
      throw const FormatException('Ukuran foto maksimal 5 MB.');
    }

    if (_supabase.auth.currentUser == null) {
      await _supabase.auth.signInAnonymously();
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Gagal melakukan autentikasi anonim ke Supabase.');
    }

    final storagePath =
        '$userId/${DateTime.now().microsecondsSinceEpoch}.$ext';

    await _supabase.storage.from('kosfinder-demo').upload(
          storagePath,
          photo,
          fileOptions: const FileOptions(upsert: false),
        );

    final publicUrl =
        _supabase.storage.from('kosfinder-demo').getPublicUrl(storagePath);

    return PhotoUploadResult(storagePath, publicUrl);
  }
}
