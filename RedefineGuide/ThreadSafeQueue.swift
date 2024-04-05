//
//  ThreadSafeQueue.swift
//  RedefineCapture
//
//  Created by Stephen Potter on 2/22/24.
//

import Foundation

/// A thread-safe queue class that allows concurrent reading and exclusive writing.
public class ThreadSafeQueue<T> {
    private var queue = [T]()
    private let dispatchQueue = DispatchQueue(label: "com.redefine.threadsafequeue", attributes: .concurrent)

    /// Initializes a new empty `ThreadSafeQueue`.
    public init() {}

    /// Enqueues an element to the end of the queue in a thread-safe manner.
    /// - Parameter element: The element to be added to the queue.
    public func enqueue(_ element: T) {
        dispatchQueue.async(flags: .barrier) {
            self.queue.append(element)
        }
    }

    /// Dequeues the first element from the queue in a thread-safe manner.
    /// - Returns: The dequeued element if the queue is not empty; otherwise, `nil`.
    public func dequeue() -> T? {
        var element: T?
        dispatchQueue.sync {
            if !self.queue.isEmpty {
                element = self.queue.removeFirst()
            }
        }
        return element
    }

    /// Dequeues all elements from the queue in a thread-safe manner.
    /// - Returns: An array of dequeued elements. Returns an empty array if the queue is empty.
    public func dequeueAll() -> [T] {
        var elements: [T] = []
        dispatchQueue.sync(flags: .barrier) {
            elements = self.queue
            self.queue.removeAll()
        }
        return elements
    }

    /// A Boolean value indicating whether the queue is empty.
    /// Access is thread-safe.
    public var isEmpty: Bool {
        dispatchQueue.sync {
            self.queue.isEmpty
        }
    }

    /// The number of elements in the queue.
    /// Access is thread-safe.
    public var count: Int {
        dispatchQueue.sync {
            self.queue.count
        }
    }
}
