import SwiftUI
import WidgetKit

// SkuaWidgetBundle is the widget extension entry point.
@main
struct SkuaWidgetBundle: WidgetBundle {
    var body: some Widget {
        ForecastWidget()
        FlightPlanWidget()
    }
}
