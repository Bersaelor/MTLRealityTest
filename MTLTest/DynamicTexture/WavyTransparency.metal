/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A compute kernel written in Metal Shading Language.
*/

#include <metal_stdlib>

using namespace metal;

kernel void
wavyTransparency(
    texture2d<float, access::sample> inTexture      [[texture(0)]],
    texture2d<float, access::write>  outTexture     [[texture(1)]],
    constant float                  &time           [[buffer(0)]],
    uint2                            gid            [[thread_position_in_grid]])
{
    const float width = outTexture.get_width();
    const float height = outTexture.get_height();
    const float2 center = float2(width * 0.5, height * 0.5);
    const float2 pixel = float2(float(gid[0]), float(height - gid[1]));

    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge,  // Prevent out-of-bounds access by clamping to edge
        coord::normalized        // Ensure we use normalized [0,1] coordinates
    );
    // Vector from center to pixel
    float2 toPixel = pixel - center;
    float dist = length(toPixel) / (min(width, height) * 0.5); // 0 at center, 1 at edge
    // Hue changes with distance, repeats every 1/N units
    const float rings = 3.0;
    float hue = fract((dist + time) * rings); // 0..1, repeats in rings

    // Convert bounding box coordinates to depth texture coordinates safely
    float2 texCoordInBB = float2(gid) / float2(width, height);
    float3 texValue = inTexture.sample(textureSampler, texCoordInBB).rgb;

    float4 outColor = float4(texValue, hue);
    outTexture.write(outColor, gid);
}
