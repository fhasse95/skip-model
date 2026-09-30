// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if SKIP

/// Kotlin representation of `Observation.Observable`.
public protocol Observable {
}

/// Kotlin representation of `Combine.ObservableObject`.
public protocol ObservableObject {
    var objectWillChange: ObservableObjectPublisher { get }
}

#elseif os(Android)

/// Native Android counterpart for Observation-style models in Fuse builds.
public protocol Observable {
}

/// Minimal Combine-compatible marker used by SwiftUI-style model code in Fuse builds.
public protocol ObservableObject {
    var objectWillChange: ObservableObjectPublisher { get }
}

public extension ObservableObject {
    var objectWillChange: ObservableObjectPublisher {
        ObservableObjectPublisher()
    }
}

#endif
