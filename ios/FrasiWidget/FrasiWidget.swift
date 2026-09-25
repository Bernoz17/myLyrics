import WidgetKit
import SwiftUI

struct WidgetState: Codable {
    let phrase_id: Int
    let testo: String
    let titolo: String
    let artista: String
    let bg_color: String
    let text_color: String
    let font_style: String
    let updated_at: String?
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

    static func fetchState(completion: @escaping (WidgetState?) -> Void) {
        guard
            let url = URL(string:
                "\(baseURL)/rest/v1/mylyrics_widget_state" +
                "?select=phrase_id,testo,titolo,artista,bg_color,text_color,font_style,updated_at" +
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
                let data = data,
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
        completion(
            SimpleEntry(
                date: Date(),
                testo: "La tua frase apparirà qui.",
                dettagli: "myLyrics",
                bgColor: "000000",
                textColor: "FFFFFF",
                fontStyle: "default"
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        SupabaseWidgetClient.fetchState { state in
            let entry: SimpleEntry

            if let state {
                entry = SimpleEntry(
                    date: Date(),
                    testo: state.testo,
                    dettagli: [state.titolo, state.artista]
                        .filter { !$0.isEmpty }
                        .joined(separator: " - "),
                    bgColor: state.bg_color,
                    textColor: state.text_color,
                    fontStyle: state.font_style
                )
            } else {
                entry = SimpleEntry(
                    date: Date(),
                    testo: "Apri myLyrics per iniziare.",
                    dettagli: "",
                    bgColor: "000000",
                    textColor: "FFFFFF",
                    fontStyle: "default"
                )
            }

            let nextUpdate = Calendar.current.date(
                byAdding: .minute,
                value: 15,
                to: Date()
            ) ?? Date().addingTimeInterval(15 * 60)

            completion(
                Timeline(entries: [entry], policy: .after(nextUpdate))
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

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                Text(entry.testo)
                    .font(.system(size: 14, weight: .medium, design: fontDesign))
                    .foregroundStyle(Color(hex: entry.textColor))
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(6)
            } else {
                VStack(alignment: .center, spacing: 10) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Color(hex: entry.textColor).opacity(0.6))

                    Text(entry.testo)
                        .font(.system(size: 15, weight: .semibold, design: fontDesign))
                        .foregroundStyle(Color(hex: entry.textColor))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    Text(entry.dettagli)
                        .font(.system(size: 12, weight: .medium, design: fontDesign))
                        .foregroundStyle(Color(hex: entry.textColor).opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color(hex: entry.bgColor), for: .widget)
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
