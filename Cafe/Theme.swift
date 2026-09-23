import SwiftUI

enum CafeTheme {
    static let espresso = Color(red: 0.17, green: 0.08, blue: 0.035)
    static let coffee = Color(red: 0.40, green: 0.22, blue: 0.10)
    static let coffeeHighlight = Color(red: 0.72, green: 0.50, blue: 0.28)
    static let foam = Color(red: 0.93, green: 0.86, blue: 0.74)
    static let ceramic = Color(red: 0.95, green: 0.93, blue: 0.90)
    static let ceramicShadow = Color(red: 0.62, green: 0.56, blue: 0.50)
    static let atmosphereTop = Color(red: 0.11, green: 0.10, blue: 0.09)
    static let atmosphereBottom = Color(red: 0.04, green: 0.035, blue: 0.03)
    static let glow = Color(red: 0.78, green: 0.52, blue: 0.24)
    static let ink = Color(red: 0.93, green: 0.91, blue: 0.88)
    static let inkMuted = Color.white.opacity(0.42)
    static let stop = Color(red: 0.72, green: 0.28, blue: 0.22)
}

extension Notification.Name {
    static let cafeOpenMainWindow = Notification.Name("cafeOpenMainWindow")
}
