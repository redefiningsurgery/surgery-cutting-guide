import Foundation

let nanosecondsPerSecond: UInt64 = 1_000_000_000
let nanosecondsPerMillisecond: UInt64 = 1_000_000

fileprivate let serverUrl = "https://d37d-3-21-181-191.ngrok-free.app"

func getServerUrl() -> String {
    return removeTrailingSlash(serverUrl)
}

func removeTrailingSlash(_ string: String) -> String {
    guard string.hasSuffix("/") else { return string }
    return String(string.dropLast())
}
