//
//  ContentView.swift
//  MTLTest
//
//  Created by Konrad Feiler on 11.09.25.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    var body: some View {
        RealityView { content in
            let rootNode = Entity()
            content.add(rootNode)

            // simple cube
            let cube = Entity()
            let mesh = MeshResource.generateBox(size: 0.1, cornerRadius: 0.005)
            let material = SimpleMaterial(color: .blue, roughness: 0.15, isMetallic: false)
            cube.components.set(ModelComponent(mesh: mesh, materials: [material]))
            cube.position = [-0.5, 0.05, 0]
            rootNode.addChild(cube)

            // simple quad
            if let quad = try? SimpleQuad(material: SimpleMaterial(color: UIColor.green, isMetallic: false)) {
                quad.scale = SIMD3(0.2, 0.2, 0.2)
                quad.position = [-0.3, 0.3, 0]
                rootNode.addChild(quad)
            }

            // quad with texture
            var texturedMaterial = UnlitMaterial()
            guard let textureResource = try? await TextureResource(named: "test_img") else {
                print("Can't find test_img")
                return
            }
            texturedMaterial.color = .init(tint: .white, texture: .init(textureResource))
            guard let textureQuad = try? SimpleQuad(material: texturedMaterial) else {
                print("Failed to create textureQuad")
                return
            }
            textureQuad.scale = SIMD3(0.2, 0.2, 0.2)
            textureQuad.position = [0, 0.5, 0]
            rootNode.addChild(textureQuad)
        }
        .realityViewCameraControls(CameraControls.orbit)
    }
}

#Preview {
    ContentView()
}
