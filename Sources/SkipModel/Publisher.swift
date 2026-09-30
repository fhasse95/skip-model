// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
// SKIP SYMBOLFILE

#if SKIP

import Foundation

public protocol Publisher<Output, Failure> {
    associatedtype Output
    associatedtype Failure
}

extension Publisher {
    public func sink(receiveValue: @escaping (Output) -> Void) -> AnyCancellable {
        fatalError()
    }

    public func assign<Root>(to keyPath: (Root, Output) -> Void, on object: Root) -> AnyCancellable {
        fatalError()
    }

    public func combineLatest<P>(_ publisher: Publisher<P, Failure>) -> Publisher<(Output, P), Failure> {
        fatalError()
    }

    public func combineLatest3<P0, P1>(_ publisher0: Publisher<P0, Failure>, _ publisher1: Publisher<P1, Failure>) -> Publisher<(Output, P0, P1), Failure> {
        fatalError()
    }

    public func combineLatest4<P0, P1, P2>(_ publisher0: Publisher<P0, Failure>, _ publisher1: Publisher<P1, Failure>, _ publisher2: Publisher<P2, Failure>) -> Publisher<(Output, P0, P1, P2), Failure> {
        fatalError()
    }

    public func debounce(for dueTime: Double, scheduler: Scheduler) -> Publisher<Output, Failure> {
        fatalError()
    }

    public func dropFirst(_ count: Int = 1) -> Publisher<Output, Failure> {
        fatalError()
    }

    public func filter(_ isIncluded: (Output) throws -> Bool) rethrows -> Publisher<Output, Failure> {
        fatalError()
    }

    public func map<T>(_ transform: (Output) throws -> T) rethrows -> Publisher<T, Failure> {
        fatalError()
    }

    public func receive(on scheduler: Scheduler) -> Publisher<Output, Failure> {
        fatalError()
    }

    public func eraseToAnyPublisher() -> AnyPublisher<Output, Failure> {
        fatalError()
    }
}

public final class AnyPublisher : Publisher {
    public init(_ publisher: Publisher<Output, Failure>) {
        fatalError()
    }
}

public protocol ConnectablePublisher<Output, Failure> : Publisher {
    func connect() -> Cancellable
    func autoconnect() -> Publisher<Output, Failure>
}

public protocol Subject<Output, Failure> : AnyObject, Publisher {
    func send(_ value: Output)
}

public final class PassthroughSubject<Output, Failure> : Subject {
    public init() {
    }

    public func send(_ input: Output) {
    }
}

public final class ObservableObjectPublisher : Publisher {
    public typealias Output = Void
    public typealias Failure = Never

    public init() {
    }

    public func send() {
    }
}

#elseif os(Android)

import Dispatch
import Foundation

public protocol Publisher<Output, Failure> {
    associatedtype Output
    associatedtype Failure

    func sink(receiveValue: @escaping (Output) -> Void) -> AnyCancellable
}

public protocol Subject<Output, Failure>: AnyObject, Publisher {
    func send(_ value: Output)
}

private final class PublisherSendableBox<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

public extension Publisher {
    func dropFirst(_ count: Int = 1) -> AnyPublisher<Output, Failure> {
        AnyPublisher { receiveValue in
            let lock = NSLock()
            var remainingCount = count

            return self.sink { value in
                lock.lock()
                defer { lock.unlock() }

                if remainingCount > 0 {
                    remainingCount -= 1
                } else {
                    receiveValue(value)
                }
            }
        }
    }
}

public final class AnyPublisher<Output, Failure>: Publisher, @unchecked Sendable {
    private let subscribeHandler: (@escaping (Output) -> Void) -> AnyCancellable

    public init(_ subscribeHandler: @escaping (@escaping (Output) -> Void) -> AnyCancellable) {
        self.subscribeHandler = subscribeHandler
    }

    public func sink(receiveValue: @escaping (Output) -> Void) -> AnyCancellable {
        self.subscribeHandler(receiveValue)
    }

    public func receive(on queue: DispatchQueue) -> AnyPublisher<Output, Failure> {
        AnyPublisher { receiveValue in
            let receiveValueBox = PublisherSendableBox(receiveValue)
            return self.sink { value in
                let valueBox = PublisherSendableBox(value)
                queue.async {
                    receiveValueBox.value(valueBox.value)
                }
            }
        }
    }

    public func eraseToAnyPublisher() -> AnyPublisher<Output, Failure> {
        self
    }
}

public final class PassthroughSubject<Output, Failure>: Subject, @unchecked Sendable {
    private let lock = NSLock()
    private var subscribers = [UUID: (Output) -> Void]()

    public init() {}

    public func sink(receiveValue: @escaping (Output) -> Void) -> AnyCancellable {
        let id = UUID()

        self.lock.lock()
        self.subscribers[id] = receiveValue
        self.lock.unlock()

        return AnyCancellable { [weak self] in
            self?.removeSubscriber(id)
        }
    }

    public func receive(on queue: DispatchQueue) -> AnyPublisher<Output, Failure> {
        self.eraseToAnyPublisher().receive(on: queue)
    }

    public func eraseToAnyPublisher() -> AnyPublisher<Output, Failure> {
        AnyPublisher { receiveValue in
            self.sink(receiveValue: receiveValue)
        }
    }

    public func send(_ value: Output) {
        self.lock.lock()
        let subscribers = Array(self.subscribers.values)
        self.lock.unlock()

        for subscriber in subscribers {
            subscriber(value)
        }
    }

    private func removeSubscriber(_ id: UUID) {
        self.lock.lock()
        self.subscribers[id] = nil
        self.lock.unlock()
    }
}

public final class ObservableObjectPublisher: Publisher, @unchecked Sendable {
    public typealias Output = Void
    public typealias Failure = Never

    private let subject = PassthroughSubject<Void, Never>()

    public init() {}

    public func sink(receiveValue: @escaping (()) -> Void) -> AnyCancellable {
        self.subject.sink(receiveValue: receiveValue)
    }

    public func send() {
        self.subject.send(())
    }
}

#endif
