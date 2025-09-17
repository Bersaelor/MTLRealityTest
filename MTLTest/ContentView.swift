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

    @State private var viewModel = ViewModel()

    var body: some View {
        RealityView { content in
            RotatingSystem.registerSystem()
            DynamicTextureSystem.registerSystem()
            TextureWaveSystem.registerSystem()

            let rootNode = Entity()
            content.add(rootNode)
            // rotate in opposite direction then the nodes
            rootNode.transform.rotation = .init(angle: -0.5, axis: [1, 0, 0])
            rootNode.components.set(RotatingComponent(speed: -rotationSpeed, axis: [0, 0, 1]))

            let testObjects = await viewModel.createEntities()

            // Arrange testObjects in a circle around the z-axis
            let radius: Float = 0.5
            let center = SIMD3<Float>(0, 0, 0)
            let count = testObjects.count
            for (i, tuple) in testObjects.enumerated() {
                let entity = tuple.0
                let angle = Float(i) / Float(max(count,1)) * 2 * .pi
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                let z = center.z
                entity.position = [x, y, z]
                entity.components.set(RotatingComponent(speed: rotationSpeed, axis: [0.05, 0, 1.0]))
                rootNode.addChild(entity)

                // add text label above the entity
                let textEntity = ModelEntity(mesh: .generateText(
                    tuple.1,
                    extrusionDepth: 0.01,
                    font: .systemFont(ofSize: 0.1),
                    containerFrame: .zero,
                    alignment: .center,
                    lineBreakMode: .byWordWrapping
                ), materials: [SimpleMaterial(color: .red, isMetallic: false)])
                textEntity.position = [0, 0, 0.15]
                textEntity.scale = [0.75, 0.75, 0.75]
                entity.addChild(textEntity)
            }
        }
        .realityViewCameraControls(CameraControls.orbit)
        .overlay {
            VStack {
                HStack {
                    Text(viewModel.timeString)

                    Spacer()
                }

                Spacer()
            }
        }
        .onAppear {
            viewModel.startUpdatingTexture()
        }
    }
}

#Preview {
    ContentView()
}
