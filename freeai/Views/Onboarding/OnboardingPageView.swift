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
            VStack(spacing: 30) {
                // --- Display Animated Eyes instead of Title/Subtitle --- 
                AnimatedEyesView()
                    .scaleEffect(2.5) // Make eyes larger for onboarding
                    .padding(.top, geo.size.height * 0.1) // Adjust vertical position
                    .opacity(fadeInTrigger ? 1 : 0)
                    .scaleEffect(animationTrigger ? 1 : 0.8)
                    .offset(y: animationTrigger ? 0 : 30)
                    .padding(.bottom, 10) // Add some space below eyes

                // --- Commented Out Original Title/Subtitle ---
                /*
                 Text(page.title)
                 .font(.largeTitle.bold())
                 .scaleEffect(animationTrigger ? 1 : 0.8)
                 .offset(y: animationTrigger ? 0 : 30)
                 .opacity(fadeInTrigger ? 1 : 0)
                 
                 Text(page.subtitle)
                 .font(.title3)
                 .multilineTextAlignment(.center)
                 .foregroundStyle(.secondary)
                 .padding(.horizontal, 40)
                 .scaleEffect(animationTrigger ? 1 : 0.9)
                 .offset(y: animationTrigger ? 0 : 30)
                 .opacity(fadeInTrigger ? 1 : 0)
                 */
                // --- End Original ---
                
                // Features grid 
                VStack(alignment: .leading, spacing: 8) {
                    Text("FEATURES")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                        .padding(.bottom, 4)
                        .opacity(fadeInTrigger ? 1 : 0)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12, alignment: .top),
                        GridItem(.flexible(), spacing: 12, alignment: .top)
                    ], spacing: 12) {
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
                
                // Add bottom padding to ensure content doesn't overlap with controls
                Spacer(minLength: 150)
            }
            .frame(minHeight: geo.size.height - 150) // Ensure content fills space
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