/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Utilities for interfacing with Metal.
*/

import Metal

/// A metal device to use throughout the app.
let metalDevice: MTLDevice? = MTLCreateSystemDefaultDevice()

/// Create a `MTLComputePipelineState` for a Metal compute kernel named `name`, using a default Metal device.
func makeComputePipeline(named name: String) -> MTLComputePipelineState? {
    if let metalDevice, let function = metalDevice.makeDefaultLibrary()?.makeFunction(name: name) {
        return try? metalDevice.makeComputePipelineState(function: function)
    } else {
        return nil
    }
}

extension MTLPackedFloat3 {
    /// Convert a `MTLPackedFloat3` to a `SIMD3<Float>`.
    var simd3: SIMD3<Float> { return .init(x, y, z) }
}

extension SIMD3 where Scalar == Float {
    /// Convert a `SIMD3<Float>` to a `MTLPackedFloat3`.
    var packed3: MTLPackedFloat3 { return .init(.init(elements: (x, y, z))) }
}

func validateMTLTexture(_ texture: MTLTexture?) -> Bool {
    guard let texture = texture else {
        return false
    }

    // Check for valid texture dimensions
    if texture.width == 0 || texture.height == 0 {
        return false
    }

    // Check for valid pixel format (common ones we use)
    switch texture.pixelFormat {
    case .r32Float, .r16Float, .rgba8Unorm, .bgra8Unorm:
        return true
    default:
        // If we're using a different format, log it but allow it through
        print("Using non-standard texture format: \(texture.pixelFormat.rawValue)")
        return true
    }
}
