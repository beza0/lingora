/// Derleme zamanı ayarları (`--dart-define` veya `--dart-define-from-file=.env.json`).
/// Gizli anahtar yoktur: Supabase publishable/anon anahtarı istemciye açıktır, güvenlik RLS ile sağlanır.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const appleSignIn = bool.fromEnvironment('FEATURE_APPLE_SIGN_IN', defaultValue: false);

  /// E-posta doğrulama bağlantısının döneceği adres. Web'de sayfanın kendisi, mobilde derin bağlantı.
  static const authRedirect = String.fromEnvironment('AUTH_REDIRECT', defaultValue: 'com.beyzaacar.lingora://auth-callback');

  static bool get hasBackend => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
