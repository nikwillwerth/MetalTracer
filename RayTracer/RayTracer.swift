//
//  RayTracer.swift
//  RayTracer
//
//  Created by Nik Willwerth on 7/23/21.
//

import Metal
import MetalKit

class RayTracer: NSObject, MTKViewDelegate {
    var renderPass: Int32 = 0
    
    private var device:               MTLDevice?
    private var defaultLibrary:       MTLLibrary?
    private var commandQueue:         MTLCommandQueue?
    private var computePipelineState: MTLComputePipelineState?
    private var renderPipelineState:  MTLRenderPipelineState?
    
    private let threadGroupSize:  MTLSize
    private var threadGroupCount: MTLSize
    
    private var imageTexture:  MTLTexture!
    private var bufferTexture: MTLTexture!
    private var vertexBuffer:  MTLBuffer!
    private var spheresBuffer: MTLBuffer!
    
    private var mtkView:     MTKView
    private var imageWidth:  CGFloat
    private var imageHeight: CGFloat
    
    private var camera:  Camera!
    private var spheres: [Sphere]!
    
    init(mtkView: MTKView, imageWidth: CGFloat, imageHeight: CGFloat) {
        self.mtkView     = mtkView
        self.imageWidth  = imageWidth
        self.imageHeight = imageHeight
        
        self.device         = MTLCreateSystemDefaultDevice()
        self.defaultLibrary = self.device?.makeDefaultLibrary()
        self.commandQueue   = self.device?.makeCommandQueue()
        
        let rayTraceShader = self.defaultLibrary?.makeFunction(name: "raytrace")
        let vertexShader   = self.defaultLibrary?.makeFunction(name: "vertexShader")
        let fragmentShader = self.defaultLibrary?.makeFunction(name: "fragmentShader")
        
        self.mtkView.device                = self.device
        self.mtkView.clearColor            = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        self.mtkView.enableSetNeedsDisplay = true
        
        if let rayTraceShader = rayTraceShader {
            self.computePipelineState = try? self.device?.makeComputePipelineState(function: rayTraceShader)
        } else {
            fatalError("Unable to make compute pipeline state")
        }
        
        if let vertexShader = vertexShader, let fragmentShader = fragmentShader {
            let renderPipelineDescriptor                             = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.vertexFunction                  = vertexShader
            renderPipelineDescriptor.fragmentFunction                = fragmentShader
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            self.renderPipelineState = try? self.device?.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } else {
            fatalError("Unable to make render pipeline state")
        }
        
        let vertexData: [Float] = [
          -1.0, -1.0, 0.0,
           1.0, -1.0, 0.0,
          -1.0,  1.0, 0.0,
           1.0,  1.0, 0.0,
           1.0, -1.0, 0.0,
          -1.0,  1.0, 0.0
        ]
        
        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        
        self.vertexBuffer = self.device?.makeBuffer(bytes: vertexData, length: dataSize, options: [])
        
        let sqrtMaxThreadsPerGroup = Int(sqrt(Double(self.device!.maxThreadsPerThreadgroup.width)))
        
        self.threadGroupSize = MTLSize(width: sqrtMaxThreadsPerGroup, height: sqrtMaxThreadsPerGroup, depth: 1)
        
        let threadGroupCountWidth  = (Int(self.imageWidth)  + self.threadGroupSize.width  - 1) / self.threadGroupSize.width
        let threadGroupCountHeight = (Int(self.imageHeight) + self.threadGroupSize.height - 1) / self.threadGroupSize.height
        
        self.threadGroupCount = MTLSize(width: threadGroupCountWidth, height: threadGroupCountHeight, depth: 1)
    }
    
    func setup() {
        self.imageTexture     = self.createTexture()
        self.bufferTexture    = self.createTexture()
        self.mtkView.delegate = self
        
        self.setupUniforms()
    }
    
