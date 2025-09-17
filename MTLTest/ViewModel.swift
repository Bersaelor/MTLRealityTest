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
    private(set) var metalTexture: MTLTexture?

    var cancellables: Set<AnyCancellable> = []

    func startUpdatingTexture() {
        let start = Date.now
        Timer.publish(every: 0.2, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] date in
                self?.metalTexture = try? self?.simulateChangingMTLTexture(time: Float(Date.now.timeIntervalSince(start)))
            }
            .store(in: &cancellables)
    }

    func createEntities() async -> [Entity] {
        var entities: [Entity] = []

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
            let textureQuad = try await make(with: imageName)
            entities.append(textureQuad)
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

    func make(with imageName: String) async throws -> SimpleQuad {
        guard let device = metalDevice else { throw DynamicTextureGenerationError.metalDeviceUnavailable }
        //quad with input texture
        let textureLoader = MTKTextureLoader(device: device)
        let texture = try await textureLoader.newTexture(name: imageName, scaleFactor: 1, bundle: nil)

        baseImageTexture = texture

        print("loading texture sized \(texture.width)x\(texture.height)")
        guard let textureComponent = try? await TextureTransformComponent(inputTexture: texture) else {
            throw DynamicTextureGenerationError.failedToLoadTexture
        }

        let textureQuad = try SimpleQuad(material: textureComponent.material)
        textureQuad.scale = SIMD3(0.2, 0.2, 0.2)
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
            Int((0.75 + 0.25 * sin(time) ) * Float(baseImageTexture.width)),
            Int((0.75 + 0.25 * cos(time) ) * Float(baseImageTexture.height))
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
