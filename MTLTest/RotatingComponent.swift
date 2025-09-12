import RealityKit
import Foundation

/// A component that marks an entity to be rotated by the RotatingSystem.
struct RotatingComponent: Component {
    var speed: Float // radians per second
    var axis: SIMD3<Float> = [0, 1, 0] // Default: Y axis
}
