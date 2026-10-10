import SwiftUI

struct Theme {
    // ŠankFinder custom vibrant palette (identično Android Color.kt)
    static let beerGold = Color(hex: 0xFFFFB703)
    static let beerAmber = Color(hex: 0xFFFB8500)
    static let beerDarkAmber = Color(hex: 0xFFD97706)
    static let beerLiquidBottom = Color(hex: 0xFFB45309)
    static let beerFoamWhite = Color(hex: 0xFFFFFDF5)
    static let beerFoamBubble = Color(hex: 0xFFFEF3C7)
    
    // DRAJV statusne barve
    static let drajvGreen = Color(hex: 0xFF22C55E)
    static let drajvRed = Color(hex: 0xFFEF4444)
    
    // Material 3 Dark površine (identično Android Color.kt)
    static let bgDark = Color(hex: 0xFF0B0F17)             // backgroundDark
    static let surfaceDark = Color(hex: 0xFF111827)        // surfaceDark
    static let surfaceVariantDark = Color(hex: 0xFF1F2937) // surfaceVariantDark
    static let cardDark = Color(hex: 0xFF161F30)           // DarkCardSurface
    static let darkBorder = Color(hex: 0xFF2B3950)         // DarkBorder
    static let outlineDark = Color(hex: 0xFF374151)        // outlineDark
    
    // Besedilo in kontrasti
    static let textLight = Color(hex: 0xFFF1F5F9)          // onSurfaceDark
    static let textMuted = Color(hex: 0xFFCBD5E1)          // onSurfaceVariantDark
    static let primaryContainerDark = Color(hex: 0xFF3B2D1B)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
    
    static let beerGold = Theme.beerGold
    static let beerAmber = Theme.beerAmber
    static let beerDarkAmber = Theme.beerDarkAmber
    static let drajvGreen = Theme.drajvGreen
    static let drajvRed = Theme.drajvRed
    
    static let appBg = Theme.bgDark
    static let appSurface = Theme.surfaceDark
    static let appSurfaceVariant = Theme.surfaceVariantDark
    static let appCard = Theme.cardDark
    static let appBorder = Theme.darkBorder
    static let appText = Theme.textLight
    static let appMuted = Theme.textMuted
}
