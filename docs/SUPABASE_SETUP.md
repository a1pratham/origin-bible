# Supabase setup (free plan only)

Do this once. Until you do, the app still works: Profile shows "Accounts are not available in this build". Nothing here needs a credit card.

## Free plan facts (checked against supabase.com pricing pages, 30 Sep 2026; re-check before launch)
- 2 active projects, 500 MB database, 50,000 monthly active users, 5 GB egress per month.
- **A free project is paused after 1 week of inactivity** and must be restored by hand from the dashboard. Origin Bible keeps working while it is paused (everything is local-first); sync resumes after you restore it.
- **Stay on the Free plan and do not add a payment method.** If an organization shows "Free" and has no card on file it cannot be billed. Never click upgrade. At the limits the project is restricted, and the app just keeps working locally.

## 1. Create the project
1. Sign up at supabase.com (email or GitHub).
2. New project: pick the **Free** organization, a name like `origin-bible`, a strong database password (store it in a password manager), and the region closest to your users (for India: Mumbai, `ap-south-1`, if offered).

## 2. Create the tables and security rules
1. Dashboard > **SQL Editor** > New query.
2. Paste the whole of `supabase/schema.sql` and press Run. It is safe to run twice.
3. Dashboard > **Table Editor** > `sync_items` should exist with the **RLS enabled** badge. If it says RLS disabled, stop and re-run the script.

## 3. Email sign-in
Dashboard > **Authentication**:
- **Providers > Email**: enabled, **Confirm email = ON**, minimum password length 8.
- **URL Configuration**: set **Site URL** to `com.originbible.app://login-callback/` and add the same value under **Redirect URLs**.
- The built-in email sender is meant for testing and is limited to a very small number of emails per hour. That is enough for you to test. Before a public launch, set up custom SMTP (Authentication > Emails > SMTP Settings) with a provider whose free tier you have checked, and read its terms.

## 4. Google sign-in (browser flow)
1. console.cloud.google.com > create or pick a project > **APIs & Services > OAuth consent screen**: External, app name "Origin Bible", your support email. Scopes: only `email`, `profile`, `openid` (these basic scopes should not need Google's app verification, but check Google's current rules). While the app is in *Testing* only the test users you list can sign in; switch to *In production* before release.
2. **Credentials > Create credentials > OAuth client ID > Web application**.
   - Authorized redirect URI: `https://<your-project-ref>.supabase.co/auth/v1/callback` (the project ref is in Supabase > Project Settings > General).
3. Copy the **Client ID** and **Client secret**.
4. Supabase > Authentication > **Providers > Google**: enable, paste both values, save.

No Android OAuth client or SHA-1 fingerprint is needed for this browser flow.

## 5. Put the public keys into the app
Supabase > **Project Settings > API**: copy the **Project URL** and the **anon / publishable** key into `env/dev.json`:
```json
{
  "APP_ENV": "dev",
  "SUPABASE_URL": "https://xxxx.supabase.co",
  "SUPABASE_ANON_KEY": "eyJ...",
  "GENERATION_ENABLED": "false"
}
```
The anon key is designed to be public; **Row Level Security protects the data**. **Never put the `service_role` or `secret` key in the app, in Git, or in any file in this project.** `env/dev.json` stays git-ignored.

## 6. Android changes (one time)
Edit `android/app/src/main/AndroidManifest.xml`:

1. Above `<application ...>` add (release builds have no internet without it):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```
2. Inside the existing `<activity android:name=".MainActivity" ...>` element add:
```xml
<meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="com.originbible.app" android:host="login-callback" />
</intent-filter>
```
(`android:launchMode="singleTop"` should already be on that activity.)

## 7. Add the package
```
flutter pub add supabase_flutter
flutter run --dart-define-from-file=env/dev.json
```

## 8. Test checklist
1. Profile > Sign in or create account > create an account with your email. Open the confirmation email **on the phone**; the link should return to the app. Then sign in.
2. Highlight a verse. Profile > **Sync now**. Supabase > Table Editor > `sync_items` shows the row.
3. Sign in on a second device or emulator with the same account: the highlight appears after a sync.
4. Turn on airplane mode, add a note, turn it off, tap Sync now: it uploads.
5. Try "Continue with Google" and "Forgot password?".
6. Profile > Delete account: the user disappears from Authentication > Users and the rows from `sync_items`.

## Troubleshooting
- "Could not reach the server": wrong URL/key in `env/dev.json`, no internet, or the project is paused (restore it in the dashboard).
- Confirmation or Google link opens the browser but not the app: check the intent filter and the Redirect URLs in step 3 match exactly.
- Nothing uploads but no error: check the `schema.sql` ran and RLS policies exist (Authentication > Policies).
