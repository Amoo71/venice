import SwiftUI

struct BrowserSettingsView: View {
    @ObservedObject var viewModel: BrowserViewModel

    @State private var newTabStartPageDraft: String = ""
    @State private var adExceptionDraft: String = ""
    @State private var popupExceptionDraft: String = ""
    @State private var redirectExceptionDraft: String = ""

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

                DomainExceptionSection(
                    title: "Ad-block exceptions",
                    domains: viewModel.settings.adExceptionDomains,
                    draft: $adExceptionDraft,
                    placeholder: "example.com",
                    addAction: {
                        viewModel.addAdExceptionDomain(adExceptionDraft)
                        adExceptionDraft = ""
                    },
                    removeAction: { domain in
                        viewModel.removeAdExceptionDomain(domain)
                    }
                )

                DomainExceptionSection(
                    title: "Popup exceptions",
                    domains: viewModel.settings.popupExceptionDomains,
                    draft: $popupExceptionDraft,
                    placeholder: "example.com",
                    addAction: {
                        viewModel.addPopupExceptionDomain(popupExceptionDraft)
                        popupExceptionDraft = ""
                    },
                    removeAction: { domain in
                        viewModel.removePopupExceptionDomain(domain)
                    }
                )

                DomainExceptionSection(
                    title: "Redirect exceptions",
                    domains: viewModel.settings.redirectExceptionDomains,
                    draft: $redirectExceptionDraft,
                    placeholder: "example.com",
                    addAction: {
                        viewModel.addRedirectExceptionDomain(redirectExceptionDraft)
                        redirectExceptionDraft = ""
                    },
                    removeAction: { domain in
                        viewModel.removeRedirectExceptionDomain(domain)
                    }
                )
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

private struct DomainExceptionSection: View {
    let title: String
    let domains: [String]
    @Binding var draft: String
    let placeholder: String
    let addAction: () -> Void
    let removeAction: (String) -> Void

    var body: some View {
        Section(title) {
            if domains.isEmpty {
                Text("No exceptions yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(domains, id: \.self) { domain in
                    HStack {
                        Text(domain)
                        Spacer()
                        Button(role: .destructive) {
                            removeAction(domain)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            HStack {
                TextField(placeholder, text: $draft)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onSubmit(addAction)

                Button("Add") {
                    addAction()
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
