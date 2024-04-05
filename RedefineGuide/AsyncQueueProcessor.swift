import Foundation
import os.log

fileprivate struct SignpostInfo {
    let signpostName: StaticString
    let signposter: OSSignposter
    let signpostID: OSSignpostID
    
    func emitQueueDepthEvent(_ depth: Int) {
        let depth = String(format: "%06d", depth)
        signposter.emitEvent(signpostName, id: signpostID, "\(depth)")
    }
}

/// A generic asynchronous queue processor that supports adding items to a queue and processing them asynchronously.
/// todo: mapSize is cool for 1, but if you have, say, 10, then you get chunks.  could be nice to space things out somehow.
/// todo: add a cancel() async that will stop runTask and clear the queue
public class AsyncQueueProcessor<T> {
    private let queue = ThreadSafeQueue<T>()
    private var isRunning: Bool = false
    private var sleepTimeMs: UInt64
    private var sleepTimeNanoseconds: UInt64
    private let processItemsFn: ([T]) async -> Void
    private let stopFn: () async -> Void
    private let stateQueue = DispatchQueue(label: "com.redefine.AsyncQueueProcessor.state")
    private var runTask: Task<Void, Never>?
    private var maxSize: Int
    private let signpostInfo: SignpostInfo?

    /// Initializes a new `AsyncQueueProcessor` with the specified processing and stopping closures.
    /// - Parameters:
    ///   - sleepTimeMs: The time to sleep between checks of the queue when it's empty, in milliseconds.
    ///   - signpostName: The name given to the OS signposter that is used to track queue processing using Instruments
    ///   - maxSize: When items are added, if the current queue size is >= this value, then the item will be ignored.  This avoids a queue growing out of control and consuming too much system memory, leading to a crash.  Only enabled when > 0
    ///   - processItems: A closure that processes an array of items from the queue.
    ///   - stop: A closure that is called when the processor stops.
    public init(sleepTimeMs: UInt64 = 10, signpostName: StaticString? = nil, maxSize: Int = -1, processItems: @escaping ([T]) async -> Void, stop: @escaping () async -> Void = {}) {
        self.sleepTimeMs = sleepTimeMs
        self.sleepTimeNanoseconds = sleepTimeMs * 1_000_000
        self.processItemsFn = processItems
        self.stopFn = stop
        self.maxSize = maxSize
        if let signpostName = signpostName {
            let signposter = OSSignposter(subsystem: "com.redefine.capture", category: "QueueDepth")
            self.signpostInfo = SignpostInfo(signpostName: signpostName, signposter: signposter, signpostID: signposter.makeSignpostID())
        } else {
            self.signpostInfo = nil
        }
    }
    
    /// Returns the current size of the queue.  Useful when checking for memory bloat
    public var queueSize: Int {
        self.queue.count
    }
    
    /// Adds an item to the queue for processing. If the processor is not running, the item will be ignored.
    /// - Parameter item: The item to add to the queue.
    public func add(_ item: T, _ onAdded: (() -> Void)? = nil) {
        guard self.isRunning else {
            return
        }
        stateQueue.async {
            if self.maxSize <= 0 || self.queue.count < self.maxSize {
                self.queue.enqueue(item)
                if let signpost = self.signpostInfo {
                    signpost.emitQueueDepthEvent(self.queue.count)
                }
                onAdded?()
            }
        }
    }

    
    /// Starts processing items from the queue asynchronously. If already running, this method does nothing.
    public func start() {
        stateQueue.sync {
            guard !self.isRunning else { return }
            self.isRunning = true
        }
        
        runTask = Task {
            await self.run()
        }
    }
    
    /// The core loop for processing items from the queue. This runs as a task started by `start()`.
    private func run() async {
        var loop = true
        while loop {
            stateQueue.sync {
                loop = self.isRunning
            }

            if loop {
                if queue.isEmpty {
                    try? await Task.sleep(nanoseconds: sleepTimeNanoseconds)
                } else {
                    let items = self.queue.dequeueAll()
                    await processItems(items)
                }
            }
        }

        // Final processing to ensure no items are left unprocessed.
        let items = self.queue.dequeueAll()
        if !items.isEmpty {
            await processItems(items)
        }

        await stopFn()
    }
    
    private func processItems(_ items: [T]) async {
        guard !items.isEmpty else {
            return
        }
        if let signpost = self.signpostInfo {
            let count = String(format: "%06d", items.count)
            
            let signpostState = signpost.signposter.beginInterval("ProcessItems", id: signpost.signpostID)

            await processItemsFn(items)

            let formatted = String(format: "%08d", count)
            signpost.signposter.endInterval("ProcessItems", signpostState, "\(formatted)")
            signpost.emitQueueDepthEvent(self.queue.count)
        } else {
            await processItemsFn(items)
        }
    }
    
    /// Stops the processor from processing any more items and calls the stop closure.
    /// If already stopped, this method does nothing.
    public func stop() async {
        let shouldStop = stateQueue.sync { () -> Bool in
            guard self.isRunning else { return false }
            self.isRunning = false
            return true
        }

        guard shouldStop else {
            return
        }
        guard let runTask = self.runTask else {
            return
        }
        await runTask.value
    }
}
