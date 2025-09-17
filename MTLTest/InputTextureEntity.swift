//
//  InputTextureEntity.swift
//  MTLTest
//
//  Created by Konrad Feiler on 12.09.25.
//

import RealityKit
import MetalKit

struct InputTextureEntity {

    /// Errors that could occur during splash screen background generation.
    private enum InputTextureEntityError: Error {
        case metalDeviceUnavailable
        case failedToLoadTexture
    }

    static func make(with imageName: String) async throws -> SimpleQuad {
        guard let device = metalDevice else { throw InputTextureEntityError.metalDeviceUnavailable }
        //quad with input texture
        let textureLoader = MTKTextureLoader(device: device)
        let texture = try await textureLoader.newTexture(name: imageName, scaleFactor: 1, bundle: nil)

        print("loading texture sized \(texture.width)x\(texture.height)")
        guard let textureComponent = try? await TextureWaveComponent(inputTexture: texture) else {
//        guard let textureComponent = try? await DynamicTextureComponent(textureSize: [texture.width, texture.height]) else {
            throw InputTextureEntityError.failedToLoadTexture
        }

        let textureQuad = try SimpleQuad(material: textureComponent.material)
        textureQuad.scale = SIMD3(0.2, 0.2, 0.2)
        textureQuad.components.set(textureComponent)

        return textureQuad
    }
}
