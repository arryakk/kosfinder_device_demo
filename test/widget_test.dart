// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:kosfinder_device_demo/main.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('KosFinderDeviceApp smoke test renders title and controls',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KosFinderDeviceApp());
    await tester.pumpAndSettle();

    // Verifikasi bahwa title bar aplikasi tampil
    expect(find.text('KosFinder - Device Demo'), findsOneWidget);

    // Verifikasi form input dan tombol aksi utama
    expect(find.text('Nama kos (contoh: Kos Melati)'), findsOneWidget);
    expect(find.text('Kamera'), findsOneWidget);
    expect(find.text('Galeri'), findsOneWidget);
    expect(find.text('Ambil Koordinat GPS'), findsOneWidget);
    expect(find.text('Simpan Draft Lokal'), findsOneWidget);
  });
}
