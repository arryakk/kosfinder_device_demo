// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kosfinder_device_demo/cloud_config.dart';
import 'package:kosfinder_device_demo/services/device_location_service.dart';
import 'package:kosfinder_device_demo/services/draft_repository.dart';
import 'package:kosfinder_device_demo/services/photo_upload_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  group('CloudConfig Tests', () {
    test('default environment returns empty strings and enabled is false', () {
      expect(CloudConfig.url, isEmpty);
      expect(CloudConfig.publishableKey, isEmpty);
      expect(CloudConfig.enabled, isFalse);
    });
  });

  group('DraftRepository Validation Tests', () {
    late DraftRepository repo;

    setUp(() {
      repo = DraftRepository();
    });

    test('throws FormatException for invalid file extension (e.g. .pdf)',
        () async {
      final dummyFile = XFile('test.pdf');
      expect(
        () => repo.savePermanentPhoto(dummyFile),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          'Foto harus berupa JPG/JPEG/PNG.',
        )),
      );
    });

    test('throws FormatException for invalid file extension (e.g. .txt)',
        () async {
      final dummyFile = XFile('notes.txt');
      expect(
        () => repo.savePermanentPhoto(dummyFile),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          'Foto harus berupa JPG/JPEG/PNG.',
        )),
      );
    });

    test('save and load draft correctly via SharedPreferencesAsync', () async {
      final sampleDraft = {
        'name': 'Kos Mawar Indah',
        'photoPath': '/path/to/photo.jpg',
        'latitude': -7.7956,
        'longitude': 110.3695,
        'storagePath': 'user1/123.jpg',
        'publicUrl': 'https://storage/123.jpg',
      };
      await repo.save(sampleDraft);
      final loaded = await repo.load();
      expect(loaded, isNotNull);
      expect(loaded!['name'], 'Kos Mawar Indah');
      expect(loaded['latitude'], -7.7956);
      expect(loaded['longitude'], 110.3695);
    });
  });

  group('DeviceLocationService & Failure Tests', () {
    test('LocationFailure stores correct type and message', () {
      const failure = LocationFailure(
        LocationFailureType.serviceDisabled,
        'GPS mati',
      );
      expect(failure.type, LocationFailureType.serviceDisabled);
      expect(failure.message, 'GPS mati');
      expect(failure.toString(), 'GPS mati');
    });

    test('LocationFailureType enum contains all required states', () {
      expect(LocationFailureType.values, contains(LocationFailureType.serviceDisabled));
      expect(LocationFailureType.values, contains(LocationFailureType.denied));
      expect(LocationFailureType.values, contains(LocationFailureType.deniedForever));
    });
  });

  group('PhotoUploadService Result Model Tests', () {
    test('PhotoUploadResult holds storagePath and publicUrl properly', () {
      const result = PhotoUploadResult('user123/12345.jpg', 'https://example.com/photo.jpg');
      expect(result.storagePath, 'user123/12345.jpg');
      expect(result.publicUrl, 'https://example.com/photo.jpg');
    });
  });
}
