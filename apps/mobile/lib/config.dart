/// Derleme zamanı ayarları (`--dart-define` veya `--dart-define-from-file=.env.json`).
/// Gizli anahtar yoktur: Supabase publishable/anon anahtarı istemciye açıktır, güvenlik RLS ile sağlanır.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const appleSignIn = bool.fromEnvironment('FEATURE_APPLE_SIGN_IN', defaultValue: false);

  /// E-posta doğrulama bağlantısının döneceği adres. Web'de sayfanın kendisi, mobilde derin bağlantı.
  static const authRedirect = String.fromEnvironment('AUTH_REDIRECT', defaultValue: 'com.beyzaacar.lingora://auth-callback');

  /// Uygulama sürümü (hata ve kullanım kayıtlarında).
  static const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.4.0');

  /// Web sürümü ve yasal metinlerin adresi.
  static const webBaseUrl = String.fromEnvironment('WEB_BASE_URL', defaultValue: 'https://lingora-beza0s-projects.vercel.app');

  static bool get hasBackend => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
