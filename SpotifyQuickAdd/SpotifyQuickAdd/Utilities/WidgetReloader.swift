import Foundation
import WidgetKit

enum WidgetReloader {
    static func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: SpotifyConfig.widgetKind)
    }
}
