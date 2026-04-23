import SwiftUI

struct ModelDownloadCard: View {
    let title: String
    let subtitle: String
    let description: String
    let size: String
    let badge: String?
    let badgeColor: Color
    let state: ModelDownloadState
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(badgeColor)
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(Theme.captionFont)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(size)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Text(description)
                .font(Theme.captionFont)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Action area — switches on download state
            Group {
                switch state {
                case .notDownloaded:
                    Button(action: onDownload) {
                        Label("Download for offline use", systemImage: "arrow.down.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                case .downloading(let progress):
                    VStack(spacing: 8) {
                        ProgressView(value: progress)
                            .tint(Theme.primary)
                        HStack {
                            Text("Downloading...")
                                .font(Theme.captionFont)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(Theme.captionFont)
                                .foregroundColor(Theme.primary)
                        }
                    }

                case .downloaded:
                    HStack(spacing: 12) {
                        Label("Downloaded", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Theme.primary)
                        Spacer()
                        Button(action: onDelete) {
                            Text("Remove")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)

                case .failed(let error):
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Download failed", systemImage: "exclamationmark.circle")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                        Text(error)
                            .font(Theme.captionFont)
                            .foregroundColor(.secondary)
                        Button(action: onDownload) {
                            Text("Try again")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}
