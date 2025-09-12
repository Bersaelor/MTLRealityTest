import RealityKit
import Foundation

/// A system that rotates entities with a RotatingComponent.
class RotatingSystem: System {
    required init(scene: Scene) {}
    
    static let query = EntityQuery(where: .has(RotatingComponent.self))
    
    func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)
        for entity in context.scene.performQuery(Self.query) {
            guard var rotating = entity.components[RotatingComponent.self] as? RotatingComponent else { continue }
            let rotation = simd_quatf(angle: rotating.speed * deltaTime, axis: rotating.axis)
            entity.transform.rotation = rotation * entity.transform.rotation
        }
    }
}
