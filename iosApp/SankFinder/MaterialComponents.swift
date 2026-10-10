import SwiftUI

// MARK: - 1. Material 3 CenterAlignedTopAppBar (identičen Androidu)
struct MaterialTopAppBar<Actions: View>: View {
    let title: String
    var showBackButton: Bool = false
    var onBack: (() -> Void)? = nil
    @ViewBuilder var actions: () -> Actions
    
    init(title: String, showBackButton: Bool = false, onBack: (() -> Void)? = nil, @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }) {
        self.title = title
        self.showBackButton = showBackButton
        self.onBack = onBack
        self.actions = actions
    }
    
    var body: some View {
        HStack {
            if showBackButton {
                Button(action: { onBack?() }) {
                    Image(systemName: "arrow.left")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                }
            } else {
                Spacer().frame(width: 38)
            }
            
            Spacer()
            
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            HStack(spacing: 8) {
                actions()
            }
            .frame(minWidth: 38, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.surfaceDark)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.white.opacity(0.1)),
            alignment: .bottom
        )
    }
}

// MARK: - 2. Material 3 BottomNavBar (identičen Android BottomNavigation.kt)
struct MaterialBottomNavBar: View {
    @Binding var selectedIndex: Int
    
    struct NavItem {
        let label: String
        let icon: String
        let index: Int
    }
    
    let items = [
        NavItem(label: "Šanki", icon: "list.bullet", index: 0),
        NavItem(label: "Orodja", icon: "wrench.and.screwdriver.fill", index: 1),
        NavItem(label: "Zemljevid", icon: "map.fill", index: 2),
        NavItem(label: "Zgodovina", icon: "clock.arrow.circlepath", index: 3),
        NavItem(label: "Nastavitve", icon: "gearshape.fill", index: 4)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Zgornja tanka ločilna črta (0.5 pt kot v Compose)
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 0.5)
            
            HStack(spacing: 0) {
                ForEach(items, id: \.index) { item in
                    let isCenter = item.index == 2
                    let isSelected = selectedIndex == item.index
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedIndex = item.index
                        }
                    }) {
                        VStack(spacing: 3) {
                            if isCenter {
                                // Osrednji 38dp krog z zlato obrobo kot v Androidu
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? Theme.beerGold.opacity(0.22) : Theme.surfaceVariantDark.opacity(0.5))
                                        .frame(width: 38, height: 38)
                                    
                                    Circle()
                                        .stroke(isSelected ? Theme.beerGold : Color.white.opacity(0.3), lineWidth: isSelected ? 1.5 : 1.0)
                                        .frame(width: 38, height: 38)
                                    
                                    Image(systemName: item.icon)
                                        .font(.system(size: 19))
                                        .foregroundColor(isSelected ? Theme.beerGold : Theme.textMuted)
                                }
                            } else {
                                // Standardni gumb z Material 3 tabletko
                                ZStack {
                                    if isSelected {
                                        Capsule()
                                            .fill(Theme.beerGold.opacity(0.18))
                                            .frame(width: 48, height: 28)
                                    }
                                    
                                    Image(systemName: item.icon)
                                        .font(.system(size: 19))
                                        .foregroundColor(isSelected ? Theme.beerGold : Theme.textMuted)
                                }
                                .frame(height: 28)
                            }
                            
                            Text(item.label)
                                .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                                .foregroundColor(isSelected ? (isCenter ? Theme.beerGold : Theme.beerGold) : Theme.textMuted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding(.bottom, 12) // Safe area padding
            .background(Theme.surfaceDark)
        }
        .clipShape(CustomRoundedCorner(radius: 18, corners: [.topLeft, .topRight]))
        .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: -4)
    }
}

// MARK: - 3. Material 3 OutlinedTextField (Iskalnik lokalov)
struct MaterialOutlinedTextField: View {
    @Binding var text: String
    var placeholder: String = "Išči lokal ali ulico..."
    var onClear: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.beerGold)
                .font(.system(size: 16))
            
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
                .font(.system(size: 15))
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onClear?()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textMuted)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Theme.surfaceDark)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(text.isEmpty ? Theme.outlineDark : Theme.beerGold, lineWidth: 1)
        )
    }
}

// MARK: - 4. Material 3 FilterChip
struct MaterialFilterChip: View {
    let title: String
    let isSelected: Bool
    let onClick: () -> Void
    
    var body: some View {
        Button(action: onClick) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Theme.beerGold : Theme.surfaceVariantDark.opacity(0.6))
                .foregroundColor(isSelected ? .black : .white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Theme.beerGold : Theme.outlineDark, lineWidth: 1)
                )
        }
    }
}

// MARK: - 5. Pomožna oblika za ukrivljene zgornje robove
struct CustomRoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
