// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if SKIP

import Foundation

extension NotificationCenter {
    /// Returns a publisher that emits notifications matching the specified name and object.
    ///
    /// - Parameters:
    ///   - name: The notification name to observe.
    ///   - object: The optional object whose notifications should be observed.
    /// - Returns: A publisher that emits matching notifications.
    public func publisher(for name: Notification.Name, object: AnyObject? = nil) -> Publisher<Notification, Never> {
        let publisher = NotificationCenterPublisher(center: self)
        publisher.observer = addObserver(forName: name, object: object, queue: nil) {
            publisher.send($0)
        }
        return publisher
    }
}

private final class NotificationCenterPublisher: Publisher {
    typealias Output = Notification
    typealias Failure = Never

    private let center: NotificationCenter
    private let helper: SubjectHelper<Notification, Never> = SubjectHelper<Notification, Never>()
    var observer: Any?

    /// Initializes a new instance of the `NotificationCenterPublisher` class.
    ///
    /// - Parameter center: The notification center to observe.
    init(center: NotificationCenter) {
        self.center = center
    }

    deinit {
        if let observer {
            center.removeObserver(observer)
        }
    }

    /// Attaches a subscriber to receive notifications emitted by this publisher.
    ///
    /// - Parameter receiveValue: The closure invoked for each notification.
    /// - Returns: A cancellable subscription.
    func sink(receiveValue: (Notification) -> Void) -> AnyCancellable {
        let internalCancellable = helper.sink(receiveValue)
        let referencingCancellable = ReferencingCancellable(publisher: self, cancellable: internalCancellable)
        return AnyCancellable(referencingCancellable)
    }

    /// Sends the specified notification to all subscribers.
    ///
    /// - Parameter notification: The notification to publish.
    func send(notification: Notification) {
        helper.send(notification)
    }
}

/// Cancellable that references the producing publisher.
///
/// The publisher will deregister from the notification center only when it finalizes after all these references are gone.
private final class ReferencingCancellable: Cancellable {
    private var publisher: NotificationCenterPublisher?
    private let cancellable: Cancellable

    /// Initializes a new instance of the `ReferencingCancellable` class.
    ///
    /// - Parameters:
    ///   - publisher: The publisher retained for the lifetime of the subscription.
    ///   - cancellable: The wrapped cancellable subscription.
    init(publisher: NotificationCenterPublisher?, cancellable: Cancellable) {
        self.publisher = publisher
        self.cancellable = cancellable
    }

    /// Cancels the subscription and releases the referenced publisher.
    func cancel() {
        publisher = nil
        cancellable.cancel()
    }
}

#elseif os(Android)

import Foundation

extension NotificationCenter {
    /// Returns a publisher that emits notifications matching the specified name and object.
    ///
    /// - Parameters:
    ///   - name: The notification name to observe.
    ///   - object: The optional object whose notifications should be observed.
    /// - Returns: A publisher that emits matching notifications.
    public func publisher(for name: Notification.Name, object: AnyObject? = nil) -> AnyPublisher<Notification, Never> {
        let publisher = NotificationCenterPublisher(center: self)
        publisher.observer = addObserver(forName: name, object: object, queue: nil) {
            publisher.send($0)
        }
        return publisher.eraseToAnyPublisher()
    }
}

private final class NotificationCenterPublisher: @unchecked Sendable {
    private let center: NotificationCenter
    private let subject = PassthroughSubject<Notification, Never>()
    var observer: Any?

    /// Initializes a new instance of the `NotificationCenterPublisher` class.
    ///
    /// - Parameter center: The notification center to observe.
    init(center: NotificationCenter) {
        self.center = center
    }

    deinit {
        if let observer {
            center.removeObserver(observer)
        }
    }

    /// Erases this publisher to an `AnyPublisher`.
    ///
    /// - Returns: A type-erased publisher that emits matching notifications.
    func eraseToAnyPublisher() -> AnyPublisher<Notification, Never> {
        AnyPublisher { [self] receiveValue in
            let subjectCancellable = self.subject.sink(receiveValue: receiveValue)
            return AnyCancellable {
                subjectCancellable.cancel()
                _ = self
            }
        }
    }

    /// Sends the specified notification to all subscribers.
    ///
    /// - Parameter notification: The notification to publish.
    func send(_ notification: Notification) {
        self.subject.send(notification)
    }
}

#endif
