# MTLRealityTest

Sample app for testing Metal and RealityKit features. 
Should run directly in SwiftUI previews, so we can test changes to Metal shaders without having to restart the simulator.

### Tests

- [x] basic green, non-metallic quad as baseline
- [x] quad with a static square textresource using
```swift
    try await TextureResource(named: imageName)
```
- [x] `DynamicTextureComponent` with a dynamic texture, updated at each render step (rainbow-color rings updated with time) 
- [x] `TextureWaveComponent` that takes an input `MTLTexture` during `init` and then applies a rainbow-wave pattern to the input texture in the shader, the outPutTexture here is a `LowLevelTexture`
- [x] `UpdatableTextureComponent` where we send a new `MTLTexture` to the component every 200ms and then sample that new texture into a new `LowLevelTexture` using the `PlainTextureSampler`
