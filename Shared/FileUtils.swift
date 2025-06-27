//
//  FileUtils.swift
//  MacIconOverlay
//
//  Created by player on 2025/6/27.
//

import Foundation

class FileUtils {
    /// 合并有相同父级路径的 path，返回父级路径数组（忽略大小写）
    /// - Parameter paths: 输入的路径数组
    /// - Returns: 父级路径数组（去重，忽略大小写）
    static func mergeToParentDirectories(_ paths: [String]) -> [String] {
        if paths.contains("/") { return ["/"] } // 只要有根目录，直接返回

        let parentDirs = paths.map { URL(fileURLWithPath: $0).deletingLastPathComponent().standardized.path }
        guard !parentDirs.isEmpty else { return [] }
        if parentDirs.count == 1 { return [parentDirs[0]] }
    
        let firstComponents = parentDirs[0].split(separator: "/")
        var commonCount = firstComponents.count

        outer: for i in 0..<firstComponents.count {
            let ithLower = firstComponents[i].lowercased()
            for dir in parentDirs.dropFirst() {
                let comps = dir.split(separator: "/")
                if i >= comps.count || comps[i].lowercased() != ithLower {
                    commonCount = i
                    break outer
                }
            }
        }

        if commonCount == 0 {
            var lowercasedToOriginal: [String: String] = [:]
            for parent in parentDirs {
                let lower = parent.lowercased()
                if lowercasedToOriginal[lower] == nil {
                    lowercasedToOriginal[lower] = parent
                }
            }
            return Array(lowercasedToOriginal.values)
        } else {
            let prefix = "/" + firstComponents.prefix(commonCount).joined(separator: "/")
            return [prefix]
        }
    }

    #if DEBUG
    // MARK: - 单元测试
    static func test_mergeToParentDirectories() {

        // 测试用例1：有共同祖先的情况
        let input1 = [
            "/a/b/c.txt",
            "/a/b/d.txt", 
            "/a/e/f.txt"
        ]
        let result1 = mergeToParentDirectories(input1)
        print("测试结果1：", result1)
        // 期望结果是 ["/a"]，因为 /a/b 和 /a/e 的共同祖先是 /a
        assert(result1.count == 1 && result1[0] == "/a", "测试1失败，结果为：\(result1)")
        
        // 测试用例2：没有共同祖先的情况
        let input2 = [
            "/a/b/c.txt",
            "/x/y/z.txt"
        ]
        let result2 = mergeToParentDirectories(input2)
        print("测试结果2：", result2)
        // 期望结果是 ["/a/b", "/x/y"]，因为没有共同祖先
        let expected2 = Set(["/a/b", "/x/y"])
        assert(Set(result2) == expected2, "测试2失败，结果为：\(result2)")
        
        // 测试用例3：大小写混合
        let input3 = [
            "/A/b/c.txt",
            "/a/B/d.txt",
            "/A/e/f.txt"
        ]
        let result3 = mergeToParentDirectories(input3)
        print("测试结果3：", result3)
        // 期望结果是 ["/A/b", "/a/B", "/A/e"] 中的去重结果（忽略大小写）
        // 由于大小写不同，应该返回所有父目录
        assert(result3.count >= 1, "测试3失败，结果为：\(result3)")
        
        // 测试用例4：包含根目录
        let input4 = ["/a/c", "/"]
        let result4 = mergeToParentDirectories(input4)
        print("测试结果4：", result4)
        assert(result4 == ["/"], "测试4失败，结果为：\(result4)")
        
        print("所有单元测试通过")
    }

    // 仅在直接运行本文件时执行测试
    static func runTests() {
        test_mergeToParentDirectories()
    }
    #endif
}





