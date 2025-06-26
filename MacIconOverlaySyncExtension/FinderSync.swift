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
    
    let socket = UnixSocket()
    
    override init() {
        super.init()
        NSLog("9999999999999FinderSync start ~")
        
        let url = URL.init(filePath: "/Users/player/projects/sync")
        FIFinderSyncController.default().directoryURLs = [url];
        
        setupBadgeImages()
        
        socket.startServer { path in
            NSLog("9999999999999 socket get path: %@", path);
        }
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


        sleep(3);
        DispatchQueue.main.async {
            for url in urlsToProcess {
                let state = url.absoluteString.count % 2 == 1 ? "synced" : "syncing"
                Logger.shared.log("xxxxxxxxx:  \(url) : \(state)")
                FIFinderSyncController.default().setBadgeIdentifier(state, for: url)
            }
//            for (url, state) in statusMap {
//                FIFinderSyncController.default().setBadgeIdentifier(state, for: url)
//            }
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

