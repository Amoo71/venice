import SwiftUI

struct BrowserSettingsView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @State private var newTabStartPageDraft: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Device emulation") {
                    Picker("User agent", selection: Binding(
                        get: { viewModel.settings.emulationProfile },
                        set: { viewModel.updateEmulation($0) }
                    )) {
                        ForEach(EmulationProfile.allCases) { profile in
                            Text(profile.rawValue).tag(profile)
                        }
                    }

                    Text(viewModel.settings.emulationProfile.userAgent)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Section("Tabs and startup") {
                    Toggle("Keep tabs after restart", isOn: Binding(
                        get: { viewModel.settings.restoreTabsOnLaunch },
                        set: { viewModel.updateRestoreTabs($0) }
                    ))

                    TextField("New tab start page", text: $newTabStartPageDraft)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .onSubmit {
                            viewModel.updateNewTabStartPage(newTabStartPageDraft)
                        }

                    Button("Save new tab start page") {
                        viewModel.updateNewTabStartPage(newTabStartPageDraft)
                    }

                    Button("Set current page as homepage") {
                        viewModel.setHomepageToCurrent()
                    }

                    Button("Close all tabs and start fresh") {
                        viewModel.closeAllTabsAndStartFresh()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        viewModel.isShowingSettings = false
                    }
                }
            }
            .onAppear {
                if newTabStartPageDraft.isEmpty {
                    newTabStartPageDraft = viewModel.settings.newTabStartPage
                }
            }
        }
    }
}
