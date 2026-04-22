import SwiftUI

struct DevToolsView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @State private var selectedTab: DevToolsTab = .network

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
        List(viewModel.consoleEvents) { event in
            VStack(alignment: .leading, spacing: 5) {
                Text(event.level.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(event.message)
                    .font(.caption)
            }
        }
        .listStyle(.plain)
    }

    private var linksPanel: some View {
        VStack(spacing: 10) {
            Button("Refresh links") {
                viewModel.refreshLinkDump()
            }
            .buttonStyle(.borderedProminent)

            List(viewModel.extractedLinks, id: \.self) { link in
                Text(link)
                    .font(.caption)
                    .textSelection(.enabled)
            }
            .listStyle(.plain)
        }
    }

    private var htmlPanel: some View {
        VStack(spacing: 10) {
            Button("Refresh HTML") {
                viewModel.refreshHTMLDump()
            }
            .buttonStyle(.borderedProminent)

            ScrollView {
                Text(viewModel.pageHTML)
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}
