import SwiftUI

struct JournalView: View {
    @StateObject private var viewModel = JournalViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var sightingPendingDelete: Sighting?

    private var bgColor: Color {
        colorScheme == .dark ? Theme.backgroundDark : Theme.background
    }

    // "Wednesday, April 22"
    private var todayFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sightings.isEmpty {
                    emptyState
                } else {
                    journalList
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.large)          // collapses on scroll ↑
            .toolbarBackground(bgColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .background(bgColor.ignoresSafeArea())
        }
        .onAppear { viewModel.load() }
        .task { viewModel.load() }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in viewModel.load() }
        .onReceive(
            NotificationCenter.default.publisher(for: .sightingSaved)
        ) { _ in viewModel.load() }
        .alert("Delete sighting?", isPresented: Binding(
            get: { sightingPendingDelete != nil },
            set: { if !$0 { sightingPendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let s = sightingPendingDelete { viewModel.delete(sighting: s) }
                sightingPendingDelete = nil
            }
            Button("Cancel", role: .cancel) { sightingPendingDelete = nil }
        } message: {
            if let s = sightingPendingDelete {
                Text("\"\(s.speciesName)\" will be permanently removed.")
            }
        }
    }

    // MARK: - Styled header (scrolls with list → large title collapses into nav bar)

    private var journalHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Date subtitle
            Text(todayFormatted)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Count badges
            HStack(spacing: 8) {
                countBadge(
                    icon:  "eye.fill",
                    label: "\(viewModel.sightings.count) sightings",
                    color: Theme.secondary
                )
                countBadge(
                    icon:  "leaf.fill",
                    label: "\(viewModel.totalUnique) species",
                    color: Theme.primary
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private func countBadge(icon: String, label: String, color: Color) -> some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color)
            .clipShape(Capsule())
    }

    // MARK: - Journal list

    private var journalList: some View {
        List {
            // ── Styled header row ──────────────────────────────────────────
            Section {
                journalHeader
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(headerRowBackground)
            }

            // ── Sighting groups ───────────────────────────────────────────
            ForEach(viewModel.groupedByDate, id: \.date) { group in
                Section {
                    ForEach(group.sightings) { sighting in
                        NavigationLink(destination: SightingDetailView(sighting: sighting)) {
                            SightingRow(sighting: sighting)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                sightingPendingDelete = sighting
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(group.date.uppercased())
                        .font(Theme.captionFont)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(bgColor.ignoresSafeArea())
    }

    /// Subtle teal-to-clear gradient that hints at the nature theme without overpowering.
    private var headerRowBackground: some View {
        ZStack {
            // Base: adaptive surface colour (matches list card bg)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Theme.surfaceDark : Theme.surface)

            // Overlay: diagonal gradient tint
            LinearGradient(
                colors: [
                    Theme.primary.opacity(colorScheme == .dark ? 0.22 : 0.12),
                    Theme.accent.opacity(colorScheme == .dark ? 0.10 : 0.05),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        // Show the header even when empty so the date & zero-counts are visible.
        ScrollView {
            VStack(spacing: 0) {
                // Mirror the list header as a plain card
                journalHeader
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(colorScheme == .dark ? Theme.surfaceDark : Theme.surface)
                            .overlay(
                                LinearGradient(
                                    colors: [
                                        Theme.primary.opacity(colorScheme == .dark ? 0.22 : 0.12),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            )
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Spacer().frame(height: 80)

                VStack(spacing: 16) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.accent)
                    Text("No sightings yet")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    Text("Go outside and record something!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 40)
        }
        .background(bgColor.ignoresSafeArea())
    }
}
