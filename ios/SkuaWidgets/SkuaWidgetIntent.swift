import AppIntents
import WidgetKit

// WidgetContent is what a configurable Skua widget shows, drawn from the same
// vocabulary as the in-app interface maker so the home screen matches the app.
enum WidgetContent: String, AppEnum {
    case conditions
    case flightPlan
    case lightning

    // typeDisplayRepresentation names the parameter in the widget editor.
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Content" }

    // caseDisplayRepresentations labels each choice with a title and a symbol.
    static var caseDisplayRepresentations: [WidgetContent: DisplayRepresentation] {
        [
            .conditions: DisplayRepresentation(
                title: "Conditions", image: .init(systemName: "thermometer.medium")),
            .flightPlan: DisplayRepresentation(
                title: "Flight plan", image: .init(systemName: "paperplane.fill")),
            .lightning: DisplayRepresentation(
                title: "Lightning", image: .init(systemName: "bolt.fill")),
        ]
    }
}

// SkuaWidgetIntent configures what a Skua widget shows. Long-press the widget on
// the home screen to switch its readout.
struct SkuaWidgetIntent: WidgetConfigurationIntent {
    // title names the configuration in the widget editor.
    static var title: LocalizedStringResource { "Skua" }
    // description explains the configuration in the widget editor.
    static var description: IntentDescription { IntentDescription("Pick what this widget shows.") }

    // content is the chosen readout.
    @Parameter(title: "Show", default: .conditions)
    var content: WidgetContent
}
