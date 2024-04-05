import Foundation
import SwiftUI
import AVFoundation

// If the given string has the prefix, this returns the remaining characters after the prefix
func splitStringByPrefix(_ string: String, prefix: String) -> String? {
    if string.hasPrefix(prefix) {
        let index = string.index(string.startIndex, offsetBy: prefix.count)
        return String(string[index...])
    } else {
        return nil
    }
}

func getNanoseconds(_ seconds: TimeInterval) -> UInt64 {
    return UInt64(seconds * 1_000_000_000)
}

func isPreviewMode() -> Bool {
    return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

func getFileSize(url: URL) throws -> Int64 {
    let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
    guard let fileSize = fileAttributes[.size] else {
        throw getError("File \(url.absoluteString) did not have a file size attribute.")
    }
    guard let size = fileSize as? NSNumber else {
        throw getError("File \(url.absoluteString) did not have a NSNumber file size attribute.")
    }
    return size.int64Value
}

extension Sequence {
    /// Runs async tasks in parallel for each item in the sequence
    func asyncParallel(_ itemTask: @escaping (Element) async -> Void) async {
        await withTaskGroup(of: Void.self) { group in
            for element in self {
                group.addTask {
                    await itemTask(element)
                }
            }
        }
    }
    
    /// Runs async tasks in parallel for each item in the group, returning the result of each transform.  Results will map to the same indexes in the source collection
    func asyncParallelMap<T>(_ transform: @escaping (Element) async -> T) async -> [T] {
        await withTaskGroup(of: T.self) { group in
            // Add tasks to the group for each element in the sequence
            for element in self {
                group.addTask {
                    await transform(element)
                }
            }

            // Collect the results as they complete
            var results = [T]()
            for await result in group {
                results.append(result)
            }
            
            // Remove nil values if any (though in this non-throwing version, there shouldn't be any)
            return results
        }
    }
    
    
    /// Runs async tasks in parallel for each item in the group, returning the result of each transform.  Results will map to the same indexes in the source collection.  Throws if any of the transforms fail
    func asyncThrowingParallelMap<T>(_ transform: @escaping (Element) async throws -> T) async throws -> [T] {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add tasks to the group for each element in the sequence
            for element in self {
                group.addTask {
                    try await transform(element)
                }
            }
            
            // Collect the results as they complete
            var results = [T]()
            for try await result in group {
                results.append(result)
            }
            
            return results
        }
    }

}
