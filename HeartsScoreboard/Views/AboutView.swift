import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    private static let appStoreURL = URL(string: "https://apps.apple.com/app/idXXXXXXXXX")!

    private var backgroundColor: Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0.08, green: 0.18, blue: 0.12)
        default:
            return Color.green
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 28) {
                        Text("Developed by Christopher Rung")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        Text("Dedicated to my father, who loves Hearts, and has taught me to always shoot the moon.")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text("I would love to hear your feedback")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        Link("christopherrung.com", destination: URL(string: "https://christopherrung.com")!)
                            .font(.body.weight(.medium))
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 24)

                    Button("Rate on App Store") {
                        openURL(AboutView.appStoreURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Hearts Scoreboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AboutView()
}
