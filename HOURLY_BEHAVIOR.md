# myLyrics — hourly phrase behavior

- A new phrase is selected for every local hour.
- Automatic hourly selection is deterministic pseudo-random (FNV-1a 32-bit), so
  Flutter and WidgetKit always derive the same phrase for the same local hour.
- The Home "Aggiorna la frase" button still chooses a genuinely random phrase,
  but only for the current hour.
- Changing the phrase preserves the current widget style.
- At the next hour, the scheduled widget timeline moves to the next hourly phrase.
- WidgetKit may delay a refresh because iOS controls widget scheduling. The widget
  therefore precomputes six future hourly entries.
- Long quotes use `ViewThatFits` with progressively smaller font sizes and no hard
  line truncation in the quote view. The Lock Screen rectangular widget prioritizes
  the quote over author metadata because its available space is much smaller.
- Home Screen transparent remains a subtle material fallback in normal mode; the
  system may apply its own Clear/Tinted rendering.
