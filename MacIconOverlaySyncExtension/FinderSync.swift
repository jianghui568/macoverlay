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
    
    override init() {
        super.init()
        NSLog("9999999999999FinderSync start ~")
        
        let url = URL.init(filePath: "/Users/yiyi/projects/verysync")
        FIFinderSyncController.default().directoryURLs = [url];
        
        setupBadgeImages()
        
        
        NSLog("9999999999999FinderSync setup timer")
        setupTimer()
    }
    
    private func setupBadgeImages() {
        if let syncedImage = NSImage(named: "synced") {
            NSLog("9999999999999FinderSync setup imaged synced")
            FIFinderSyncController.default().setBadgeImage(syncedImage, label: "已同步", forBadgeIdentifier: "synced")
        }
        
        if let syncingImage = NSImage(named: "syncing") {
            NSLog("9999999999999FinderSync setup imaged syncing")
            FIFinderSyncController.default().setBadgeImage(syncingImage, label: "同步中", forBadgeIdentifier: "syncing")
        }
    }

    
    private func setupTimer() {
        // 创建定时器，每秒检查一次更新
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkForUpdates()
        }
    }
    
    private func checkForUpdates() {
        guard let currentUpdateTime = userDefaults?.double(forKey: lastUpdateTimeKey),
              currentUpdateTime > lastUpdateTime else {
            return
        }
        
        // 更新本地时间戳
        lastUpdateTime = currentUpdateTime
        
        // 获取最新的状态数据
        guard let watchedPaths = userDefaults?.dictionary(forKey: watchedPathsKey) as? [String: String] else {
            NSLog("9999999999999 FinderSync guard watchedPaths error ------ ")
            return
        }
        
        NSLog("9999999999999 FinderSync checkForUpdates - watchedPaths: %@", watchedPaths)
        
        // 更新所有图标
        if let path = watchedPaths["path"],
           let state = watchedPaths["state"] {
            let url = URL(fileURLWithPath: path)
            
            // 使用异步方式更新图标
            DispatchQueue.main.async {
                FIFinderSyncController.default().setBadgeIdentifier(state, for: url)
                Logger.shared.log("更新图标 - path: \(path), state: \(state)")
            }
        }
    }
    
    
    override func beginObservingDirectory(at url: URL) {
        Logger.shared.log("开始观察目录: \(url.path)")
    }
    
    override func endObservingDirectory(at url: URL) {
        Logger.shared.log("停止观察目录: \(url.path)")
    }
    
    override func requestBadgeIdentifier(for url: URL) {
        NSLog("9999999999999 FinderSync requestBadgeIdentifier - url: %@", url.path)
        
        guard let watchedPaths = userDefaults?.dictionary(forKey: watchedPathsKey) as? [String: String] else {
            NSLog("9999999999999 FinderSync requestBadgeIdentifier - no watchedPaths")
            return
        }
        
        NSLog("9999999999999 FinderSync requestBadgeIdentifier - watchedPaths: %@", watchedPaths)
        
        if let path = watchedPaths["path"],
           let state = watchedPaths["state"] {
            NSLog("9999999999999 FinderSync requestBadgeIdentifier - comparing paths: %@ vs %@", path, url.path)
            
            // 检查路径是否匹配
            if path == url.path {
                NSLog("9999999999999 FinderSync requestBadgeIdentifier - setting badge: %@", state)
                FIFinderSyncController.default().setBadgeIdentifier(state, for: url)
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

