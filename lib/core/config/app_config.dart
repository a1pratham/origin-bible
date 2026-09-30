/// Build-time configuration, injected with:
///   flutter run --dart-define-from-file=env/dev.json
///
/// Only PUBLIC values belong here (Supabase URL + anon key are designed to be
/// public; Row Level Security protects data). Service-role keys, Groq/Gemini
/// keys and R2 credentials must NEVER be in the app. They live only in the
/// backend/pipeline environment.
enum AppEnv { dev, prod }

class AppConfig {
  const AppConfig({
    required this.env,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.generationEnabled,
  });

  factory AppConfig.fromEnvironment() {
    const envName = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    const gen = String.fromEnvironment('GENERATION_ENABLED');
    return const AppConfig(
      env: envName == 'prod' ? AppEnv.prod : AppEnv.dev,
      supabaseUrl: url,
      supabaseAnonKey: key,
      generationEnabled: gen == 'true',
    );
  }

  final AppEnv env;
  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Master runtime switch for any on-demand generation (AI/TTS).
  /// Defaults to false: the app must work fully without generation.
  final bool generationEnabled;

  bool get hasBackend => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
