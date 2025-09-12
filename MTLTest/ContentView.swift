//
//  ContentView.swift
//  MTLTest
//
//  Created by Konrad Feiler on 11.09.25.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    let rotationSpeed: Float = 0.2

    var body: some View {
        RealityView { content in
            RotatingSystem.registerSystem()
            DynamicTextureSystem.registerSystem()
            TextureTransformSystem.registerSystem()

            let rootNode = Entity()
            content.add(rootNode)
            // rotate in opposite direction then the nodes
            rootNode.transform.rotation = .init(angle: -0.5, axis: [1, 0, 0])
            rootNode.components.set(RotatingComponent(speed: -rotationSpeed, axis: [0, 0, 1]))

            let testObjects = await createEntities()

            // Arrange testObjects in a circle around the z-axis
            let radius: Float = 0.5
            let center = SIMD3<Float>(0, 0, 0)
            let count = testObjects.count
            for (i, entity) in testObjects.enumerated() {
                let angle = Float(i) / Float(max(count,1)) * 2 * .pi
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                let z = center.z
                entity.position = [x, y, z]
                entity.components.set(RotatingComponent(speed: rotationSpeed, axis: [0.05, 0, 1.0]))
                rootNode.addChild(entity)
            }
        }
        .realityViewCameraControls(CameraControls.orbit)
    }

    private func createEntities() async -> [Entity] {
        var entities: [Entity] = []

        let imageName = "test_img"

        do {
            // simple quad
            let quad = try SimpleQuad(material: SimpleMaterial(color: UIColor.green, isMetallic: false))
            quad.scale = SIMD3(0.2, 0.2, 0.2)
            quad.position = [-0.3, 0.3, 0]
            entities.append(quad)

            // quad with texture
            var texturedMaterial = UnlitMaterial()
            let textureResource = try await TextureResource(named: imageName)
            texturedMaterial.color = .init(tint: .white, texture: .init(textureResource))
            if let textureQuad = try? SimpleQuad(material: texturedMaterial) {
                textureQuad.scale = SIMD3(0.2, 0.2, 0.2)
                entities.append(textureQuad)
            }

            //quad with dynamic texture
            if let dynamicTextureComponent = try? await DynamicTextureComponent(textureSize: [100, 100]) {
                let textureQuad = try SimpleQuad(material: dynamicTextureComponent.material)
                textureQuad.scale = SIMD3(0.2, 0.2, 0.2)
                textureQuad.components.set(dynamicTextureComponent)
                entities.append(textureQuad)
            }

            //quad with input texture
            let textureQuad = try await InputTextureEntity.make(with: imageName)
            entities.append(textureQuad)
        } catch {
            print("Failed to create entities due to \(error)")
        }


        return entities
    }
}

#Preview {
    ContentView()
}
