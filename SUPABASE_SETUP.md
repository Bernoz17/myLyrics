# Setup Supabase for myLyrics

1. Run `supabase_schema.sql` in the Supabase SQL Editor.
2. In Codemagic -> Environment variables add:
   SUPABASE_URL = https://YOUR_PROJECT.supabase.co
   SUPABASE_PUBLISHABLE_KEY = your publishable/anon client key
3. Run the workflow.

The app selects a random phrase from its local SQLite DB and saves the phrase
and current widget style in the single Supabase row `id = 1`.

The widget reads the same row over HTTPS. When the app changes the phrase or
style it asks WidgetCenter to reload all widget timelines. The widget also
refreshes on its timeline schedule and caches the last successful state.

Use only the publishable/anon key in client apps. Never put a `service_role`
or secret key in the Flutter/iOS project.

The SQL policy deliberately limits anonymous access to this one row. Because
the app is client-only, anyone who extracts the public key could still modify
this one row; this is suitable for a personal app but is not a multi-user
security boundary.


## Behavior updates
- Pressing "Aggiorna la frase" first reads the current Supabase row and then replaces only the phrase fields, so the selected widget style is preserved.
- The "Trasparente / Clear" choice uses clear rendering for the Lock Screen accessory widget and a subtle ultra-thin material on Home Screen. In iOS Clear/Tinted mode, WidgetKit may remove the container and apply its own system glass effect.
