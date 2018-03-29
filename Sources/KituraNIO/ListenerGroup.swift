import Dispatch

/// A class that provides a set of helper functions that enables a caller to wait
/// for a group of listener blocks to finish executing.
public class ListenerGroup {
    
    /// Group for waiting on listeners
    private static let group = DispatchGroup()

    /// Wait for all of the listeners to stop
    public static func waitForListeners() {
        _ = group.wait(timeout: DispatchTime.distantFuture)
    }
    
    /// Enqueue a block of code on a given queue, assigning
    /// it to the listener group in the process (so we can wait
    /// on it later).
    ///
    /// - Parameter on: The queue on to which the provided block will be enqueued
    ///                for asynchronous execution.
    /// - Parameter block: The block to be enqueued for asynchronous execution.
    public static func enqueueAsynchronously(on queue: DispatchQueue, block: DispatchWorkItem) {
        queue.async(group: ListenerGroup.group, execute: block)
    }
    
}
