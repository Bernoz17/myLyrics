import AppIntents
import WidgetKit
import SwiftUI

struct DailyPhrase: Codable {
    let testo: String
    let titolo: String
    let artista: String
}

enum WidgetBackground: String, AppEnum, CaseIterable {
    case nero
    case trasparente
    case grigio
    case bianco
    case verde

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Sfondo"
    static var caseDisplayRepresentations: [WidgetBackground: DisplayRepresentation] = [
        .nero: "Nero assoluto",
        .trasparente: "Senza sfondo / Clear di iOS",
        .grigio: "Grigio scuro",
        .bianco: "Bianco",
        .verde: "Verde acqua"
    ]

    var hex: String {
        switch self {
        case .nero: return "000000"
        case .trasparente: return "transparent"
        case .grigio: return "1C1C1E"
        case .bianco: return "FFFFFF"
        case .verde: return "00C49A"
        }
    }
}

enum WidgetTextColor: String, AppEnum, CaseIterable {
    case bianco
    case nero
    case verde
    case oro

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Colore testo"
    static var caseDisplayRepresentations: [WidgetTextColor: DisplayRepresentation] = [
        .bianco: "Bianco",
        .nero: "Nero",
        .verde: "Verde acqua acceso",
        .oro: "Giallo oro"
    ]

    var hex: String {
        switch self {
        case .bianco: return "FFFFFF"
        case .nero: return "000000"
        case .verde: return "1DE9B6"
        case .oro: return "FFD600"
        }
    }
}

enum WidgetFontStyle: String, AppEnum, CaseIterable {
    case standard
    case serif
    case monospaced
    case rounded

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Font"
    static var caseDisplayRepresentations: [WidgetFontStyle: DisplayRepresentation] = [
        .standard: "Standard iOS",
        .serif: "Elegante (Serif)",
        .monospaced: "Macchina da scrivere",
        .rounded: "Moderno arrotondato"
    ]

    var design: Font.Design {
        switch self {
        case .standard: return .default
        case .serif: return .serif
        case .monospaced: return .monospaced
        case .rounded: return .rounded
        }
    }
}

struct FrasiWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Personalizza widget"
    static var description = IntentDescription("Scegli lo stile del widget Le Mie Barre.")

    @Parameter(title: "Sfondo", default: .nero)
    var background: WidgetBackground

    @Parameter(title: "Colore del testo", default: .bianco)
    var textColor: WidgetTextColor

    @Parameter(title: "Font", default: .standard)
    var fontStyle: WidgetFontStyle
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let testo: String
    let dettagli: String
    let bgColor: String
    let textColor: String
    let fontStyle: WidgetFontStyle
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            testo: "La musica è l'unica magia che esiste.",
            dettagli: "Le Mie Barre",
            bgColor: WidgetBackground.nero.hex,
            textColor: WidgetTextColor.bianco.hex,
            fontStyle: .standard
        )
    }

    func snapshot(for configuration: FrasiWidgetIntent, in context: Context) async -> SimpleEntry {
        makeEntry(for: Date(), configuration: configuration)
    }

    func timeline(for configuration: FrasiWidgetIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let now = Date()
        let today = makeEntry(for: now, configuration: configuration)

        let calendar = Calendar.current
        let nextMidnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTimePreservingSmallerComponents) ?? now.addingTimeInterval(24 * 60 * 60)
        let tomorrowDate = calendar.date(byAdding: .minute, value: 1, to: nextMidnight) ?? now.addingTimeInterval(24 * 60 * 60)
        let tomorrow = makeEntry(for: tomorrowDate, configuration: configuration)

        return Timeline(entries: [today, tomorrow], policy: .after(tomorrowDate))
    }

    private func makeEntry(for date: Date, configuration: FrasiWidgetIntent) -> SimpleEntry {
        let phrase = dailyPhrase(for: date) ?? DailyPhrase(
            testo: "Nessuna frase disponibile",
            titolo: "",
            artista: ""
        )

        return SimpleEntry(
            date: date,
            testo: phrase.testo,
            dettagli: [phrase.titolo, phrase.artista].filter { !$0.isEmpty }.joined(separator: " - "),
            bgColor: configuration.background.hex,
            textColor: configuration.textColor.hex,
            fontStyle: configuration.fontStyle
        )
    }

    private func dailyPhrase(for date: Date) -> DailyPhrase? {
        guard let url = Bundle.main.url(forResource: "frasi", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let phrases = try? JSONDecoder().decode([DailyPhrase].self, from: data),
              !phrases.isEmpty else {
            return nil
        }

        // Use the device's local year/month/day, then turn that civil date
        // into a UTC date for the day-number calculation. This matches Flutter
        // and avoids daylight-saving-time duration differences.
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = .autoupdatingCurrent

        let components = localCalendar.dateComponents([.year, .month, .day], from: date)

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        guard let localDayAsUTC = utcCalendar.date(from: components),
              let epochUTC = utcCalendar.date(from: DateComponents(year: 1970, month: 1, day: 1)) else {
            return nil
        }

        let days = utcCalendar.dateComponents([.day], from: epochUTC, to: localDayAsUTC).day ?? 0
        let index = ((days % phrases.count) + phrases.count) % phrases.count
        return phrases[index]
    }
}

extension Color {
    init(hex: String) {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }
}

struct FrasiWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var effectiveTextColor: Color {
        switch renderingMode {
        case .fullColor:
            return Color(hex: entry.textColor)
        case .accented, .vibrant:
            // iOS can override widget colors in these rendering modes.
            return .white
        @unknown default:
            return Color(hex: entry.textColor)
        }
    }

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                Text(entry.testo)
                    .font(.system(size: 14, weight: .medium, design: entry.fontStyle.design))
                    .foregroundStyle(effectiveTextColor)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(6)
            } else {
                VStack(alignment: .center, spacing: 10) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(effectiveTextColor.opacity(0.6))

                    Text(entry.testo)
                        .font(.system(size: 15, weight: .semibold, design: entry.fontStyle.design))
                        .foregroundStyle(effectiveTextColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    Text(entry.dettagli)
                        .font(.system(size: 12, weight: .medium, design: entry.fontStyle.design))
                        .foregroundStyle(effectiveTextColor.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(
            entry.bgColor == "transparent" ? Color.clear : Color(hex: entry.bgColor),
            for: .widget
        )
    }
}

@main
struct FrasiWidget: Widget {
    let kind = "FrasiWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: FrasiWidgetIntent.self,
            provider: Provider()
        ) { entry in
            FrasiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Le Mie Barre")
        .description("Mostra la frase del giorno e permette di scegliere aspetto e font.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
        .containerBackgroundRemovable(true)
    }
}
