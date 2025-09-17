/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A compute kernel written in Metal Shading Language.
*/

#include <metal_stdlib>

using namespace metal;

kernel void
plainTextureSampler(
    texture2d<float, access::sample> inTexture      [[texture(0)]],
    texture2d<float, access::write>  outTexture     [[texture(1)]],
    constant float                  &time           [[buffer(0)]],
    uint2                            gid            [[thread_position_in_grid]])
{
    const float width = outTexture.get_width();
    const float height = outTexture.get_height();

    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge,  // Prevent out-of-bounds access by clamping to edge
        coord::normalized        // Ensure we use normalized [0,1] coordinates
    );

    // Convert bounding box coordinates to depth texture coordinates safely
    float2 texCoordInBB = float2(gid) / float2(width, height);
    float3 texValue = inTexture.sample(textureSampler, texCoordInBB).rgb;

    float4 outColor = float4(texValue, 1.0);
    outTexture.write(outColor, gid);
}
