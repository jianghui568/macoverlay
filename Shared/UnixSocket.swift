//
//  UnixSocket.swift
//  MacIconOverlay
//
//  Created by player on 2025/6/24.
//


import Foundation
import Network

// AppGroup identifier (must be configured in both targets)
class UnixSocket {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "UnixSocketClientAsync")
    private let groupID: String

    init(groupID: String) {
        self.groupID = groupID
    }
    
    /// 异步连接到服务器，直到连接状态变为 .ready 或 .failed
    func connect() async throws {
        // 如果已有连接，先断开
        if let existingConnection = connection {
            existingConnection.cancel()
        }
        
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)!
        let socketPath = containerURL.appendingPathComponent("unix_socket.sock").path
        
        let endpoint = NWEndpoint.unix(path: socketPath)
        let parameters = NWParameters() // 使用默认的 unix 参数
        
        let newConnection = NWConnection(to: endpoint, using: parameters)
        self.connection = newConnection

        return try await withCheckedThrowingContinuation { continuation in
            newConnection.stateUpdateHandler = { state in
                print("Connection state: \(state)")
                switch state {
                case .ready:
                    // 连接成功，恢复执行
                    continuation.resume()
                case .failed(let error):
                    // 连接失败，抛出错误
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume(throwing: NWError.posix(POSIXErrorCode.ECANCELED))
                default:
                    // 其他状态如 preparing, waiting 等，继续等待
                    break
                }
            }
            newConnection.start(queue: queue)
        }
    }

    func stop() {
        connection?.cancel()
        connection = nil
    }

    func sendAndWait(_ message: String, timeout: TimeInterval = 5.0) async throws -> String {
        guard let connection = self.connection, connection.state == .ready else {
            throw NSError(domain: "UnixSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection is not ready"])
        }

        // 使用 TaskGroup 实现带超时的发送和接收
        return try await withThrowingTaskGroup(of: String.self) { group in
            // 网络操作任务
            group.addTask {
                try await self.performSendReceive(connection: connection, message: message)
            }
            // 超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw NSError(domain: "UnixSocket", code: -2, userInfo: [NSLocalizedDescriptionKey: "Timeout"])
            }

            // 等待第一个完成的任务
            let result = try await group.next()!
            
            // 取消其他任务
            group.cancelAll()
            
            return result
        }
    }
    
    private func performSendReceive(connection: NWConnection, message: String) async throws -> String {
        // 1. 发送数据
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: message.data(using: .utf8), completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
        
        // 2. 接收数据
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, !data.isEmpty {
                    let response = String(decoding: data, as: UTF8.self)
                    continuation.resume(returning: response)
                } else {
                    // 对端关闭了连接或发送了空数据
                    continuation.resume(returning: "")
                }
            }
        }
    }
}
