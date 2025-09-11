//
//  Quad.swift
//  MTLTest
//
//  Created by Konrad Feiler on 11.09.25.
//

import SwiftUI
import RealityKit

public class SimpleQuad: Entity, HasModel {

    required init(material: RealityKit.Material) throws {

        super.init()

        let newMesh = try MeshResource.generateQuad(from: [
            SIMD3<Float>(-0.5, -0.5, 0.0),
            SIMD3<Float>(0.5, -0.5, 0.0),
            SIMD3<Float>(0.5, 0.5, 0.0),
            SIMD3<Float>(-0.5, 0.5, 0.0),
        ])

        let meshComponent = ModelComponent(
            mesh: newMesh,
            materials: [material]
        )

        components[ModelComponent.self] = meshComponent
    }
    
    @MainActor @preconcurrency required init() {
        fatalError("init() has not been implemented")
    }
}

extension MeshResource {
    static func generateQuad(from corners: [SIMD3<Float>]) throws -> MeshResource {
        let bottomLeft = corners[0]
        let bottomRight = corners[1]
        let topRight = corners[2]
        let topLeft = corners[3]

        // Create vertices for the quad (two triangles)
        // Triangle 1: bottomLeft -> bottomRight -> topLeft
        // Triangle 2: bottomRight -> topRight -> topLeft
        let vertices: [SIMD3<Float>] = [
            bottomLeft,   // 0
            bottomRight,  // 1
            topLeft,      // 2
            topRight      // 3
        ]

        // Define triangles using vertex indices
        let indices: [UInt32] = [
            0, 1, 2,  // First triangle: bottomLeft -> bottomRight -> topLeft
            1, 3, 2   // Second triangle: bottomRight -> topRight -> topLeft
        ]

        // Create UV coordinates for texture mapping
        let uvs: [SIMD2<Float>] = [
            SIMD2<Float>(0, 0),  // bottomLeft
            SIMD2<Float>(1, 0),  // bottomRight
            SIMD2<Float>(0, 1),  // topLeft
            SIMD2<Float>(1, 1)   // topRight
        ]

        // Create the mesh
        var meshDescriptor = MeshDescriptor(name: "TrackerQuad")
        meshDescriptor.positions = MeshBuffers.Positions(vertices)
        meshDescriptor.primitives = .triangles(indices)
        meshDescriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)

        return try MeshResource.generate(from: [meshDescriptor])
    }
}
