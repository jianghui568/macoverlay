//
//  UnixSocket.swift
//  MacIconOverlay
//
//  Created by player on 2025/6/24.
//


import Foundation
import Network

// AppGroup identifier (must be configured in both targets)
let appGroupID = "group.com.mycompany.MacIconOverlay"

// Define a Unix domain socket path (inside app group container)
func socketPath() -> String? {
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
        return nil
    }
    return containerURL.appendingPathComponent("unix_socket.sock").path
}

class UnixSocket {
    private var listener: NWListener?
    private var connection: NWConnection?

    // MARK: - Server
    func startServer(onReceive: @escaping (String) -> Void) {
        guard let path = socketPath() else {
            print("❌ Failed to get socket path")
            return
        }

        // Clean up previous socket file if it exists
        unlink(path)

        let params = NWParameters(tls: nil, tcp: .init())
        params.allowLocalEndpointReuse = true
        params.includePeerToPeer = false
        params.requiredLocalEndpoint = NWEndpoint.unix(path: path)

        do {
            listener = try NWListener(using: params)
        } catch {
            print("❌ Failed to start listener: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .main)
            self?.receive(on: connection, handler: onReceive)
        }

        listener?.start(queue: .main)
        print("✅ Unix Socket Server started at: \(path)")
    }

    private func receive(on connection: NWConnection, handler: @escaping (String) -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, error in
            if let data = data, let message = String(data: data, encoding: .utf8) {
                print("📩 Received: \(message)")
                handler(message)
            }
            if error == nil {
                self?.receive(on: connection, handler: handler) // Continue listening
            }
        }
    }

    func stopServer() {
        listener?.cancel()
        if let path = socketPath() {
            unlink(path)
        }
    }

    // MARK: - Client
    func send(message: String) {
        guard let path = socketPath() else {
            print("❌ Could not resolve socket path")
            return
        }

        let endpoint = NWEndpoint.unix(path: path)
        let params = NWParameters(tls: nil, tcp: .init())

        connection = NWConnection(to: endpoint, using: params)
        connection?.start(queue: .main)

        let data = message.data(using: .utf8) ?? Data()
        connection?.send(content: data, completion: .contentProcessed({ [weak self] error in
            if let error = error {
                print("❌ Send error: \(error)")
            } else {
                print("✅ Sent message: \(message)")
            }
            self?.connection?.cancel()
        }))
    }
}