    private func setupUniforms() {
        // set up camera
        let eye         = simd_float3(5.0, 1.0, 5.5)
        let viewCenter  = simd_float3(1.0, 0.5, 0.0)
        let upDirection = simd_float3(0.0, 1.0, 0.0)
        let fov         = Float(45.0)
        let aspectRatio = Float(self.imageWidth / self.imageHeight)
        let lensRadius  = Float(0.0)
        
        self.camera = makeCamera(eye: eye, viewCenter: viewCenter, upDirection: upDirection, fov: fov, aspectRatio: aspectRatio, lensRadius: lensRadius)
        
        // set up objects
        self.spheres = [Sphere]()
        self.spheres.append(makeSphere(center: simd_float3(0.0, -1000.0, 0.0), radius: 1000.0, material: Material.createLambertianMaterial(albedo: simd_float3(0.5, 0.5, 0.5))))
        
        self.spheres.append(makeSphere(center: simd_float3(0.0, 1.0, 0.0),  radius: 1.0, material: Material.createMetalMaterial(albedo: 0.5 * (1.0 + simd_float3.random(in: 0.0..<1.0)), fuzziness: 0.0)))
        self.spheres.append(makeSphere(center: simd_float3(-4.0, 1.0, 0.0), radius: 1.0, material: Material.createMetalMaterial(albedo: 0.5 * (1.0 + simd_float3.random(in: 0.0..<1.0)), fuzziness: 0.0)))
        self.spheres.append(makeSphere(center: simd_float3(4.0, 1.0, 0.0),  radius: 1.0, material: Material.createMetalMaterial(albedo: 0.5 * (1.0 + simd_float3.random(in: 0.0..<1.0)), fuzziness: 0.0)))
        
        for a in -10..<10 {
            for b in -10..<10 {
                let radius = 0.2 + (((2.0 * Float.random(in: 0..<1)) - 1.0) * 0.05)
                let center = simd_float3(Float(a) + (0.9 * Float.random(in: 0..<1)), radius + (5.0 * Float.random(in: 0..<1)), Float(b) + (10.9 * Float.random(in: 0..<1)))
                
                var tooBig = false
                
                for sphere in self.spheres {
                    if(simd_length(center - sphere.center.toSimd()) < (1.0 + radius)) {
                        tooBig = true
                        
                        break
                    }
                }
                
                if(!tooBig) {
                    var material: Material
                    
                    let rando = Float.random(in: 0..<1)
                    
                    if(rando < 0.33) {
                        material = Material.createLambertianMaterial()
                    } else if(rando < 0.66) {
                        material = Material.createMetalMaterial(albedo: simd_float3.random(in: 0.0..<1.0), fuzziness: Float.random(in: 0..<1))
                    } else {
                        material = Material.createDielectricMaterial()
                    }
                    
                    self.spheres.append(makeSphere(center: center,  radius: radius, material: material))
                }
            }
        }
        
        var sphereBytes = [Byte]()

        for sphere in self.spheres {
            sphereBytes.append(contentsOf: ByteBackpacker.pack(sphere))
        }
        
        self.spheresBuffer = self.device?.makeBuffer(bytes: sphereBytes, length: sphereBytes.count, options: [])!
    }
    
    func render() {
        // set up uniforms
        let metadata = Metadata(camera: self.camera, numSpheres: Int32(self.spheres.count), randomSeed: Int32.random(in: 1..<1000), renderPass: self.renderPass)
        
        let metadataBytes = ByteBackpacker.pack(metadata)
        
        let metadataBuffer = self.device?.makeBuffer(bytes: metadataBytes, length: metadataBytes.count, options: [])!
        
        // compute
        let commandBuffer = self.commandQueue?.makeCommandBuffer()
        
        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        computeCommandEncoder?.setComputePipelineState(self.computePipelineState!)
        computeCommandEncoder?.setTexture(self.bufferTexture, index: 0)
        computeCommandEncoder?.setTexture(self.imageTexture,  index: 1)
        computeCommandEncoder?.setBuffer(metadataBuffer,     offset: 0, index: 0)
        computeCommandEncoder?.setBuffer(self.spheresBuffer, offset: 0, index: 1)
        computeCommandEncoder?.dispatchThreadgroups(self.threadGroupCount, threadsPerThreadgroup: self.threadGroupSize)
        computeCommandEncoder?.endEncoding()
        
        // render
        let renderCommandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: self.mtkView.currentRenderPassDescriptor!)
        renderCommandEncoder?.setRenderPipelineState(self.renderPipelineState!)
        renderCommandEncoder?.setFragmentTexture(self.imageTexture, index: 0)
        renderCommandEncoder?.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderCommandEncoder?.endEncoding()
        
        commandBuffer?.present(self.mtkView.currentDrawable!)
        
        commandBuffer?.commit()
        commandBuffer?.waitUntilCompleted()
        
        self.renderPass += 1
    }
    
    private func createTexture() -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float,
                                                                         width:       Int(self.imageWidth),
                                                                         height:      Int(self.imageHeight),
                                                                         mipmapped:   false)
        textureDescriptor.usage       = [.shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .private
        
        return (self.device?.makeTexture(descriptor: textureDescriptor))!
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        self.render()
    }
}
