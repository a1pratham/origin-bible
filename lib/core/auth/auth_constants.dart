/// Deep link used by email confirmation, password reset and Google sign-in.
/// Must match android/app/src/main/AndroidManifest.xml and
/// Supabase > Authentication > URL Configuration > Redirect URLs.
const String kAuthScheme = 'com.originbible.app';
const String kAuthRedirectUrl = '$kAuthScheme://login-callback/';
