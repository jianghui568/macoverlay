//
//  FinderSync.swift
//  MacIconOverlaySyncExtension
//
//  Created by 一一 on 2025/6/15.
//

import Cocoa
import FinderSync

class FinderSync: FIFinderSync {
    private let userDefaults = UserDefaults(suiteName: "group.com.mycompany.MacIconOverlay")
    private let watchedPathsKey = "watchedPaths"
    private let lastUpdateTimeKey = "lastUpdateTime"
    private var lastUpdateTime: TimeInterval = 0
    private var timer: Timer?
    
    private var requestQueue: [URL] = []
    private let queueAccessQueue = DispatchQueue(label: "com.mycompany.MacIconOverlay.queueAccess")
    private var batchScheduled = false
    
    let socket = UnixSocket(groupID: "group.com.mycompany.MacIconOverlay")
    
    override init() {
        super.init()
        NSLog("9999999999999FinderSync start ~")
        setupBadgeImages()

        // 异步设置管理的目录范围
        Task {
            Logger.shared.log("9999999999999 task 11111111")
            do {
                // 1. 先异步连接，这会一直等到连接成功或失败
                try await socket.connect()
                Logger.shared.log("✅ Socket connected successfully.")
                
                // 2. 连接成功后，再发送请求
                let result = try await socket.sendAndWait("paths")
                Logger.shared.log("9999999999999 task 2222222222")
                let decoder = JSONDecoder()
                if let data = result.data(using: .utf8),
                   let paths = try? decoder.decode([String].self, from: data) {
                    let urls = paths.map { URL(fileURLWithPath: $0) }
                    FIFinderSyncController.default().directoryURLs = Set(urls)
                    Logger.shared.log("9999999999999 设置directoryURLs: \(urls)")
                } else {
                    Logger.shared.log("9999999999999 解析paths失败: \(result)")
                }
            } catch {
                Logger.shared.log("9999999999999 socket.sendAndWait(\"paths\") 失败: \(error)")
            }
        }
    }
    
    private func setupBadgeImages() {
        if let syncedImage = NSImage(named: "synced") {
            Logger.shared.log("9999999999999FinderSync setup imaged synced")
            FIFinderSyncController.default().setBadgeImage(syncedImage, label: "已同步", forBadgeIdentifier: "synced")
        }
        
        if let syncingImage = NSImage(named: "syncing") {
            Logger.shared.log("9999999999999FinderSync setup imaged syncing")
            FIFinderSyncController.default().setBadgeImage(syncingImage, label: "同步中", forBadgeIdentifier: "syncing")
        }
    }
    
    
    override func beginObservingDirectory(at url: URL) {
        Logger.shared.log("开始观察目录: \(url.path)")
    }
    
    override func endObservingDirectory(at url: URL) {
        Logger.shared.log("停止观察目录: \(url.path)")
    }
    
    override func requestBadgeIdentifier(for url: URL) {
        Logger.shared.log("requestBadgeIdentifier: \(url)")
        queueAccessQueue.async { [weak self] in
            guard let self = self else { return }
            self.requestQueue.append(url)
            if !self.batchScheduled {
                self.batchScheduled = true
                self.queueAccessQueue.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.processRequestQueue()
                }
            }
        }
    }
    
    private func processRequestQueue() {
        // 在串行队列内调用，无需加锁
        let urlsToProcess = self.requestQueue
        self.requestQueue.removeAll()
        self.batchScheduled = false
        guard !urlsToProcess.isEmpty else { return }
        
        // 1. 转为路径数组
        let pathArray = urlsToProcess.map { $0.path }
        let encoder = JSONEncoder()
        guard let jsonData = try? encoder.encode(pathArray),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            Logger.shared.log("9999999999 编码urlsToProcess失败")
            return
        }

        // 2. 通过 socket 发送并处理响应
       Task {
           do {
               let response = try await socket.sendAndWait(jsonString)
               let decoder = JSONDecoder()
               if let data = response.data(using: .utf8),
                  let statusMap = try? decoder.decode([String: Int].self, from: data) {
                   DispatchQueue.main.async {
                       for (path, s) in statusMap {
                           let url = URL(fileURLWithPath: path)
                           let state = s == 1 ? "syncing" : "synced"
                           Logger.shared.log("setBadgeIdentifier: \(url) : \(state)")
                           FIFinderSyncController.default().setBadgeIdentifier(state, for: url)
                       }
                   }
               } else {
                   Logger.shared.log("解析badge响应失败: \(response)")
               }
           } catch {
               Logger.shared.log("socket.sendAndWait 失败: \(error)")
           }
       }
    }
    
    // MARK: - Menu and toolbar item support
    
    override var toolbarItemName: String {
        return "FinderSy"
    }
    
    override var toolbarItemToolTip: String {
        return "FinderSy: Click the toolbar item for a menu."
    }
    
    override var toolbarItemImage: NSImage {
        return NSImage(named: NSImage.cautionName)!
    }
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        // Produce a menu for the extension.
        let menu = NSMenu(title: "")
        menu.addItem(withTitle: "MacIconOverlay", action: #selector(sampleAction(_:)), keyEquivalent: "")
        return menu
    }
    
    @IBAction func sampleAction(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
        NSLog("sampleAction: menu item: %@, target = %@, items = ", item.title as NSString, target!.path as NSString)
        for obj in items! {
            NSLog("    %@", obj.path as NSString)
        }
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
}

extension Notification.Name {
    static let iconOverlayStateChanged = Notification.Name("IconOverlayStateChanged")
}

