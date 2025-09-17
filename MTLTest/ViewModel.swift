//
//  TextureUpdater.swift
//  MTLTest
//
//  Created by Konrad Feiler on 12.09.25.
//

import Metal
import SwiftUI
import RealityKit
import Combine
import MetalKit

@Observable
class ViewModel {

    let imageName = "test_img"
    private var baseImageTexture: MTLTexture?
    private(set) var timeString: String = ""
    private var metalTexture: MTLTexture?
    private var updatableTextureEntity: Entity?
    private var blittableTextureEntity: Entity?
    private let quadScale = SIMD3<Float>(0.4, 0.4, 0.4)

    var cancellables: Set<AnyCancellable> = []

    func startUpdatingTexture() {
        let start = Date.now
        Timer.publish(every: 0.2, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] date in
                self?.metalTexture = try? self?.simulateChangingMTLTexture(time: Float(Date.now.timeIntervalSince(start)))

                if let texture = self?.metalTexture,
                   let entity = self?.updatableTextureEntity,
                   var updatableTextureComponent = entity.components[UpdatableTextureComponent.self],
                   var modelComponent = entity.components[ModelComponent.self]
                {
                    try? updatableTextureComponent.updateTexture(texture)
                    modelComponent.materials = [updatableTextureComponent.material]
                    entity.components.set(updatableTextureComponent)
                    entity.components.set(modelComponent)
                }

                if let texture = self?.metalTexture,
                   let entity = self?.blittableTextureEntity,
                   var blitTextureComponent = entity.components[BlitTextureComponent.self],
                   var modelComponent = entity.components[ModelComponent.self]
                {
                    try? blitTextureComponent.updateTexture(texture)
                    modelComponent.materials = [blitTextureComponent.material]
                    entity.components.set(blitTextureComponent)
                    entity.components.set(modelComponent)
                }
            }
            .store(in: &cancellables)
    }

    func createEntities() async -> [(Entity, String)] {
        var entities: [(Entity, String)] = []

        do {
            // simple quad
            let quad = try SimpleQuad(material: SimpleMaterial(color: UIColor.green, isMetallic: false))
            quad.scale = quadScale
            quad.position = [-0.3, 0.3, 0]
            entities.append((quad, "Simple Material"))

            // quad with texture
            var texturedMaterial = UnlitMaterial()
            let textureResource = try await TextureResource(named: imageName)
            texturedMaterial.color = .init(tint: .white, texture: .init(textureResource))
            if let textureQuad = try? SimpleQuad(material: texturedMaterial) {
                textureQuad.scale = quadScale
                entities.append((textureQuad, "Textured Quad"))
            }

            //quad with dynamic texture
            if let dynamicTextureComponent = try? await DynamicTextureComponent(textureSize: [100, 100]) {
                let textureQuad = try SimpleQuad(material: dynamicTextureComponent.material)
                textureQuad.scale = quadScale
                textureQuad.components.set(dynamicTextureComponent)
                entities.append((textureQuad, "Dynamic Texture"))
            }

            guard let device = metalDevice else { throw DynamicTextureGenerationError.metalDeviceUnavailable }
            //quad with input texture
            let textureLoader = MTKTextureLoader(device: device)
            let texture = try await textureLoader.newTexture(name: imageName, scaleFactor: 1, bundle: nil)
            baseImageTexture = texture

            // quad with single input MTLTexture, which is modified at each render step by a MTL shader
            let textureQuad = try await wavyTextureQuad()
            entities.append((textureQuad, "Wavy Texture Quad"))

            // quad where the MTLTexture is changed in size at each render step
            let updatableTextureQuad = try await updatableTextureQuad()
            entities.append((updatableTextureQuad, "Updatable Texture Quad"))
            updatableTextureEntity = updatableTextureQuad

            let blittingQuad = try await blittingQuad()
            entities.append((blittingQuad, "Blit Texture Quad"))
            blittableTextureEntity = blittingQuad

        } catch {
            print("Failed to create entities due to \(error)")
        }

        return entities
    }

    private static let computePipeline: MTLComputePipelineState? = makeComputePipeline(named: "simulateMasking")

    private static let commandQueue: MTLCommandQueue? = {
        if let metalDevice, let queue = metalDevice.makeCommandQueue() {
            queue.label = "Texture Transform Command Queue"
            return queue
        } else {
            return nil
        }
    }()

    private func wavyTextureQuad() async throws -> SimpleQuad {
        guard let baseImageTexture = baseImageTexture else {
            throw DynamicTextureGenerationError.invalidInputTexture
        }
        guard let textureComponent = try? await TextureWaveComponent(inputTexture: baseImageTexture) else {
            throw DynamicTextureGenerationError.failedToLoadTexture
        }

        let textureQuad = try SimpleQuad(material: textureComponent.material)
        textureQuad.scale = quadScale
        textureQuad.components.set(textureComponent)

        return textureQuad
    }

    private func updatableTextureQuad() async throws -> SimpleQuad {
        guard let baseImageTexture = baseImageTexture else {
            throw DynamicTextureGenerationError.invalidInputTexture
        }
        guard let textureComponent = try? await UpdatableTextureComponent(inputTexture: baseImageTexture) else {
            throw DynamicTextureGenerationError.failedToLoadTexture
        }

        let textureQuad = try SimpleQuad(material: textureComponent.material)
        textureQuad.scale = quadScale
        textureQuad.components.set(textureComponent)

        return textureQuad
    }


    private func blittingQuad() async throws -> SimpleQuad {
        guard let baseImageTexture = baseImageTexture else {
            throw DynamicTextureGenerationError.invalidInputTexture
        }
        guard let textureComponent = try? await BlitTextureComponent(inputTexture: baseImageTexture) else {
            throw DynamicTextureGenerationError.failedToLoadTexture
        }

        let textureQuad = try SimpleQuad(material: textureComponent.material)
        textureQuad.scale = quadScale
        textureQuad.components.set(textureComponent)

        return textureQuad
    }

    /// Errors that could occur during splash screen background generation.
    private enum DynamicTextureGenerationError: Error {
        case failedToLoadTexture
        case metalDeviceUnavailable
        case unableToCreateComputePipeline
        case unableToCreateEncoders
        case unableToCreateOutputTexture
        case invalidInputTexture
    }

    func simulateChangingMTLTexture(time: Float) throws -> MTLTexture {
        // Set up the Metal command buffer and compute command encoder.
        guard let commandBuffer = Self.commandQueue?.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                  throw DynamicTextureGenerationError.unableToCreateEncoders
        }

        guard let baseImageTexture else {
            throw DynamicTextureGenerationError.invalidInputTexture
        }

        // adjust size dynamically to simulate what objects changing size in a real worlds camera feed
        let newSize = SIMD2<Int>(
            Int((0.25 + 0.2 * sin(time) ) * Float(baseImageTexture.width)),
            Int((0.25 + 0.2 * sin(time) ) * Float(baseImageTexture.height))
        )

        print("Updated MTL Texture size: \(newSize.x)x\(newSize.y)")

        commandBuffer.enqueue()

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: newSize.x,
            height: newSize.y,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderWrite, .shaderRead]

        guard let outputTexture = metalDevice?.makeTexture(descriptor: textureDescriptor) else {
            throw DynamicTextureGenerationError.unableToCreateOutputTexture
        }

        defer {
            computeEncoder.endEncoding()
            commandBuffer.commit()
        }

        // Load the Metal compute pipeline corresponding with the kernel in `SplashScreenBackground.metal`.
        guard let computePipeline = Self.computePipeline else {
            throw DynamicTextureGenerationError.unableToCreateComputePipeline
        }
        computeEncoder.setComputePipelineState(computePipeline)

        // Acquire the output texture from `LowLevelTexture`, providing the command buffer.
        computeEncoder.setTexture(baseImageTexture, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)

        var mutatableTime = time
        // Pass the current time to the compute kernel to facilitate animation.
        computeEncoder.setBytes(&mutatableTime, length: MemoryLayout<Float>.size, index: 0)

        // Compute the thread and group size for threadgroup dispatch.
        let threadGroupSizePerDimension = 16
        let threadGroupCountPerDimension = (newSize &+ (threadGroupSizePerDimension - 1)) / threadGroupSizePerDimension

        let threadGroupSize = MTLSize(width: threadGroupSizePerDimension,
                                      height: threadGroupSizePerDimension,
                                      depth: 1)
        let threadGroupCount = MTLSize(width: threadGroupCountPerDimension.x,
                                       height: threadGroupCountPerDimension.y,
                                       depth: 1)

        // Dispatch the compute work.
        computeEncoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)

        return outputTexture
    }

}
