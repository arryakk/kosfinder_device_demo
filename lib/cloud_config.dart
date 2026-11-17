/// Konfigurasi integrasi Supabase Cloud opsional.
///
/// Nilai kredensial dioper via compile-time environment variables:
/// --dart-define=SUPABASE_URL=...
/// --dart-define=SUPABASE_PUBLISHABLE_KEY=...
class CloudConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Getter untuk mengecek apakah integrasi Supabase aktif.
  static bool get enabled => url.isNotEmpty && publishableKey.isNotEmpty;
}
