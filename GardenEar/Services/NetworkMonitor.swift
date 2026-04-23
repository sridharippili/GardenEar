import Network
import Combine

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var isConnected: Bool = true
    @Published var connectionType: ConnectionType = .unknown

    enum ConnectionType {
        case wifi, cellular, unknown, none
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    init() {
        // Synchronous check so isConnected is correct before the monitor fires
        let currentPath = monitor.currentPath
        isConnected = currentPath.status == .satisfied
        if currentPath.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if currentPath.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if currentPath.status == .satisfied {
            connectionType = .unknown
        } else {
            connectionType = .none
        }

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.status == .satisfied {
                    self?.connectionType = .unknown
                } else {
                    self?.connectionType = .none
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
