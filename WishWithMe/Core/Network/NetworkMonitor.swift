import Foundation
import Network
import Observation

// MARK: - Network Monitor

@Observable
final class NetworkMonitor: @unchecked Sendable {
    private let monitor: NWPathMonitor
    private let queue: DispatchQueue

    private(set) var isConnected: Bool = true
    private(set) var connectionType: ConnectionType = .unknown

    var onStatusChange: ((Bool) -> Void)?

    enum ConnectionType: Sendable {
        case wifi
        case cellular
        case wired
        case unknown
    }

    init() {
        self.monitor = NWPathMonitor()
        self.queue = DispatchQueue(label: "com.wishwithme.networkmonitor", qos: .utility)
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }

    private func handlePathUpdate(_ path: NWPath) {
        let previousStatus = isConnected
        isConnected = path.status == .satisfied
        connectionType = determineConnectionType(path)

        if previousStatus != isConnected {
            onStatusChange?(isConnected)
        }
    }

    private func determineConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wired
        } else {
            return .unknown
        }
    }
}

// MARK: - Network Status View Helper

extension NetworkMonitor {
    var statusDescription: String {
        if isConnected {
            switch connectionType {
            case .wifi:
                return String(localized: "network.wifi")
            case .cellular:
                return String(localized: "network.cellular")
            case .wired:
                return String(localized: "network.wired")
            case .unknown:
                return String(localized: "network.connected")
            }
        } else {
            return String(localized: "network.offline")
        }
    }

    var statusIcon: String {
        if isConnected {
            switch connectionType {
            case .wifi:
                return "wifi"
            case .cellular:
                return "antenna.radiowaves.left.and.right"
            case .wired:
                return "cable.connector"
            case .unknown:
                return "network"
            }
        } else {
            return "wifi.slash"
        }
    }
}
