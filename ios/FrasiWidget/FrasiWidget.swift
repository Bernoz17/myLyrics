import WidgetKit
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue:  Double(b) / 255, opacity: Double(a) / 255)
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
        SimpleEntry(date: Date(), testo: "Caricamento...", dettagli: "", bgColor: "000000", textColor: "FFFFFF", fontStyle: "default")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(SimpleEntry(date: Date(), testo: "La musica è l'unica magia che esiste.", dettagli: "Autore - Titolo", bgColor: "000000", textColor: "FFFFFF", fontStyle: "default"))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.it.bernoz.myLyrics")
        
        let testo = userDefaults?.string(forKey: "widget_testo") ?? "Nessuna frase estratta"
        let dettagli = userDefaults?.string(forKey: "widget_dettagli") ?? ""
        let bgColor = userDefaults?.string(forKey: "widget_bgColor") ?? "000000"
        let textColor = userDefaults?.string(forKey: "widget_textColor") ?? "FFFFFF"
        let fontStyle = userDefaults?.string(forKey: "widget_fontStyle") ?? "default"

        let entry = SimpleEntry(date: Date(), testo: testo, dettagli: dettagli, bgColor: bgColor, textColor: textColor, fontStyle: fontStyle)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct FrasiWidgetEntryView : View {
    var entry: Provider.Entry
    
    @Environment(\.widgetFamily) var family

    func getFontDesign() -> Font.Design {
        switch entry.fontStyle {
        case "serif": return .serif             
        case "monospaced": return .monospaced   
        case "rounded": return .rounded         
        default: return .default                
        }
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            Text(entry.testo)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(3)
                .multilineTextAlignment(.center)
        default:
                
        VStack(alignment: .center, spacing: 10) {
            Image(systemName: "quote.opening")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(Color(hex: entry.textColor).opacity(0.6))
            
            Text(entry.testo)
                .font(.system(size: 15, weight: .semibold, design: getFontDesign()))
                .foregroundColor(Color(hex: entry.textColor))
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
            
            Spacer()
            
            Text(entry.dettagli)
                .font(.system(size: 12, weight: .medium, design: getFontDesign()))
                .foregroundColor(Color(hex: entry.textColor).opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

extension View {
    func widgetBackground(bgColorHex: String) -> some View {
        let color = bgColorHex == "transparent" ? Color.clear : Color(hex: bgColorHex)
        if #available(iOS 17.0, *) {
            return containerBackground(color, for: .widget)
        } else {
            return background(color)
        }
    }
}

@main
struct FrasiWidget: Widget {
    let kind: String = "FrasiWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            FrasiWidgetEntryView(entry: entry)
                .widgetBackground(bgColorHex: entry.bgColor)
        }
        .configurationDisplayName("Le Mie Barre")
        .description("Il widget personalizzabile con le tue citazioni.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
