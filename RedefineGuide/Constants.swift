import Foundation

let nanosecondsPerSecond: UInt64 = 1_000_000_000
let nanosecondsPerMillisecond: UInt64 = 1_000_000

fileprivate let serverUrl = "https://07fb-13-58-106-62.ngrok-free.app"

func getServerUrl() -> String {
    return removeTrailingSlash(serverUrl)
}

func removeTrailingSlash(_ string: String) -> String {
    guard string.hasSuffix("/") else { return string }
    return String(string.dropLast())
}
