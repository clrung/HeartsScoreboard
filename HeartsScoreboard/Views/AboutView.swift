import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private static let appStoreURL = URL(string: "https://apps.apple.com/app/id1033609492")!
    private static let feedbackURL = URL(string: "mailto:clrung@gmail.com")!
    private static let sourceURL = URL(string: "https://github.com/clrung/HeartsScoreboard/")!
    /// PayPal donation link; amount=5 USD, recipient clrung@gmail.com
    private static let donateURL = URL(string: "https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=clrung%40gmail.com&item_name=Hearts%20Scoreboard%20Donation&amount=5&currency_code=USD")!

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Developed by Christopher Rung")
                            .font(.body)
                        Text("Dedicated to my father, who loves Hearts, and has taught me to always shoot the moon.")
                            .font(.body)
                        Text("I would love to hear your feedback!")
                            .font(.body)
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Link(destination: AboutView.feedbackURL) {
                        HStack {
                            Text("Send Feedback")
                            Spacer()
                            Image(systemName: "envelope.fill")
                                .font(.body)
                                .foregroundStyle(.blue)
                        }
                    }
                }

                Section {
                    Link(destination: AboutView.appStoreURL) {
                        HStack {
                            Text("Rate on App Store")
                            Spacer()
                            Image(systemName: "heart.fill")
                                .font(.body)
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                Section {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Link(destination: AboutView.donateURL) {
                        HStack {
                            Text(String(localized: "Donate a coffee to Christopher"))
                            Spacer()
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.body)
                                .foregroundStyle(.brown)
                        }
                    }
                }
                
                Section {
                    Link(destination: AboutView.sourceURL) {
                        HStack {
                            Text("View Source")
                            Spacer()
                            Image(systemName: "chevron.left.slash.chevron.right")
                                .font(.body)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
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
