# Widget Fix v5

1. Changing the phrase no longer resets background, text color, or font:
   the app reads the current Supabase state first and carries the existing style
   values into the new phrase row.

2. Transparent background:
   - Lock Screen/accessory widget: `Color.clear`.
   - Home Screen: a subtle `.ultraThinMaterial` fallback instead of the opaque dark
     appearance.
   - When iOS renders the Home Screen in Clear/Tinted mode, WidgetKit can remove the
     background and supply its own themed glass presentation.
