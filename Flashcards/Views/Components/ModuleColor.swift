import SwiftUI

/// The colours a module can be tagged with.
enum ModuleColor: String, CaseIterable, Identifiable {
    case blue, indigo, purple, pink, red, orange, yellow, green, mint, teal, brown, gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .brown: .brown
        case .gray: .gray
        }
    }
}

extension StudyModule {
    var moduleColor: ModuleColor {
        get { ModuleColor(rawValue: colorName) ?? .blue }
        set { colorName = newValue.rawValue }
    }

    var color: Color { moduleColor.color }
}
