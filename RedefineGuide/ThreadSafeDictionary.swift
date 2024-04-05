//
//  ThreadSafeDictionary.swift
//  RedefineCapture
//
//  Created by Stephen Potter on 2/26/24.
//

import Foundation

class ThreadSafeDictionary<Key: Hashable, Value> {
    private var dictionary: [Key: Value] = [:]
    private let accessQueue = DispatchQueue(label: "com.redefine.threadSafeDictionary", attributes: .concurrent)

    // Method to safely update or add a key-value pair
    func updateValue(_ value: Value, forKey key: Key) {
        accessQueue.async(flags: .barrier) {
            self.dictionary[key] = value
        }
    }

    // Method to safely remove a key-value pair
    func removeValue(forKey key: Key) {
        accessQueue.async(flags: .barrier) {
            self.dictionary.removeValue(forKey: key)
        }
    }

    // Method to safely retrieve a value for a key
    func value(forKey key: Key) -> Value? {
        var value: Value?
        accessQueue.sync {
            value = self.dictionary[key]
        }
        return value
    }

    // Method to safely access all key-value pairs
    func getAll() -> [Key: Value] {
        var dictCopy: [Key: Value] = [:]
        accessQueue.sync {
            dictCopy = self.dictionary
        }
        return dictCopy
    }
    
    // Computed property to safely access all values
    var values: [Value] {
        var allValues: [Value] = []
        accessQueue.sync {
            allValues = Array(self.dictionary.values)
        }
        return allValues
    }
    
    // Subscript for accessing and modifying dictionary values by key
    subscript(key: Key) -> Value? {
        get {
            var value: Value?
            accessQueue.sync {
                value = self.dictionary[key]
            }
            return value
        }
        set(newValue) {
            accessQueue.async(flags: .barrier) {
                if let newValue = newValue {
                    self.dictionary[key] = newValue
                } else {
                    self.dictionary.removeValue(forKey: key)
                }
            }
        }
    }
}
