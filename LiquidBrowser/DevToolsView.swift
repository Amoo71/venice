import SwiftUI

struct DevToolsView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @State private var selectedTab: DevToolsTab = .network
    @State private var consoleInput: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Panel", selection: $selectedTab) {
                    ForEach(DevToolsTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case .network:
                    networkPanel
                case .console:
                    consolePanel
                case .links:
                    linksPanel
                case .html:
                    htmlPanel
                case .cookies:
                    cookiesPanel
                }
            }
            .padding()
            .navigationTitle("Dev Tools")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        viewModel.clearDevToolsData()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        viewModel.isShowingDevTools = false
                    }
                }
            }
        }
        .onAppear {
            viewModel.refreshCookies()
            if viewModel.pageHTML.isEmpty {
                viewModel.refreshHTMLDump()
            }
        }
    }

    private var networkPanel: some View {
        List {
            if !viewModel.blockedEvents.isEmpty {
                Section("Blocked") {
                    ForEach(viewModel.blockedEvents) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.url)
                                .font(.caption)
                                .lineLimit(2)
                            Text(event.status)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Network") {
                ForEach(viewModel.networkEvents) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.method)
                                .font(.caption2.monospaced())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12), in: Capsule())

                            Text(event.status)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Spacer()

                            if let duration = event.durationMs {
                                Text("\(duration)ms")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(event.url)
                            .font(.caption)
                            .lineLimit(2)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var consolePanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("JavaScript command", text: $consoleInput)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onSubmit {
                        viewModel.runConsoleCommand(consoleInput)
                        consoleInput = ""
                    }

                Button("Run") {
                    viewModel.runConsoleCommand(consoleInput)
                    consoleInput = ""
                }
                .buttonStyle(.borderedProminent)
            }

            List(viewModel.consoleEvents) { event in
                VStack(alignment: .leading, spacing: 5) {
                    Text(event.level.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(event.message)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
            .listStyle(.plain)
        }
    }

    private var linksPanel: some View {
        VStack(spacing: 10) {
            Button("Refresh links") {
                viewModel.refreshLinkDump()
            }
            .buttonStyle(.borderedProminent)

            List {
                if !viewModel.capturedVideoLinks.isEmpty {
                    Section("Captured video links") {
                        ForEach(viewModel.capturedVideoLinks, id: \.self) { link in
                            Text(link)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                }

                Section("Page links") {
                    ForEach(viewModel.extractedLinks, id: \.self) { link in
                        Text(link)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var htmlPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button("Refresh HTML") {
                    viewModel.refreshHTMLDump()
                }
                .buttonStyle(.bordered)

                Button("Save HTML") {
                    viewModel.saveHTMLFromEditor()
                }
                .buttonStyle(.borderedProminent)
            }

            TextEditor(text: $viewModel.htmlEditorText)
                .font(.caption.monospaced())
                .scrollContentBackground(.hidden)
                .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .textSelection(.enabled)
        }
    }

    private var cookiesPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button("Refresh cookies") {
                    viewModel.refreshCookies()
                }
                .buttonStyle(.borderedProminent)

                Text("\(viewModel.cookies.count) cookies")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            List(viewModel.cookies) { cookie in
                CookieEditorRow(cookie: cookie) { updatedValue in
                    viewModel.saveCookieValue(cookie, newValue: updatedValue)
                } onDelete: {
                    viewModel.deleteCookie(cookie)
                }
            }
            .listStyle(.plain)
        }
    }
}

private struct CookieEditorRow: View {
    let cookie: BrowserCookie
    let onSave: (String) -> Void
    let onDelete: () -> Void

    @State private var valueDraft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(cookie.name)
                .font(.subheadline.weight(.semibold))

            Text("\(cookie.domain)\(cookie.path)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            TextField("Value", text: $valueDraft)
                .font(.caption.monospaced())
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            HStack(spacing: 8) {
                Button("Save") {
                    onSave(valueDraft)
                }
                .buttonStyle(.borderedProminent)

                Button("Delete") {
                    onDelete()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .onAppear {
            valueDraft = cookie.value
        }
        .onChange(of: cookie.value) { _, newValue in
            valueDraft = newValue
        }
    }
}
