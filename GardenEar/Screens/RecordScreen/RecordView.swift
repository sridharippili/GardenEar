import SwiftUI
import UniformTypeIdentifiers

struct RecordView: View {
    @StateObject private var viewModel = RecordViewModel()
    @ObservedObject private var modelManager = OfflineModelManager.shared
    @ObservedObject private var network = NetworkMonitor.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingFilePicker = false
    @State private var isAnalyzingFile = false

    private var bgColor: Color {
        colorScheme == .dark ? Theme.backgroundDark : Theme.background
    }

    private var isRecording: Bool {
        if case .recording = viewModel.state { return true }
        return false
    }
    private var isLoading: Bool {
        if case .loading = viewModel.state { return true }
        return false
    }
    private var isResult: Bool {
        if case .result = viewModel.state { return true }
        return false
    }
    private var isError: Bool {
        if case .error = viewModel.state { return true }
        return false
    }

    var body: some View {
        NavigationStack {
        ZStack(alignment: .top) {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top header
                VStack(alignment: .center, spacing: 6) {
                    Text("GardenEar")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.primary)
                    Text("Tap to identify backyard sounds")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.secondary)

                    // Connectivity pill
                    HStack(spacing: 6) {
                        Circle()
                            .fill(network.isConnected ? Theme.primary : .orange)
                            .frame(width: 7, height: 7)
                        Text(network.isConnected
                             ? "Online · BirdNET server"
                             : modelManager.isBirdNetDownloaded
                               ? "Offline · Local BirdNET"
                               : "Offline · No local model")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.systemBackground))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.05), radius: 4)
                }
                .padding(.top, 16)

                Spacer()

                // Center: waveform + button + timer + upload
                VStack(spacing: 24) {
                    if isRecording {
                        WaveformView(recorder: viewModel.audioRecorder)
                            .frame(maxWidth: CGFloat.infinity)
                            .transition(
                                AnyTransition.opacity.combined(
                                    with: AnyTransition.scale(scale: 0.95)
                                )
                            )
                    }

                    // Button + ping rings stacked, timer below
                    VStack(spacing: 16) {
                        ZStack {
                            if isRecording {
                                pingRings
                            }
                            recordButton
                        }

                        // MM:SS duration timer — recording only
                        if isRecording {
                            Text(durationString)
                                .font(.system(size: 22, weight: .medium, design: .monospaced))
                                .foregroundColor(.primary)
                                .transition(
                                    .opacity.combined(with: .scale(scale: 0.85))
                                )
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: isRecording)

                    // Upload button — idle state only
                    if case .idle = viewModel.state {
                        uploadButton
                            .transition(AnyTransition.opacity.combined(with: AnyTransition.scale(scale: 0.95)))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: isRecording)

                // Status label — fixed height so layout doesn't jump
                Text(statusLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(height: 20)
                    .padding(.top, 24)

                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomSection
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
        }
        // Save confirmation toast
        .overlay(alignment: .bottom) {
            if viewModel.showSaveConfirmation {
                Text(viewModel.saveMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Theme.primary)
                    .clipShape(Capsule())
                    .shadow(color: Theme.primary.opacity(0.3), radius: 8, y: 2)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: viewModel.showSaveConfirmation)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [
                .audio,
                UTType(filenameExtension: "mp3")  ?? .audio,
                UTType(filenameExtension: "wav")  ?? .audio,
                UTType(filenameExtension: "m4a")  ?? .audio,
                UTType(filenameExtension: "flac") ?? .audio
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    isAnalyzingFile = true
                    viewModel.analyzeUploadedFile(url: url)
                }
            case .failure(let error):
                viewModel.state = .error(error.localizedDescription)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(bgColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(Theme.primary)
                }
            }
        }
        } // NavigationStack
    }

    // MARK: - Status label

    private var statusLabel: String {
        switch viewModel.state {
        case .loading: return isAnalyzingFile ? "Analyzing your file..." : "Identifying your recording..."
        default:       return ""
        }
    }

    // MARK: - Duration string (MM:SS monospace timer)

    private var durationString: String {
        let s = viewModel.elapsedSeconds
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    // MARK: - Upload button

    private var uploadButton: some View {
        Button {
            showingFilePicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .medium))
                Text("Analyze audio file")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(.secondary)
            .frame(maxWidth: CGFloat.infinity)
            .frame(height: 50)
            .background(colorScheme == .dark ? Theme.surfaceDark : Theme.surface)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.accent, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 32)
    }

    // MARK: - Ping rings (teal stroke, expand + fade, staggered 0 / 0.3 / 0.6 s)

    private var pingRings: some View {
        ZStack {
            PingRing(delay: 0.0)
            PingRing(delay: 0.3)
            PingRing(delay: 0.6)
        }
    }

    // MARK: - Record button

    private var recordButton: some View {
        Button {
            switch viewModel.state {
            case .idle:
                isAnalyzingFile = false
                viewModel.startRecording()
            case .recording:
                viewModel.stopRecording()
            default:
                break
            }
        } label: {
            ZStack {
                // Outer glow — colour matches button fill
                Circle()
                    .fill(isRecording ? Color.red : Theme.primary)
                    .frame(width: 96, height: 96)
                    .shadow(
                        color: (isRecording ? Color.red : Theme.primary).opacity(0.5),
                        radius: 24, x: 0, y: 0
                    )
                    .animation(.easeInOut(duration: 0.3), value: isRecording)

                // Icon
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
                } else if isRecording {
                    // Rounded square stop icon (w-8 h-8 = 32 pt)
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    // MARK: - Bottom section

    @ViewBuilder
    private var bottomSection: some View {
        if case .result = viewModel.state {
            VStack(spacing: 16) {
                ResultCard(
                    detectedSpecies: $viewModel.detectedSpecies,
                    onToggle: { id in viewModel.toggleSpecies(id: id) }
                )
                actionButtons
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isResult)
        } else if case .error(let msg) = viewModel.state {
            let isOffline = msg == AppError.offlineNoModel.errorDescription
            Group {
                if isOffline {
                    offlinePanel
                } else {
                    errorPanel(message: msg)
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isError)
        }
    }

    // MARK: - Action buttons

    @ViewBuilder
    private var actionButtons: some View {
        let selectedCount = viewModel.detectedSpecies.filter { $0.isSelected }.count
        VStack(spacing: 10) {
            Button {
                viewModel.saveSelectedSightings()
            } label: {
                Text(selectedCount == 0
                     ? "Select Species to Save"
                     : "Save \(selectedCount) \(selectedCount == 1 ? "Species" : "Species")")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.primary)
                    .cornerRadius(14)
                    .opacity(selectedCount == 0 ? 0.5 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(selectedCount == 0)

            tryAgainButton
        }
    }

    private var tryAgainButton: some View {
        Button {
            viewModel.reset()
        } label: {
            Text("Try Again")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Theme.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(colorScheme == .dark ? Theme.surfaceDark : Theme.surface)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.accent, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Offline panel

    private var offlinePanel: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("You're offline")
                .font(Theme.headingFont)
                .foregroundColor(.primary)

            Text("Download BirdNET (50MB) to identify species without internet. Your recording has been saved.")
                .font(Theme.captionFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await OfflineModelManager.shared.downloadBirdNet() }
            } label: {
                Label("Download BirdNET — 50MB", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            if case .downloading(let progress) = modelManager.birdNetState {
                VStack(spacing: 6) {
                    ProgressView(value: progress)
                        .tint(Theme.primary)
                    Text("Downloading... \(Int(progress * 100))%")
                        .font(Theme.captionFont)
                        .foregroundColor(.secondary)
                }
            }

            if case .downloaded = modelManager.birdNetState {
                Button { viewModel.retryWithLocalModel() } label: {
                    Label("Identify now (offline)", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.primary)
                }
                .buttonStyle(.plain)
            }

            Button("Try again later") { viewModel.reset() }
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
        }
        .padding(20)
        .background(colorScheme == .dark ? Theme.surfaceDark : Theme.surface)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.07), radius: 16, x: 0, y: 4)
    }

    // MARK: - Error panel

    private func errorPanel(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            tryAgainButton
        }
        .padding(20)
        .background(colorScheme == .dark ? Theme.surfaceDark : Theme.surface)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.07), radius: 16, x: 0, y: 4)
    }
}

// MARK: - Ping ring
// Each ring expands from 1× to 2× and fades out over 2 s,
// with a one-time stagger delay so the three rings feel continuous.

private struct PingRing: View {
    let delay: Double

    @State private var scale:   CGFloat = 1.0
    @State private var opacity: Double  = 0.30

    // Teal matching GardenEar's nature theme (rgba 0, 200, 180)
    private let ringColor = Color(red: 0.0, green: 0.78, blue: 0.70)

    var body: some View {
        Circle()
            .strokeBorder(ringColor.opacity(opacity), lineWidth: 2)
            .frame(width: 96, height: 96)
            .scaleEffect(scale)
            .onAppear {
                // Stagger the first fire; then repeat continuously with no extra delay
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                        scale   = 2.2
                        opacity = 0
                    }
                }
            }
    }
}
