import SwiftUI
import UIKit

/// Pushed from Settings (no NavigationStack or Done button of its own).
struct AboutView: View {
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id1033609492")!
    private static let feedbackURL = URL(string: "mailto:clrung@gmail.com")!
    private static let sourceURL = URL(string: "https://github.com/clrung/HeartsScoreboard/")!
    /// PayPal donation link; amount=5 USD, recipient clrung@gmail.com (kept by owner decision)
    private static let donateURL = URL(string: "https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=clrung%40gmail.com&item_name=Hearts%20Scoreboard%20Donation&amount=5&currency_code=USD")!

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                header
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                Text("Developed by Christopher Rung")
                Text("Dedicated to my father, who loves Hearts, and has taught me to always shoot the moon.")
                Text("I would love to hear your feedback!")
            }

            Section {
                linkRow("Send Feedback", systemImage: "envelope.fill", url: AboutView.feedbackURL)
                linkRow("Rate on App Store", systemImage: "heart.fill", url: AboutView.appStoreURL)
                ShareLink(item: AboutView.appStoreURL) {
                    rowLabel("Share App", systemImage: "square.and.arrow.up")
                }
                .foregroundStyle(.primary)
            }

            Section {
                linkRow("Donate a coffee to Christopher", systemImage: "cup.and.saucer.fill", url: AboutView.donateURL)
                linkRow("View Source", systemImage: "chevron.left.slash.chevron.right", url: AboutView.sourceURL)
            }

            Section {
                VStack(spacing: 6) {
                    Text("\(String(localized: "App Version")) \(appVersion)")
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(Theme.accent)
                        Text(String(localized: "Made with love in Denver, CO"))
                        Text("🏔️")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 10) {
            AppIconImage()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                .accessibilityHidden(true)
            Text("Hearts Scoreboard")
                .font(.title2.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func linkRow(_ title: LocalizedStringKey, systemImage: String, url: URL) -> some View {
        Link(destination: url) {
            rowLabel(title, systemImage: systemImage)
        }
        .foregroundStyle(.primary)
    }

    /// Accent icon in a fixed column, primary text: one tint across every row.
    private func rowLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            Text(title)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

/// The app's own icon from the bundle, or a felt-green heart tile when it can't be loaded
/// (e.g. in a unit-test host).
private struct AppIconImage: View {
    private var icon: UIImage? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last else { return nil }
        return UIImage(named: name)
    }

    var body: some View {
        if let icon {
            Image(uiImage: icon).resizable().scaledToFit()
        } else {
            ZStack {
                Theme.accent
                Image(systemName: "heart.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    NavigationStack { AboutView() }
}
