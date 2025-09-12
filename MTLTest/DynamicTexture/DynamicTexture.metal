/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A compute kernel written in Metal Shading Language.
*/

#include <metal_stdlib>

using namespace metal;

kernel void
colorCirclesKernel(
                   texture2d<float, access::write>  outTexture     [[texture(0)]],
                   constant float                  &time           [[buffer(0)]],
                   uint2                            gid            [[thread_position_in_grid]])
{
    const float width = outTexture.get_width();
    const float height = outTexture.get_height();
    const float2 center = float2(width * 0.5, height * 0.5);
    const float2 pixel = float2(float(gid[0]), float(height - gid[1]));

    // Vector from center to pixel
    float2 toPixel = pixel - center;
    float dist = length(toPixel) / (min(width, height) * 0.5); // 0 at center, 1 at edge
    // Hue changes with distance, repeats every 1/N units
    const float rings = 3.0;
    float hue = fract((dist + time) * rings); // 0..1, repeats in rings
    float brightness = 1.0;

    // HSV to RGB
    float s = 1.0;
    float v = brightness;
    float c = v * s;
    float h = hue * 6.0;
    float x = c * (1.0 - fabs(fmod(h, 2.0) - 1.0));
    float3 rgb;
    if (0.0 <= h && h < 1.0)      rgb = float3(c, x, 0);
    else if (1.0 <= h && h < 2.0) rgb = float3(x, c, 0);
    else if (2.0 <= h && h < 3.0) rgb = float3(0, c, x);
    else if (3.0 <= h && h < 4.0) rgb = float3(0, x, c);
    else if (4.0 <= h && h < 5.0) rgb = float3(x, 0, c);
    else                         rgb = float3(c, 0, x);
    float m = v - c;
    rgb += float3(m, m, m);

    float4 outColor = float4(rgb, 1.0);
    outTexture.write(outColor, gid);
}
