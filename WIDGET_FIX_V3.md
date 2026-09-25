# Widget Fix v3

- Home and WidgetKit now use the same local calendar day -> UTC civil date algorithm.
- Home no longer pretends that it can synchronize a random phrase with the widget.
- Widget configuration remains AppIntent-based for per-widget style.
- Widget container background is explicitly removable.
- iOS accented/vibrant rendering is respected; custom text colors are used in full-color mode.
- Transparent/clear presentation follows iOS's current WidgetKit behavior.

The no-App-Group architecture cannot share arbitrary runtime state between the Flutter app
and the widget. Exact synchronization of a random Home selection would require a shared
container or another synchronized external data source.
