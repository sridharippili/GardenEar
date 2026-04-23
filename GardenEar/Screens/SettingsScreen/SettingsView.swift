import SwiftUI

struct SettingsView: View {
    @ObservedObject private var modelManager = OfflineModelManager.shared
    @ObservedObject private var network     = NetworkMonitor.shared
    @State private var capability           = DeviceCapabilityService.assess()
    @Environment(\.colorScheme) private var colorScheme

    private var bgColor: Color {
        colorScheme == .dark ? Theme.backgroundDark : Theme.background
    }
    private var surfaceColor: Color {
        colorScheme == .dark ? Theme.surfaceDark : Theme.surface
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    deviceInfoCard

                    // Show online status when connected, offline recommendation when not
                    if network.isConnected {
                        onlineStatusCard
                    } else {
                        recommendationCard
                    }

                    birdNetCard
                    natureLMCard
                    currentModeCard
                }
                .padding(16)
            }
            .background(bgColor.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(bgColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    // MARK: - Device info card

    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your Device", systemImage: "iphone")
                .font(Theme.headingFont)
                .foregroundColor(.primary)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(capability.modelName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("\(String(format: "%.1f", capability.availableStorageGB))GB available storage")
                        .font(Theme.captionFont)
                        .foregroundColor(.secondary)
                }
                Spacer()
                storageIndicator
            }
        }
        .padding(20)
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var storageIndicator: some View {
        let gb    = capability.availableStorageGB
        let color: Color = gb > 2 ? Theme.primary : gb > 1 ? .orange : .red
        let label = gb > 2 ? "Plenty of space" : gb > 1 ? "Limited space" : "Low storage"
        return VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(color)
        }
    }

    // MARK: - Online status card (connected)

    private var onlineStatusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Theme.primary)
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text("Using online model")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Connected — using BirdNET server for best accuracy")
                    .font(Theme.captionFont)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Theme.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.primary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Recommendation card (offline)

    private var recommendationCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 22))
                .foregroundColor(Theme.primary)
            VStack(alignment: .leading, spacing: 4) {
                Text("Recommended for you")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text(capability.recommendationReason)
                    .font(Theme.captionFont)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Theme.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.primary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - BirdNET download card

    private var birdNetCard: some View {
        ModelDownloadCard(
            title:       "BirdNET",
            subtitle:    "Cornell Lab · 6,000+ species",
            description: "Fast on-device identification. Works offline in ~3 seconds. Recommended for all devices.",
            size:        "50 MB",
            badge:       capability.recommendedModel == .birdNetTFLite ? "Recommended" : nil,
            badgeColor:  Theme.primary,
            state:       modelManager.birdNetState,
            onDownload:  { Task { await modelManager.downloadBirdNet() } },
            onDelete:    { modelManager.deleteBirdNet() }
        )
    }

    // MARK: - NatureLM card (coming soon)

    private var natureLMCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("NatureLM-audio")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Coming soon")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                    Text("Earth Species Project · Birds, frogs, whales + more")
                        .font(Theme.captionFont)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("1.4 GB")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Text("Includes life stage, call type, and broader species detection. Requires iPhone 12+ and 2GB free storage.")
                .font(Theme.captionFont)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: capability.supportsNatureLM ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(capability.supportsNatureLM ? Theme.primary : .red)
                Text(capability.supportsNatureLM
                     ? "Compatible with your \(capability.modelName)"
                     : "Requires iPhone 12 or newer")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "arrow.down.circle")
                Text("Available in a future update")
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.accent.opacity(0.4), lineWidth: 1)
            )
        }
        .padding(20)
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .opacity(0.8)
    }

    // MARK: - Current mode card

    private var currentModeCard: some View {
        HStack(spacing: 12) {
            Image(systemName: modelManager.isBirdNetDownloaded ? "wifi.slash" : "wifi")
                .font(.system(size: 20))
                .foregroundColor(Theme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(modelManager.isBirdNetDownloaded ? "Offline mode active" : "Online mode active")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text(modelManager.isBirdNetDownloaded
                     ? "Using local BirdNET model — no internet needed"
                     : "Using BirdNET server at ippili7-gardenear-api.hf.space")
                    .font(Theme.captionFont)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}
