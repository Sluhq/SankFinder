import SwiftUI

struct SplashScreenView: View {
    @Binding var isPresented: Bool
    
    @State private var startAnimation = false
    @State private var pulse = false
    @State private var progressWidth: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            // Ozadje z enakim prelivom kot na Androidu (#0F172A -> #0B132B -> #060913)
            LinearGradient(
                colors: [
                    Color(red: 15/255, green: 23/255, blue: 42/255),
                    Color(red: 11/255, green: 19/255, blue: 43/255),
                    Color(red: 6/255, green: 9/255, blue: 19/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // Škatla z uradnim ŠankFinder PNG logotipom in pivskim sijem
                ZStack {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(Color(red: 16/255, green: 25/255, blue: 45/255))
                        .frame(width: 150, height: 150)
                        .shadow(color: Color.beerGold.opacity(0.35), radius: 28, x: 0, y: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 36, style: .continuous)
                                .stroke(Color.beerGold.opacity(0.25), lineWidth: 1.5)
                        )
                    
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                }
                .scaleEffect(pulse ? 1.03 : 0.98)
                .opacity(startAnimation ? 1.0 : 0.0)
                
                VStack(spacing: 8) {
                    Text("ŠankFinder")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Poišči najboljše šanke v bližini")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(red: 148/255, green: 163/255, blue: 184/255))
                }
                .opacity(startAnimation ? 1.0 : 0.0)
                
                Spacer().frame(height: 12)
                
                // Eleganten vrstični indikator nalaganja
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 170, height: 4)
                    
                    Capsule()
                        .fill(LinearGradient(colors: [Color.beerGold, Color(red: 255/255, green: 213/255, blue: 79/255)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: progressWidth, height: 4)
                }
                .opacity(startAnimation ? 1.0 : 0.0)
            }
            .padding(.horizontal, 32)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.35)) {
                isPresented = false
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                startAnimation = true
            }
            withAnimation(Animation.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 0.95)) {
                progressWidth = 170
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    isPresented = false
                }
            }
        }
    }
}
