//
//  UnixSocketAsync.swift
//  MacIconOverlay
//
//  Created by player on 2025/6/27.
//

import Foundation
import Network

/// actor 用于管理连接状态，确保线程安全
actor UnixSocketAsync {
    private var connection: NWConnection?
    private let socketPath: String
    private let queue = DispatchQueue(label: "SocketQueue")

    init(socketPath: String) {
        self.socketPath = socketPath
    }

    /// 启动连接（async）
    func connect() async throws {
        let endpoint = NWEndpoint.unix(path: socketPath)
        let parameters = NWParameters()
        parameters.defaultProtocolStack.applicationProtocols = []

        let conn = NWConnection(to: endpoint, using: parameters)
        connection = conn

        let ready: Void = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("✅ Connected to \(self.socketPath)")
                    cont.resume()
                case .failed(let error):
                    cont.resume(throwing: error)
                default:
                    break
                }
            }
            conn.start(queue: self.queue)
        }
    }

    /// 异步发送并等待响应
    func send(_ message: String, timeout: TimeInterval = 5.0) async throws -> String {
        guard let connection = connection else {
            throw NSError(domain: "SocketError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection not established"])
        }

        // 发送数据
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: message.data(using: .utf8), completion: .contentProcessed { error in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            })
        }

        // 接收响应
        return try await withCheckedThrowingContinuation { cont in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else if let data = data, !data.isEmpty {
                    let response = String(decoding: data, as: UTF8.self)
                    cont.resume(returning: response)
                } else {
                    cont.resume(returning: "")
                }
            }
        }
    }

    /// 停止连接
    func stop() {
        connection?.cancel()
        connection = nil
        print("🛑 Connection closed")
    }
}
