import WidgetKit
import SwiftUI

struct WidgetState: Codable {
    let phrase_id: Int
    let hour_key: String
    let testo: String
    let titolo: String
    let artista: String
    let bg_color: String
    let text_color: String
    let font_style: String
    let updated_at: String?
}

struct PhraseRecord: Codable {
    let testo: String
    let titolo: String
    let artista: String
}

struct HourPhrase {
    let testo: String
    let titolo: String
    let artista: String
    let phraseId: Int
    let hourKey: String
}

enum SupabaseWidgetClient {
    static let cacheKey = "mylyrics_widget_state_cache_v1"

    static var baseURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String ?? "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static var publishableKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String ?? ""
    }

    static func currentHourKey(_ date: Date = Date()) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour],
            from: date
        )

        return String(
            format: "%04d-%02d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            components.hour ?? 0
        )
    }

    static func hourlyPhrase(for hourKey: String) -> PhraseRecord? {
        guard
            let url = Bundle.main.url(forResource: "frasi", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let phrases = try? JSONDecoder().decode([PhraseRecord].self, from: data),
            !phrases.isEmpty
        else {
            return nil
        }

        // FNV-1a 32-bit; same algorithm used by Dart.
        var hash: UInt32 = 2_166_136_261
        for byte in Data("\(hourKey)-myLyrics".utf8) {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }

        return phrases[Int(hash % UInt32(phrases.count))]
    }

    static func nextHour(after date: Date) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let hourStart = calendar.date(
            bySetting: .minute,
            value: 0,
            of: date
        ) ?? date

        let normalized = calendar.date(
            bySetting: .second,
            value: 0,
            of: hourStart
        ) ?? hourStart

        return calendar.date(
            byAdding: .hour,
            value: 1,
            to: normalized
        ) ?? date.addingTimeInterval(3600)
    }

    static func fetchState(completion: @escaping (WidgetState?) -> Void) {
        guard
            let url = URL(string:
                "\(baseURL)/rest/v1/mylyrics_widget_state" +
                "?select=phrase_id,hour_key,testo,titolo,artista,bg_color,text_color,font_style,updated_at" +
                "&id=eq.1&limit=1"
            ),
            !baseURL.isEmpty,
            !publishableKey.isEmpty
        else {
            completion(loadCachedState())
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard
                let data,
                let http = response as? HTTPURLResponse,
                200..<300 ~= http.statusCode,
                let rows = try? JSONDecoder().decode([WidgetState].self, from: data),
                let state = rows.first
            else {
                completion(loadCachedState())
                return
            }

            saveCachedState(state)
            completion(state)
        }.resume()
    }

    static func saveCachedState(_ state: WidgetState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    static func loadCachedState() -> WidgetState? {
        guard
            let data = UserDefaults.standard.data(forKey: cacheKey),
            let state = try? JSONDecoder().decode(WidgetState.self, from: data)
        else {
            return nil
        }

        return state
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let testo: String
    let dettagli: String
    let bgColor: String
    let textColor: String
    let fontStyle: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            testo: "La tua frase apparirà qui.",
            dettagli: "myLyrics",
            bgColor: "000000",
            textColor: "FFFFFF",
            fontStyle: "default"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        SupabaseWidgetClient.fetchState { state in
            let now = Date()
            let currentHour = SupabaseWidgetClient.currentHourKey(now)
            let styleBg = state?.bg_color ?? "000000"
            let styleText = state?.text_color ?? "FFFFFF"
            let styleFont = state?.font_style ?? "default"

            var entries: [SimpleEntry] = []

            // Current hour: honor a manual phrase selected by the app if it belongs
            // to the current hour; otherwise use the same pseudo-random hourly phrase
            // used by Flutter.
            if let state, state.hour_key == currentHour {
                let details = [state.titolo, state.artista]
                    .filter { !$0.isEmpty }
                    .joined(separator: " - ")

                entries.append(
                    SimpleEntry(
                        date: now,
                        testo: state.testo,
                        dettagli: details,
                        bgColor: styleBg,
                        textColor: styleText,
                        fontStyle: styleFont
                    )
                )
            } else if let phrase = SupabaseWidgetClient.hourlyPhrase(for: currentHour) {
                entries.append(
                    SimpleEntry(
                        date: now,
                        testo: phrase.testo,
                        dettagli: [phrase.titolo, phrase.artista]
                            .filter { !$0.isEmpty }
                            .joined(separator: " - "),
                        bgColor: styleBg,
                        textColor: styleText,
                        fontStyle: styleFont
                    )
                )
            } else {
                entries.append(
                    SimpleEntry(
                        date: now,
                        testo: "Apri myLyrics per iniziare.",
                        dettagli: "",
                        bgColor: styleBg,
                        textColor: styleText,
                        fontStyle: styleFont
                    )
                )
            }

            // Precompute the next six hourly phrases so the widget can change
            // independently even when the main app is closed.
            for offset in 1...6 {
                let entryDate = Calendar.autoupdatingCurrent.date(
                    byAdding: .hour,
                    value: offset,
                    to: SupabaseWidgetClient.nextHour(after: now)
                ) ?? now.addingTimeInterval(Double(offset) * 3600)

                let hourKey = SupabaseWidgetClient.currentHourKey(entryDate)

                if let phrase = SupabaseWidgetClient.hourlyPhrase(for: hourKey) {
                    entries.append(
                        SimpleEntry(
                            date: entryDate,
                            testo: phrase.testo,
                            dettagli: [phrase.titolo, phrase.artista]
                                .filter { !$0.isEmpty }
                                .joined(separator: " - "),
                            bgColor: styleBg,
                            textColor: styleText,
                            fontStyle: styleFont
                        )
                    )
                }
            }

            completion(
                Timeline(
                    entries: entries,
                    policy: .after(
                        Calendar.autoupdatingCurrent.date(
                            byAdding: .hour,
                            value: 1,
                            to: SupabaseWidgetClient.nextHour(after: now)
                        ) ?? now.addingTimeInterval(7200)
                    )
                )
            )
        }
    }
}

