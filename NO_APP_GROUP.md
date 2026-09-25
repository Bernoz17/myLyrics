# Free iOS widget architecture

This version intentionally does not use an Apple App Group. The widget is self-contained:
- it bundles `assets/frasi.json` as `ios/FrasiWidget/frasi.json`;
- it calculates the same local-day phrase index as the Flutter Home screen;
- widget style (background, text color, font) is configured per widget through iOS `Modifica widget` using WidgetKit App Intents.

This avoids the paid Apple Developer App Group capability. The trade-off is that changes to the database made inside the Flutter app are not mirrored into the widget; the shared source for the daily phrase is the bundled JSON.
