import Foundation

let nanosecondsPerSecond: UInt64 = 1_000_000_000
let nanosecondsPerMillisecond: UInt64 = 1_000_000

// Just for testing purposes.  If set to > 0, this will stop the tracking after this many frames.  For example, if you set this to 1, it will do just a single frame
let maxTrackingFrames = 1

func getServerUrl() -> String {
    return removeTrailingSlash(Settings.shared.devServerUrl)
}

func removeTrailingSlash(_ string: String) -> String {
    guard string.hasSuffix("/") else { return string }
    return String(string.dropLast())
}
