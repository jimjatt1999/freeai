import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage
    let geo: GeometryProxy
    let animationTrigger: Bool
    let fadeInTrigger: Bool
    let isActive: Bool
    @State private var localAnimation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Animated Eyes
                AnimatedEyesView()
                    .scaleEffect(2.0)
                    .padding(.top, geo.size.height * 0.08)
                    .opacity(fadeInTrigger ? 1 : 0)
                    .scaleEffect(animationTrigger ? 1 : 0.8)
                    .offset(y: animationTrigger ? 0 : 30)
                    .padding(.bottom, 5)

                // --- Add Section Title --- 
                Text(page.title)
                     .font(.system(size: 28, weight: .bold, design: .rounded))
                     .foregroundStyle(.primary)
                     .scaleEffect(animationTrigger ? 1 : 0.8)
                     .offset(y: animationTrigger ? 0 : 30)
                     .opacity(fadeInTrigger ? 1 : 0)
                     .padding(.bottom, 15)
                // --- End Section Title ---
                
                // Features grid 
                VStack(alignment: .leading, spacing: 6) {
                    Text("FEATURES")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                        .padding(.bottom, 4)
                        .opacity(fadeInTrigger ? 1 : 0)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10, alignment: .top),
                        GridItem(.flexible(), spacing: 10, alignment: .top)
                    ], spacing: 10) {
                        ForEach(page.features) { feature in
                            FeatureCard(
                                icon: feature.icon,
                                title: feature.title,
                                description: feature.description,
                                delay: isActive ? (localAnimation ? 0.1 : 0.1 * Double(page.features.firstIndex(where: { $0.id == feature.id }) ?? 0)) : 0
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .offset(y: fadeInTrigger ? 0 : 40)
                .opacity(fadeInTrigger ? 1 : 0)
                
                // Add bottom padding
                Spacer(minLength: 150)
            }
            .frame(minHeight: geo.size.height - 150)
        }
        .scrollDisabled(true)
        .onAppear {
            localAnimation = true
        }
        .onDisappear {
            localAnimation = false
        }
    }
}

// Include FeatureCard struct if it's defined here, otherwise ensure it's accessible
// Assuming FeatureCard is defined elsewhere or in another part of the file

/* Preview might need adjustment if OnboardingPage requires specific setup
 #Preview {
 OnboardingPageView(page: /* provide a sample page */, geo: /* provide geometry */, animationTrigger: true, fadeInTrigger: true, isActive: true)
 }
 */ 