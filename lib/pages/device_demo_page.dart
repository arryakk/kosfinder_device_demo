import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud_config.dart';
import '../services/device_location_service.dart';
import '../services/draft_repository.dart';
import '../services/photo_upload_service.dart';
import 'sensor_demo_page.dart';

/// Halaman demo integrasi fitur perangkat (Kamera/Galeri, GPS, Draft Lokal, & Cloud).
class DeviceDemoPage extends StatefulWidget {
  const DeviceDemoPage({super.key});

  @override
  State<DeviceDemoPage> createState() => _DeviceDemoPageState();
}

class _DeviceDemoPageState extends State<DeviceDemoPage> {
  final TextEditingController _nameController = TextEditingController();
  final DraftRepository _draftRepository = DraftRepository();
  final DeviceLocationService _locationService = DeviceLocationService();
  final PhotoUploadService _uploadService = PhotoUploadService();
  final ImagePicker _picker = ImagePicker();

  String? _photoPath;
  double? _latitude;
  double? _longitude;
  String? _storagePath;
  String? _publicUrl;

  bool _isLoadingGps = false;
  bool _isUploading = false;
  bool _isSavingDraft = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    // 1. Pulihkan data kamera yang terputus akibat proses OS Android di background
    await _checkLostData();
    // 2. Muat draft lokal otomatis jika ada
    await _loadDraft();
  }

  Future<void> _checkLostData() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty) return;
      if (response.file != null) {
        final savedPath =
            await _draftRepository.savePermanentPhoto(response.file!);
        if (mounted) {
          setState(() {
            _photoPath = savedPath;
          });
          _showSnackBar('Foto berhasil dipulihkan dari sesi sebelumnya.');
        }
      } else if (response.exception != null) {
        _showSnackBar(
            'Gagal memulihkan foto sebelumnya: ${response.exception?.message}');
      }
    } on FormatException catch (e) {
      _showSnackBar('Format foto tidak didukung: ${e.message}');
    } on PlatformException catch (e) {
      _showSnackBar('Gagal memulihkan foto: ${e.message ?? e.code}');
    } catch (e) {
      _showSnackBar('Kesalahan pemulihan data: $e');
    }
  }

  Future<void> _loadDraft() async {
    try {
      final draft = await _draftRepository.load();
      if (draft != null && mounted) {
        setState(() {
          _nameController.text = draft['name'] as String? ?? '';
          _photoPath = draft['photoPath'] as String?;
          _latitude = (draft['latitude'] as num?)?.toDouble();
          _longitude = (draft['longitude'] as num?)?.toDouble();
          _storagePath = draft['storagePath'] as String?;
          _publicUrl = draft['publicUrl'] as String?;
        });
        _showSnackBar('Draft lokal berhasil dimuat secara otomatis.');
      }
    } catch (e) {
      _showSnackBar('Gagal memuat draft lokal: $e');
    }
  }

  void _showSnackBar(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );

      if (picked == null) return;

      final permanentPath = await _draftRepository.savePermanentPhoto(picked);

      if (mounted) {
        setState(() {
          _photoPath = permanentPath;
          // Reset hasil upload cloud sebelumnya karena foto telah berganti
          _storagePath = null;
          _publicUrl = null;
        });
        _showSnackBar('Foto berhasil disimpan ke direktori permanen lokal.');
      }
    } on FormatException catch (e) {
      _showSnackBar(e.message);
    } on PlatformException catch (e) {
      _showSnackBar('Akses kamera/galeri gagal: ${e.message ?? e.code}');
    } catch (e) {
      _showSnackBar('Gagal mengambil foto: $e');
    }
  }

  Future<void> _fetchGpsCoordinates() async {
    setState(() => _isLoadingGps = true);
    try {
      final position = await _locationService.getPosition();
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
        _showSnackBar('Koordinat GPS berhasil diperbarui.');
      }
    } on LocationFailure catch (e) {
      if (e.type == LocationFailureType.serviceDisabled) {
        _showSnackBar(
          e.message,
          actionLabel: 'Pengaturan GPS',
          onAction: () => Geolocator.openLocationSettings(),
        );
      } else if (e.type == LocationFailureType.deniedForever) {
        _showSnackBar(
          e.message,
          actionLabel: 'Pengaturan Izin',
          onAction: () => Geolocator.openAppSettings(),
        );
      } else {
        _showSnackBar(e.message);
      }
    } on TimeoutException {
      _showSnackBar(
          'Waktu permintaan lokasi habis (timeout 20 detik). Coba lagi di tempat terbuka.');
    } on PlatformException catch (e) {
      _showSnackBar('Gagal membaca sensor lokasi: ${e.message ?? e.code}');
    } catch (e) {
      _showSnackBar('Terjadi kesalahan lokasi: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingGps = false);
      }
    }
  }

  Future<void> _saveDraftLocal() async {
    setState(() => _isSavingDraft = true);
    try {
      final draft = <String, dynamic>{
        'name': _nameController.text.trim(),
        'photoPath': _photoPath,
        'latitude': _latitude,
        'longitude': _longitude,
        'storagePath': _storagePath,
        'publicUrl': _publicUrl,
      };

      await _draftRepository.save(draft);
      _showSnackBar('Draft lokal berhasil disimpan.');
    } catch (e) {
      _showSnackBar('Gagal menyimpan draft lokal: $e');
    } finally {
      if (mounted) {
        setState(() => _isSavingDraft = false);
      }
    }
  }

  Future<void> _uploadPhotoCloud() async {
    if (!CloudConfig.enabled) {
      _showSnackBar('Supabase belum dikonfigurasi.');
      return;
    }
    if (_photoPath == null) {
      _showSnackBar('Pilih atau potret foto terlebih dahulu.');
      return;
    }

    setState(() => _isUploading = true);
    try {
      final file = File(_photoPath!);
      if (!await file.exists()) {
        _showSnackBar('File foto lokal tidak ditemukan pada perangkat.');
        return;
      }

      final result = await _uploadService.upload(file);
      if (mounted) {
        setState(() {
          _storagePath = result.storagePath;
          _publicUrl = result.publicUrl;
        });
        _showSnackBar('Foto berhasil diunggah ke Supabase Storage!');
      }
    } on FormatException catch (e) {
      _showSnackBar(e.message);
    } on StorageException catch (e) {
      _showSnackBar('Gagal Supabase Storage: ${e.message}');
    } on AuthException catch (e) {
      _showSnackBar('Gagal autentikasi Supabase: ${e.message}');
    } on PlatformException catch (e) {
      _showSnackBar('Kesalahan platform: ${e.message ?? e.code}');
    } on TimeoutException {
      _showSnackBar('Waktu unggah habis (timeout). Periksa jaringan Anda.');
    } catch (e) {
      _showSnackBar('Gagal mengunggah foto ke Cloud: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCloudActive = CloudConfig.enabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KosFinder - Device Demo'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.sensors),
            tooltip: 'Sensor Accelerometer',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SensorDemoPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode status banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isCloudActive
                    ? Colors.teal.shade50
                    : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCloudActive
                      ? Colors.teal.shade300
                      : Colors.amber.shade400,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCloudActive ? Icons.cloud_done : Icons.cloud_off,
                    color: isCloudActive
                        ? Colors.teal.shade800
                        : Colors.amber.shade900,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isCloudActive
                          ? 'Mode: lokal + Supabase (tanpa Worksheet 9)'
                          : 'Mode: lokal/offline (Supabase belum dikonfigurasi)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isCloudActive
                            ? Colors.teal.shade900
                            : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // TextField Nama Kos
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama kos (contoh: Kos Melati)',
                hintText: 'Masukkan nama kos...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home_work_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Bagian Foto
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Foto Kamar Kos',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_photoPath != null && File(_photoPath!).existsSync())
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_photoPath!),
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Belum ada foto yang dipilih',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Kamera'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galeri'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bagian Lokasi GPS
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Lokasi GPS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: theme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (_latitude != null && _longitude != null)
                                  ? 'Lat: ${_latitude!.toStringAsFixed(6)}\nLng: ${_longitude!.toStringAsFixed(6)}'
                                  : 'Koordinat belum diambil',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoadingGps ? null : _fetchGpsCoordinates,
                      icon: _isLoadingGps
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(
                        _isLoadingGps
                            ? 'Mencari Lokasi GPS...'
                            : 'Ambil Koordinat GPS',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Simpan Draft Lokal
            FilledButton.icon(
              onPressed: _isSavingDraft ? null : _saveDraftLocal,
              icon: _isSavingDraft
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _isSavingDraft
                    ? 'Menyimpan...'
                    : 'Simpan Draft Lokal',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Tombol Upload Foto ke Supabase
            OutlinedButton.icon(
              onPressed: (!isCloudActive || _photoPath == null || _isUploading)
                  ? null
                  : _uploadPhotoCloud,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                _isUploading
                    ? 'Mengunggah ke Supabase...'
                    : 'Upload Foto ke Supabase (opsional)',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            // Informasi Cloud Storage jika tersedia
            if (_storagePath != null || _publicUrl != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.teal, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Informasi Cloud Supabase Storage',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_storagePath != null) ...[
                        const Text(
                          'Storage Path:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SelectableText(
                          _storagePath!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (_publicUrl != null) ...[
                        const Text(
                          'Public URL:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SelectableText(
                          _publicUrl!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.teal.shade900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

