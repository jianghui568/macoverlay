//
//  UnixSocketClient.swift
//  MacIconOverlay
//
//  Created by 一一 on 2025/6/29.
//

import Foundation
import Network

/// Unix Socket 客户端类
/// 用于连接到Unix域套接字服务器，发送消息并接收响应
class UnixSocketClient {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "UnixSocketClientQueue")
    private let groupID: String
    
    /// 初始化客户端
    /// - Parameter groupID: 应用组标识符
    init(groupID: String) {
        self.groupID = groupID
    }
    
    /// 获取socket路径
    /// - Returns: socket文件路径，如果获取失败则返回nil
    private func socketPath() -> String? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            return nil
        }
        return containerURL.appendingPathComponent("unix_socket.sock").path
    }
    
    /// 连接到服务器
    /// - Returns: 连接是否成功
    func connect() -> Bool {
        guard let path = socketPath() else {
            print("❌ Could not resolve socket path")
            return false
        }
        
        let endpoint = NWEndpoint.unix(path: path)
        let params = NWParameters(tls: nil, tcp: .init())
        
        connection = NWConnection(to: endpoint, using: params)
        connection?.start(queue: queue)
        
        print("🔗 Attempting to connect to: \(path)")
        return true
    }
    
    /// 同步发送消息并等待响应
    /// - Parameters:
    ///   - message: 要发送的消息
    ///   - timeout: 超时时间（秒）
    /// - Returns: 服务器响应，如果失败则返回nil
    func sendAndReceive(_ message: String, timeout: TimeInterval = 5.0) -> String? {
        guard let connection = connection else {
            print("❌ No connection available")
            return nil
        }
        
        // 等待连接就绪
        let semaphore = DispatchSemaphore(value: 0)
        var isReady = false
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                isReady = true
                semaphore.signal()
            case .failed(let error):
                print("❌ Connection failed: \(error)")
                semaphore.signal()
            case .cancelled:
                print("❌ Connection cancelled")
                semaphore.signal()
            default:
                break
            }
        }
        
        // 等待连接就绪或超时
        _ = semaphore.wait(timeout: .now() + timeout)
        
        guard isReady else {
            print("❌ Connection not ready within timeout")
            return nil
        }
        
        // 发送消息
        let data = message.data(using: .utf8) ?? Data()
        let sendSemaphore = DispatchSemaphore(value: 0)
        var sendError: Error?
        
        connection.send(content: data, completion: .contentProcessed { error in
            sendError = error
            sendSemaphore.signal()
        })
        
        // 等待发送完成
        _ = sendSemaphore.wait(timeout: .now() + timeout)
        
        if let error = sendError {
            print("❌ Send error: \(error)")
            return nil
        }
        
        print("✅ Sent message: \(message)")
        
        // 接收响应
        let receiveSemaphore = DispatchSemaphore(value: 0)
        var response: String?
        var receiveError: Error?
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
            if let error = error {
                receiveError = error
            } else if let data = data, !data.isEmpty {
                response = String(decoding: data, as: UTF8.self)
            }
            receiveSemaphore.signal()
        }
        
        // 等待接收完成
        _ = receiveSemaphore.wait(timeout: .now() + timeout)
        
        if let error = receiveError {
            print("❌ Receive error: \(error)")
            return nil
        }
        
        if let response = response {
            print("📩 Received response: \(response)")
            return response
        } else {
            print("❌ No response received")
            return nil
        }
    }
    
    /// 发送消息（不等待响应）
    /// - Parameter message: 要发送的消息
    /// - Returns: 发送是否成功
    func send(message: String) -> Bool {
        guard let path = socketPath() else {
            print("❌ Could not resolve socket path")
            return false
        }
        
        let endpoint = NWEndpoint.unix(path: path)
        let params = NWParameters(tls: nil, tcp: .init())
        
        // 如果没有连接，创建新连接
        if connection == nil {
            connection = NWConnection(to: endpoint, using: params)
            connection?.start(queue: queue)
        }
        
        let data = message.data(using: .utf8) ?? Data()
        connection?.send(content: data, completion: .contentProcessed({ [weak self] error in
            if let error = error {
                print("❌ Send error: \(error)")
            } else {
                print("✅ Sent message: \(message)")
            }
        }))
        
        return true
    }
    
    /// 异步发送消息并等待响应
    /// - Parameters:
    ///   - message: 要发送的消息
    ///   - timeout: 超时时间（秒）
    /// - Returns: 服务器响应
    func sendAndWait(_ message: String, timeout: TimeInterval = 5.0) async throws -> String {
        guard let connection = self.connection, connection.state == .ready else {
            throw NSError(domain: "UnixSocketClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection is not ready"])
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
                throw NSError(domain: "UnixSocketClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Timeout"])
            }
            
            // 等待第一个完成的任务
            let result = try await group.next()!
            
            // 取消其他任务
            group.cancelAll()
            
            return result
        }
    }
    
    /// 执行发送和接收操作
    /// - Parameters:
    ///   - connection: 网络连接
    ///   - message: 要发送的消息
    /// - Returns: 服务器响应
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
    
    /// 断开连接
    func disconnect() {
        connection?.cancel()
        connection = nil
        print("🔌 Unix Socket Client disconnected")
    }
    
    /// 检查连接状态
    var isConnected: Bool {
        return connection?.state == .ready
    }
    
    /// 获取连接状态
    var connectionState: NWConnection.State? {
        return connection?.state
    }
}

// MARK: - 便捷方法

extension UnixSocketClient {
    
    /// 发送ping请求
    /// - Returns: 是否收到pong响应
    func ping() -> Bool {
        let response = sendAndReceive("ping", timeout: 2.0)
        return response == "pong"
    }
    
    /// 获取监控路径列表
    /// - Returns: 路径数组，如果失败则返回空数组
    func getPaths() -> [String] {
        let response = sendAndReceive("paths", timeout: 3.0)
        guard let response = response,
              let data = response.data(using: .utf8),
              let paths = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return paths
    }
    
    /// 查询文件状态
    /// - Parameter path: 文件路径
    /// - Returns: 状态字符串
    func getStatus(for path: String) -> String {
        let response = sendAndReceive("status:\(path)", timeout: 3.0)
        return response ?? "unknown"
    }
    
    /// 更新文件状态
    /// - Parameters:
    ///   - path: 文件路径
    ///   - status: 新状态
    /// - Returns: 更新是否成功
    func updateStatus(path: String, status: String) -> Bool {
        let response = sendAndReceive("update:\(path):\(status)", timeout: 3.0)
        return response?.hasPrefix("updated:") == true
    }
}
