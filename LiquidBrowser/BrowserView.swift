import SwiftUI

struct BrowserView: View {
    @StateObject private var viewModel = BrowserViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.12, blue: 0.16), Color(red: 0.06, green: 0.08, blue: 0.11)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            WebViewContainer(viewModel: viewModel)
                .id(viewModel.webViewIdentity)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabStripView(viewModel: viewModel)
                Spacer(minLength: 0)
            }

            VStack {
                Spacer()
                BottomAddressBar(viewModel: viewModel)
            }

            HStack {
                FeatureBubble(viewModel: viewModel)
                Spacer()
            }
            .padding(.leading, 14)
            .padding(.bottom, 130)
            .frame(maxHeight: .infinity, alignment: .bottomLeading)

            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .tint(.white)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 12)
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingDevTools) {
            DevToolsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingProxyEditor) {
            ProxySettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingSettings) {
            BrowserSettingsView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.bootstrapIfNeeded()
        }
    }
}

private struct BottomAddressBar: View {
    @ObservedObject var viewModel: BrowserViewModel

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button(action: viewModel.goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(GlassIconButtonStyle(enabled: viewModel.canGoBack))
                .disabled(!viewModel.canGoBack)

                Button(action: viewModel.goForward) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(GlassIconButtonStyle(enabled: viewModel.canGoForward))
                .disabled(!viewModel.canGoForward)

                TextField("URL oder Suche", text: $viewModel.addressInput)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .submitLabel(.go)
                    .onSubmit {
                        viewModel.navigateFromInput()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button(action: {
                    if viewModel.isLoading {
                        viewModel.stopLoading()
                    } else {
                        viewModel.requestReload()
                    }
                }) {
                    Image(systemName: viewModel.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(GlassIconButtonStyle(enabled: true))
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )

            Text(viewModel.pageTitle)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }
}

private struct TabStripView: View {
    @ObservedObject var viewModel: BrowserViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.tabs) { tab in
                    HStack(spacing: 8) {
                        Button(action: {
                            viewModel.selectTab(tab.id)
                        }) {
                            Text(tab.title)
                                .font(.caption)
                                .lineLimit(1)
                                .frame(maxWidth: 110, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            viewModel.closeTab(tab.id)
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        (viewModel.selectedTabID == tab.id ? Color.white.opacity(0.24) : Color.white.opacity(0.11)),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }

                Button(action: viewModel.openNewTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }
}

private struct FeatureBubble: View {
    @ObservedObject var viewModel: BrowserViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.isFeatureMenuOpen {
                featureMenu
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            Button(action: {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                    viewModel.isFeatureMenuOpen.toggle()
                }
            }) {
                Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(
                        Circle()
                            .fill(Color(red: 0.16, green: 0.66, blue: 0.56).opacity(0.95))
                    )
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
        }
    }

    private var featureMenu: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Block all ads", isOn: Binding(
                get: { viewModel.settings.blockAds },
                set: { viewModel.toggleAds($0) }
            ))
            Toggle("Block all popups", isOn: Binding(
                get: { viewModel.settings.blockPopups },
                set: { viewModel.togglePopups($0) }
            ))
            Toggle("Block redirects", isOn: Binding(
                get: { viewModel.settings.blockRedirects },
                set: { viewModel.toggleRedirects($0) }
            ))
            Toggle("Use proxy", isOn: Binding(
                get: { viewModel.settings.useProxy },
                set: { viewModel.toggleProxy($0) }
            ))
            Toggle("Rotate proxy", isOn: Binding(
                get: { viewModel.settings.rotateProxyOnFailure },
                set: { viewModel.toggleProxyRotation($0) }
            ))

            Divider().overlay(Color.white.opacity(0.2))

            Button("Proxy list") {
                viewModel.isShowingProxyEditor = true
            }
            .foregroundStyle(.white)

            Button("Dev tools") {
                viewModel.isShowingDevTools = true
            }
            .foregroundStyle(.white)

            Button("Settings") {
                viewModel.isShowingSettings = true
            }
            .foregroundStyle(.white)
        }
        .font(.subheadline)
        .toggleStyle(.switch)
        .padding(14)
        .frame(maxWidth: 250, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct GlassIconButtonStyle: ButtonStyle {
    var enabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(enabled ? .white : .white.opacity(0.45))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.2 : 0.13))
            )
    }
}
