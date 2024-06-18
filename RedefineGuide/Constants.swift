import Foundation

let nanosecondsPerSecond: UInt64 = 1_000_000_000
let nanosecondsPerMillisecond: UInt64 = 1_000_000

func getNanoseconds(seconds: Double) -> UInt64 {
    return UInt64(seconds * Double(nanosecondsPerSecond))
}

func getServerUrl() -> String {
    return removeTrailingSlash(Settings.shared.devServerUrl)
}

func removeTrailingSlash(_ string: String) -> String {
    guard string.hasSuffix("/") else { return string }
    return String(string.dropLast())
}
