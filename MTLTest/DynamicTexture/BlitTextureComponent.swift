
/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A RealityKit component and system used to facilitate the background of the
  splash screen. The splash screen background is a RealityKit entity that
  updates a `LowLevelTexture` every frame and displays it using
  a `ShaderGraphMaterial`.
*/

import RealityKit
import Metal

/// Dynamic texture that takes a static input texture and transforms it over time
struct BlitTextureComponent: TransientComponent {
    private static let commandQueue: MTLCommandQueue? = {
        if let metalDevice, let queue = metalDevice.makeCommandQueue() {
            queue.label = "Texture Transform Command Queue"
            return queue
        } else {
            return nil
        }
    }()

    private(set) var lowLevelTexture: LowLevelTexture

    /// The size of `lowLevelTexture`.
    @MainActor
    private var textureSize: SIMD2<Int> {
        let descriptor = lowLevelTexture.descriptor
        return [descriptor.width, descriptor.height]
    }
    
    /// The `Date` at which the splash screen first appeared.
    private let spawnDate: Date

    private var inputTexture: MTLTexture

    /// The RealityKit material to use when rendering the background.
    private(set) var material: RealityKit.UnlitMaterial

    /// Errors that could occur during splash screen background generation.
    private enum DynamicTextureGenerationError: Error {
        case unableToCreateComputePipeline
        case unableToCreateEncoders
        case unableToCreateNoiseTexture
        case invalidInputTexture
    }
    
    /// Generate a `LowLevelTexture` suitable to be populated for the splash screen background.
    ///
    /// - Parameters:
    ///   - width: The width of the texture.
    ///   - height: The height of the texture.
    @MainActor
    private static func generateTexture(width: Int, height: Int) throws -> LowLevelTexture {
        return try LowLevelTexture(descriptor: .init(pixelFormat: .rgba8Unorm,
                                                     width: width,
                                                     height: height,
                                                     depth: 1,
                                                     mipmapLevelCount: 1,
                                                     textureUsage: [.shaderWrite, .shaderRead]))
    }

    /// Initializes the splash screen background to a texture with the provided resolution.
    @MainActor
    init(inputTexture: MTLTexture) async throws {
        spawnDate = Date.now

        guard validateMTLTexture(inputTexture) else {
            throw DynamicTextureGenerationError.invalidInputTexture
        }

        self.inputTexture = inputTexture
//
        let textureSize: SIMD2<Int> = [inputTexture.width, inputTexture.height]
        lowLevelTexture = try Self.generateTexture(width: textureSize.x, height: textureSize.y)

        let textureResource = try await TextureResource(from: lowLevelTexture)
        material = UnlitMaterial(texture: textureResource)
        material.opacityThreshold = 0.0
        material.blending = .transparent(opacity: 1.0)
    }
    
    /// Updates the texture size of the splash screen background to the provided resolution.
    @MainActor
    mutating func updateTexture(_ mtlTexture: MTLTexture) throws {
        let textureSize: SIMD2<Int> = [mtlTexture.width, mtlTexture.height]
        lowLevelTexture = try Self.generateTexture(width: textureSize.x, height: textureSize.y)
        let textureResource = try TextureResource(from: lowLevelTexture)
        material.color = .init(texture: .init(textureResource))
        self.inputTexture = mtlTexture
        try self.update()
    }
    
    /// Updates the underlying `LowLevelTexture` for the splash screen.
    @MainActor
    func update() throws {
        // Set up the Metal command buffer and compute command encoder.
        guard let commandBuffer = Self.commandQueue?.makeCommandBuffer(),
            let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
                  throw DynamicTextureGenerationError.unableToCreateEncoders
        }

        commandBuffer.enqueue()

        defer {
            blitEncoder.endEncoding()
            commandBuffer.commit()
        }

        // Acquire the output texture from `LowLevelTexture`, providing the command buffer.
        let outTexture: MTLTexture = lowLevelTexture.replace(using: commandBuffer)

        blitEncoder.copy(from: inputTexture, to: outTexture)
    }
}
