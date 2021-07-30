//
//  Camera.swift
//  RayTracer
//
//  Created by Nik Willwerth on 7/25/21.
//

import simd

struct Vector3 {
    var x: Float
    var y: Float
    var z: Float
    
    init(_ x: Float, _ y: Float, _ z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    init(vector: simd_float3) {
        self.x = vector.x
        self.y = vector.y
        self.z = vector.z
    }
    
    func toSimd() -> simd_float3 {
        return simd_float3(self.x, self.y, self.z)
    }
}



struct Camera {
    var origin:          Vector3
    var lensRadius:      Float
    var u:               Vector3
    var v:               Vector3
    var w:               Vector3
    var lowerLeftCorner: Vector3
    var horizontalEdge:  Vector3
    var verticalEdge:    Vector3
}

func makeCamera(eye: simd_float3, viewCenter: simd_float3, upDirection: simd_float3, fov: Float, aspectRatio: Float, lensRadius: Float) -> Camera {
    let w = simd_normalize(eye - viewCenter)
    let u = simd_normalize(simd_cross(upDirection, w))
    let v = simd_normalize(simd_cross(w, u))
    
    let halfHeight    = tan(fov * 0.0174533 * 0.5)
    let halfWidth     = aspectRatio * halfHeight;
    let focusDistance = simd_length(eye - viewCenter)
    
    let lowerLeftCorner = eye - simd_float3(halfWidth * focusDistance * u) - simd_float3(halfHeight * focusDistance * v) - simd_float3(focusDistance * w)
    
    let horizontalEdge = 2.0 * halfWidth  * focusDistance * u
    let verticalEdge   = 2.0 * halfHeight * focusDistance * v
    
    return Camera(origin: Vector3(vector: eye), lensRadius: lensRadius, u: Vector3(vector: u), v: Vector3(vector: v), w: Vector3(vector: w), lowerLeftCorner: Vector3(vector: lowerLeftCorner), horizontalEdge: Vector3(vector: horizontalEdge), verticalEdge: Vector3(vector: verticalEdge))
}



enum MaterialEnum: Int32 {
    case none               = -1
    case lambertianMaterial = 0
    case metalMaterial      = 1
    case dielectricMaterial = 2
}

struct Material {
    init(type: MaterialEnum, albedo: Vector3, fuzziness: Float, refractiveIndex: Float) {
        self.materialType    = type.rawValue
        self.albedo          = albedo
        self.fuzziness       = fuzziness
        self.refractiveIndex = refractiveIndex
    }
    
    // lambertian
    static func createLambertianMaterial() -> Material {
        return Material(type: .lambertianMaterial, albedo: Vector3(vector: simd_float3.random(in: 0.0..<1.0)), fuzziness: 0.0, refractiveIndex: 0.0)
    }
    
    static func createLambertianMaterial(albedo: simd_float3) -> Material {
        return Material(type: .lambertianMaterial, albedo: Vector3(vector: albedo), fuzziness: 0.0, refractiveIndex: 0.0)
    }
    
    static func createLambertianMaterial(albedo: Vector3) -> Material {
        return Material(type: .lambertianMaterial, albedo: albedo, fuzziness: 0.0, refractiveIndex: 0.0)
    }
    
    // metal
    static func createMetalMaterial() -> Material {
        return Material(type: .metalMaterial, albedo: Vector3(vector: simd_float3.random(in: 0.0..<1.0)), fuzziness: Float.random(in: 0..<1), refractiveIndex: 0.0)
    }
    
    static func createMetalMaterial(albedo: simd_float3, fuzziness: Float) -> Material {
        return Material(type: .metalMaterial, albedo: Vector3(vector: albedo), fuzziness: fuzziness, refractiveIndex: 0.0)
    }
    
    static func createMetalMaterial(albedo: Vector3, fuzziness: Float) -> Material {
        return Material(type: .metalMaterial, albedo: albedo, fuzziness: fuzziness, refractiveIndex: 0.0)
    }
    
    // dielectric
    static func createDielectricMaterial() -> Material {
        return Material(type: .dielectricMaterial, albedo: Vector3(0.0, 0.0, 0.0), fuzziness: 0.0, refractiveIndex: 1.1 + (3.0 * Float.random(in: 0..<1)))
    }

    static func createDielectricMaterial(refractiveIndex: Float) -> Material {
        return Material(type: .dielectricMaterial, albedo: Vector3(0.0, 0.0, 0.0), fuzziness: 0.0, refractiveIndex: refractiveIndex)
    }

    var materialType:    Int32
    var albedo:          Vector3
    var fuzziness:       Float
    var refractiveIndex: Float
}

struct Sphere {
    init(center: Vector3, radiusSquared: Float, material: Material) {
        self.center          = center
        self.radiusSquared   = radiusSquared
        self.materialType    = material.materialType
        self.albedo          = material.albedo
        self.fuzziness       = material.fuzziness
        self.refractiveIndex = material.refractiveIndex
    }
    
    var center:          Vector3
    var radiusSquared:   Float
    var materialType:    Int32
    var albedo:          Vector3
    var fuzziness:       Float
    var refractiveIndex: Float
}

func makeSphere(center: simd_float3, radius: Float, material: Material) -> Sphere {
    return Sphere(center: Vector3(vector: center), radiusSquared: radius * radius, material: material)
}



struct Metadata {
    var camera:     Camera
    var numSpheres: Int32
    var randomSeed: Int32
    var renderPass: Int32
}
