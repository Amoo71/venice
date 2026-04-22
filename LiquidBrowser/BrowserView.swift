import SwiftUI
import AVKit

struct BrowserView: View {
    @StateObject private var viewModel = BrowserViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.12, blue: 0.16), Color(red: 0.06, green: 0.08, blue: 0.11)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            WebViewContainer(viewModel: viewModel)
                .id(viewModel.webViewIdentity)
                .ignoresSafeArea()

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

            BottomChrome(viewModel: viewModel)
                .offset(y: viewModel.isBottomChromeHidden ? 230 : 0)
                .opacity(viewModel.isBottomChromeHidden ? 0.2 : 1)
                .animation(.easeInOut(duration: 0.2), value: viewModel.isBottomChromeHidden)
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
        .sheet(isPresented: $viewModel.isShowingNativeVideoPlayer, onDismiss: {
            viewModel.closeNativeVideoPlayer()
        }) {
            if let url = viewModel.nativeVideoURL {
                NativePlayerView(url: url)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            viewModel.bootstrapIfNeeded()
        }
    }
}

private struct BottomChrome: View {
    @ObservedObject var viewModel: BrowserViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isFeatureMenuOpen {
                featureMenu
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 10)
            }

            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.isFeatureMenuOpen.toggle()
                    }
                }) {
                    Text("-")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.15), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)

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

                addressField

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

                Button(action: {
                    viewModel.burnEverything()
                }) {
                    Image(systemName: "flame.fill")
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

            TabStripView(viewModel: viewModel)

            Text(viewModel.pageTitle)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private var addressField: some View {
        ZStack(alignment: .trailing) {
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
                .padding(.trailing, 22)

            if !viewModel.addressInput.isEmpty {
                Button(action: {
                    viewModel.addressInput = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.75))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        .frame(maxWidth: 260, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
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
                                .frame(maxWidth: 112, alignment: .leading)
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
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(viewModel.selectedTabID == tab.id ? Color.white.opacity(0.35) : Color.white.opacity(0.12), lineWidth: 1)
                    )
                }

                Button(action: viewModel.openNewTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
        }
    }
}

private struct NativePlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: url)
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.player?.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
    }
}

private struct GlassIconButtonStyle: ButtonStyle {
    var enabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(enabled ? .white : .white.opacity(0.45))
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.35 : 0.2), lineWidth: 1)
            )
    }
}
