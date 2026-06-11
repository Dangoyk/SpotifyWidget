import SwiftUI
import WidgetKit

struct AddCurrentSongWidgetView: View {
    var body: some View {
        Link(destination: URL(string: SpotifyConfig.addSongDeepLink)!) {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                Text("Add Current Song")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
        .containerBackground(for: .widget) {
            Color(red: 0.11, green: 0.73, blue: 0.33)
        }
    }
}

struct SpotifyQuickAddWidget: Widget {
    let kind = "SpotifyQuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { _ in
            AddCurrentSongWidgetView()
        }
        .configurationDisplayName("Spotify Quick Add")
        .description("Add your currently playing Spotify song to a playlist.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(86400)))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}
