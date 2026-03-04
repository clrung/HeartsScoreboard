import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private static let appStoreURL = URL(string: "https://apps.apple.com/app/id1033609492")!
    private static let websiteURL = URL(string: "https://christopherrung.com")!

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        return "\(short)"
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
                    Link(destination: AboutView.websiteURL) {
                        HStack {
                            Text("christopherrung.com")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section {
                    Button {
                        openURL(AboutView.appStoreURL)
                    } label: {
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
