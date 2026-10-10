import SwiftUI

struct Theme {
    static let beerGold = Color(red: 255/255, green: 183/255, blue: 3/255) // #FFB703
    static let beerAmber = Color(red: 217/255, green: 119/255, blue: 6/255) // #D97706
    static let beerDark = Color(red: 180/255, green: 83/255, blue: 9/255) // #B45309
    
    static let bgDark = Color(red: 11/255, green: 15/255, blue: 25/255) // #0B0F19
    static let cardDark = Color(red: 22/255, green: 31/255, blue: 48/255) // #161F30
    static let surfaceDark = Color(red: 30/255, green: 41/255, blue: 59/255) // #1E293B
    
    static let drajvGreen = Color(red: 5/255, green: 150/255, blue: 105/255) // #059669
    static let drajvRed = Color(red: 239/255, green: 68/255, blue: 68/255) // #EF4444
    static let textLight = Color(red: 248/255, green: 250/255, blue: 252/255)
    static let textMuted = Color(red: 148/255, green: 163/255, blue: 184/255)
}

extension Color {
    static let beerGold = Theme.beerGold
    static let beerAmber = Theme.beerAmber
    static let appBg = Theme.bgDark
    static let appCard = Theme.cardDark
    static let appSurface = Theme.surfaceDark
    static let appText = Theme.textLight
    static let appMuted = Theme.textMuted
}