extension Color {
    init(hex: String) {
        if hex == "transparent" {
            self = Color.clear
            return
        }

        var int: UInt64 = 0
        Scanner(
            string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        ).scanHexInt64(&int)

        self.init(
            .sRGB,
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255,
            opacity: 1
        )
    }
}

struct FrasiWidgetEntryView: View {
    let entry: Provider.Entry

    @Environment(\.widgetFamily) private var family

    private var fontDesign: Font.Design {
        switch entry.fontStyle {
        case "serif": return .serif
        case "monospaced": return .monospaced
        case "rounded": return .rounded
        default: return .default
        }
    }

    @ViewBuilder
    private func quoteText(baseSize: CGFloat) -> some View {
        Text(entry.testo)
            .font(.system(size: baseSize, weight: .semibold, design: fontDesign))
            .foregroundStyle(Color(hex: entry.textColor))
            .multilineTextAlignment(.center)
            .lineSpacing(-0.5)
            .allowsTightening(true)
            .minimumScaleFactor(0.35)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func adaptiveQuote() -> some View {
        // ViewThatFits chooses the largest text size whose full multiline content
        // fits the available vertical space; none of these variants truncates the quote.
        ViewThatFits(in: .vertical) {
            quoteText(baseSize: 18)
            quoteText(baseSize: 16)
            quoteText(baseSize: 14)
            quoteText(baseSize: 12)
            quoteText(baseSize: 10)
            quoteText(baseSize: 8)
        }
    }

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                // The Lock Screen rectangular family has very limited space.
                // Prioritize the complete quote over metadata.
                ViewThatFits(in: .vertical) {
                    quoteText(baseSize: 14)
                    quoteText(baseSize: 12)
                    quoteText(baseSize: 10)
                    quoteText(baseSize: 8)
                }
                .padding(4)
            } else {
                ViewThatFits(in: .vertical) {
                    VStack(alignment: .center, spacing: 6) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Color(hex: entry.textColor).opacity(0.45))

                        adaptiveQuote()

                        if !entry.dettagli.isEmpty {
                            Capsule()
                                .fill(Color(hex: entry.textColor).opacity(0.35))
                                .frame(width: 22, height: 1.5)

                            Text(entry.dettagli)
                                .font(.system(size: 11, weight: .medium, design: fontDesign))
                                .italic()
                                .foregroundStyle(Color(hex: entry.textColor).opacity(0.75))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                    .padding(10)

                    VStack(spacing: 5) {
                        adaptiveQuote()
                    }
                    .padding(8)

                    adaptiveQuote()
                        .padding(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            if entry.bgColor == "transparent" {
                // No material/blur here: on the Home Screen a material renders as an
                // opaque grey plate. Color.clear lets iOS show its own glass look when
                // the Home Screen is set to "Clear"/"Tinted".
                Color.clear
            } else {
                atmosphereBackground
            }
        }
    }

    // Solid background with a soft light-to-shadow gradient for some depth.
    private var atmosphereBackground: some View {
        ZStack {
            Color(hex: entry.bgColor)
            LinearGradient(
                colors: [Color.white.opacity(0.10), Color.clear, Color.black.opacity(0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

@main
struct FrasiWidget: Widget {
    let kind = "FrasiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            FrasiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Le Mie Barre")
        .description("Mostra la frase e lo stile salvati in myLyrics.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
