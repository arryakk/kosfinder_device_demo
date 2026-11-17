import 'package:geolocator/geolocator.dart';

/// Jenis kegagalan saat mengakses layanan lokasi.
enum LocationFailureType { serviceDisabled, denied, deniedForever }

/// Exception khusus untuk kegagalan akses lokasi.
class LocationFailure implements Exception {
  final LocationFailureType type;
  final String message;

  const LocationFailure(this.type, this.message);

  @override
  String toString() => message;
}

/// Service untuk menangani izin dan pembacaan koordinat GPS perangkat.
class DeviceLocationService {
  /// Mengambil posisi terkini perangkat dengan penanganan izin yang aman.
  Future<Position> getPosition() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationFailure(
        LocationFailureType.serviceDisabled,
        'Layanan GPS/lokasi sedang tidak aktif. Harap aktifkan GPS perangkat Anda.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationFailure(
          LocationFailureType.denied,
          'Izin akses lokasi ditolak oleh pengguna.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        LocationFailureType.deniedForever,
        'Izin lokasi ditolak secara permanen. Buka pengaturan aplikasi untuk mengaktifkannya.',
      );
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }
}
