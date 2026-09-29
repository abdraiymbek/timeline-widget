import SwiftUI
import EventKit
import WidgetKit

struct ContentView: View {
    private let store = EventStore()
    @State private var status: EKAuthorizationStatus
    @State private var model: TimelineModel

    init() {
        let initial = EKEventStore.authorizationStatus(for: .event)
        _status = State(initialValue: initial)
        _model = State(initialValue: initial == .fullAccess
            ? TimelineLoader.load(calendarIDs: nil).model
            : DemoData.model())
    }

    var body: some View {
        ZStack {
            SpaceBackground()
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Timeline")
                        .font(.cormorant(34, .semibold, italic: true))
                        .foregroundStyle(Palette.starlight)
                    Text("Your calendar, as a quiet timeline of days on the desktop.")
                        .font(.cormorant(14.5, .medium))
                        .foregroundStyle(Palette.muted)
                }

                statusSection

                StandaloneWidgetView(model: model)
                    .frame(width: 329, height: 345)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Palette.starlight.opacity(0.12), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
                    .frame(maxWidth: .infinity)

                Text("Right-click the desktop, choose Edit Widgets, and search for Timeline.")
                    .font(.cormorant(12.5, .medium, italic: true))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
        }
        .frame(width: 480, height: 620)
        .onAppear(perform: refresh)
        .onOpenURL { _ in
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            refresh()
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch status {
        case .fullAccess:
            HStack(spacing: 8) {
                Circle()
                    .fill(Palette.earthlight)
                    .frame(width: 6, height: 6)
                Text("Calendar access granted — showing your events.")
                    .font(.cormorant(13, .medium))
                    .foregroundStyle(Palette.muted)
            }
        case .denied, .restricted:
            HStack(spacing: 12) {
                Text("Calendar access is off.")
                    .font(.cormorant(13, .medium))
                    .foregroundStyle(Palette.muted)
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(QuietButtonStyle())
            }
        default:
            HStack(spacing: 12) {
                Text("Timeline needs calendar access to show your events.")
                    .font(.cormorant(13, .medium))
                    .foregroundStyle(Palette.muted)
                Button("Allow calendar access") {
                    requestAccess()
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
    }

    private func requestAccess() {
        Task {
            _ = try? await store.requestAccess()
            status = store.authorizationStatus
            refresh()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func refresh() {
        let current = store.authorizationStatus
        status = current
        model = current == .fullAccess
            ? TimelineLoader.load(calendarIDs: nil).model
            : DemoData.model()
    }
}

private struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.cormorant(12.5, .semibold))
            .foregroundStyle(Palette.dustRose)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Palette.dustRose.opacity(configuration.isPressed ? 0.22 : 0.12))
            )
            .overlay(
                Capsule().strokeBorder(Palette.dustRose.opacity(0.3), lineWidth: 0.5)
            )
    }
}
