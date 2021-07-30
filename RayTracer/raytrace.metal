//
//  raytrace.metal
//  RayTracer
//
//  Created by Nik Willwerth on 7/23/21.
//

#include <metal_stdlib>
#include "loki_header.metal"
using namespace metal;


struct Vector3 {
    float x;
    float y;
    float z;
    
    float3 toFloat3() const {
        return float3(x, y, z);
    }
};

enum MaterialEnum: int {
    lambertianMaterial = 0,
    metalMaterial      = 1,
    dielectricMaterial = 2
};
    
struct CameraStruct {
    Vector3 origin;
    float  lensRadius;
    Vector3 u;
    Vector3 v;
    Vector3 w;
    Vector3 lowerLeftCorner;
    Vector3 horizontalEdge;
    Vector3 verticalEdge;
};

struct SphereStruct {
    Vector3      center;
    float        radiusSquared;
    MaterialEnum material;
    Vector3      albedo;
    float        fuzziness;
    float        refractiveIndex;
};




struct Ray {
    explicit Ray() {}

    explicit Ray(float3 origin, float3 unitDirection): origin{origin}, unitDirection{normalize(unitDirection)} {}
    
    float3 point(float f) const {
        return origin + (f * unitDirection);
    }
    
    float3 origin;
    float3 unitDirection;
};

struct HitInfo {
    float  hitTime;
    float3 point;
    float3 unitNormal;
    int    hitIndex;
};
    
namespace Math {
    inline float2 randomInDisk(Loki rng) {
        float2 rando;

        for(int i = 0; i < 16; i++) {
            rando = 2.0 * float2(rng.rand(), rng.rand()) - float2(1.0);

            if(dot(rando, rando) < 1.0) {
                break;
            }
        }
        
        return rando;
    }
        
    inline float3 randomInSphere(Loki rng) {
        float3 rando;

        for(int i = 0; i < 16; i++) {
            rando = 2.0 * float3(rng.rand(), rng.rand(), rng.rand()) - float3(1.0);

            if(dot(rando, rando) < 1.0) {
                break;
            }
        }
        
        return rando;
    }
}

struct Camera {
    Camera(float3 origin, float lensRadius, float3 u, float3 v, float3 w, float3 lowerLeftCorner, float3 horizontalEdge, float3 verticalEdge):
        origin{origin}, lensRadius{lensRadius}, u{u}, v{v}, w{w}, lowerLeftCorner{lowerLeftCorner}, horizontalEdge{horizontalEdge}, verticalEdge{verticalEdge} {}
    
    Camera(CameraStruct camera):
    origin{camera.origin.toFloat3()}, lensRadius{camera.lensRadius}, u{camera.u.toFloat3()}, v{camera.v.toFloat3()}, w{camera.w.toFloat3()}, lowerLeftCorner{camera.lowerLeftCorner.toFloat3()}, horizontalEdge{camera.horizontalEdge.toFloat3()}, verticalEdge{camera.verticalEdge.toFloat3()} {}
    
    Ray ray(float s, float t, Loki rng) const {
        const float2 rd     = lensRadius * Math::randomInDisk(rng);
        const float3 offset = (u * rd.x) + (v * rd.y);
        
        return Ray{origin + offset, lowerLeftCorner + (s * horizontalEdge) + (t * verticalEdge) - offset - origin};
    }
    
    float3 origin;
    float  lensRadius;
    float3 u;
    float3 v;
    float3 w;
    float3 lowerLeftCorner;
    float3 horizontalEdge;
    float3 verticalEdge;
};
    
struct Material {
    Material(MaterialEnum type, float3 albedo, float fuzziness, float refractiveIndex):
        materialType{type}, albedo{albedo}, fuzziness{fuzziness}, refractiveIndex{refractiveIndex} {}
    
    bool scatter(Ray ray, HitInfo hitInfo, Loki rng, thread float3& attenuation, thread Ray& scatteredRay) const {
        if(materialType == lambertianMaterial) {
            return scatterLambertian(hitInfo, rng, attenuation, scatteredRay);
        } else if(materialType == metalMaterial) {
            return scatterMetal(ray, hitInfo, rng, attenuation, scatteredRay);
        } else if(materialType == dielectricMaterial) {
            return scatterdielectric(ray, hitInfo, rng, attenuation, scatteredRay);
        }
        
        return false;
    }
    
    MaterialEnum materialType;
    float3       albedo;
    float        fuzziness;
    float        refractiveIndex;
    
private:
    bool scatterLambertian(HitInfo hitInfo, Loki rng, thread float3& attenuation, thread Ray& scatteredRay) const {
        const float3 target = hitInfo.point + hitInfo.unitNormal + Math::randomInSphere(rng);

        scatteredRay = Ray(hitInfo.point, target - hitInfo.point);
        attenuation  = albedo;
        
        return true;
    }
    
    bool scatterMetal(Ray ray, HitInfo hitInfo, Loki rng, thread float3& attenuation, thread Ray& scatteredRay) const {
        const float3 reflectedRay = reflect(ray.unitDirection, hitInfo.unitNormal);

        scatteredRay = Ray(hitInfo.point, reflectedRay + (fuzziness * Math::randomInSphere(rng)));
        attenuation  = albedo;
        
        return dot(scatteredRay.unitDirection, hitInfo.unitNormal) > 0;
    }
    
    bool scatterdielectric(Ray ray, HitInfo hitInfo, Loki rng, thread float3& attenuation, thread Ray& scatteredRay) const {
        attenuation = float3(1.0f);
        
        float  niOverNt;
        float  cosine;
        float3 outwardNormal;
        
        cosine = dot(ray.unitDirection, hitInfo.unitNormal);
        
        if(cosine > 0) {
            outwardNormal = -hitInfo.unitNormal;
            niOverNt      = refractiveIndex;
            
            cosine = sqrt(1.0f - (refractiveIndex * refractiveIndex * (1 - (cosine * cosine))));
        } else {
            outwardNormal = hitInfo.unitNormal;
            niOverNt      = 1.0f / refractiveIndex;
            cosine        = -cosine;
        }
        
        const float3 refractedDirection    = refract(ray.unitDirection, outwardNormal, niOverNt);
        const float  reflectionProbability = dot(refractedDirection, refractedDirection) > 0 ? schlick(cosine) : 1.0f;
        
        scatteredRay.origin = hitInfo.point;
        
        if(rng.rand() < reflectionProbability) {
            scatteredRay.unitDirection = reflect(ray.unitDirection, hitInfo.unitNormal);
        } else {
            scatteredRay.unitDirection = normalize(refractedDirection);
        }
        
        return true;
    }
    
    inline float schlick(float cosine) const {
        float r0 = (1.0f - refractiveIndex) / (1.0f + refractiveIndex);
        r0 = r0 * r0;
        
        return r0 + ((1.0f - r0) * pow(1.0f - cosine, 5.0f));
    }
};

struct Sphere {
    Sphere(SphereStruct sphere):
        center{sphere.center.toFloat3()}, radiusSquared{sphere.radiusSquared}, material{Material(sphere.material, sphere.albedo.toFloat3(), sphere.fuzziness, sphere.refractiveIndex)} {}
    
    bool intersect(Ray ray, float tMin, float tMax, thread HitInfo& hitInfo) const {
        const float3 direction = ray.unitDirection;
        const float3 oc        = ray.origin - center;
        
        const float a = 1.0;
        const float b = dot(direction, oc);
        const float c = dot(oc, oc) - radiusSquared;
        
        const float delta = (b * b) - (a * c);
        
        if(delta > 0.0) {
            const float t1 = (-b - sqrt(delta)) / a;
            
            if((t1 > tMin) && (t1 < tMax)) {
                computeHitInfo(ray, t1, hitInfo);
                
                return true;
            }
            
            const float t2 = (-b + sqrt(delta)) / a;
            
            if((t2 > tMin) && (t2 < tMax)) {
                computeHitInfo(ray, t2, hitInfo);
                
                return true;
            }
        }
        
        return false;
    }
    
    void computeHitInfo(Ray ray, float hitTime, thread HitInfo& hitInfo) const {
        hitInfo.hitTime    = hitTime;
        hitInfo.point      = ray.point(hitTime);
        hitInfo.unitNormal = normalize(hitInfo.point - center);
    }
    
    float3   center;
    float    radiusSquared;
    Material material;
};






bool checkForIntersect(Ray ray, float tMin, float tMax, constant SphereStruct* spheres, int numSpheres, thread HitInfo& hitInfo) {
    bool hit = false;
    
    float minHitTime = tMax;
    
    for(int i = 0; i < numSpheres; i++) {
        Sphere sphere = Sphere(spheres[i]);
        
        if(sphere.intersect(ray, tMin, minHitTime, hitInfo)) {
            minHitTime = hitInfo.hitTime;
            
            hit = true;
            
            hitInfo.hitIndex = i;
        }
    }
    
    return hit;
}

float3 shade(Ray ray, constant SphereStruct* spheres, int numSpheres, Loki rng) {
    thread Ray* scatteredRay = &ray;

    HitInfo temp1 = HitInfo();
    float3  temp2(0.0f);
    
    thread HitInfo* hitInfo = &temp1;
    
    float3 attenuation;
    
    int i = 0;
    
    for(; i < 16; i++) {
        if(checkForIntersect(*scatteredRay, 0.001, 1e10f, spheres, numSpheres, *hitInfo)) {
            thread float3* thisAttenuation = &temp2;

            Sphere sphere = Sphere(spheres[hitInfo->hitIndex]);

            bool scatter = sphere.material.scatter(*scatteredRay, *hitInfo, rng, *thisAttenuation, *scatteredRay);
            
            if(i == 0) {
                attenuation = *thisAttenuation;
            }

            if(scatter) {
                if(i > 0) {
                    attenuation *= *thisAttenuation;
                }
            } else {
                break;
            }
        } else {
            const float t = 0.5 * (scatteredRay->unitDirection.y + 1.0);

            float3 background = ((1.0 - t) * float3(1.0, 1.0, 1.0)) + (t * float3(0.5, 0.7, 1.0));

            if(i == 0) {
                attenuation = background;
            } else {
                attenuation *= background;
            }

            break;
        }
    }

    return attenuation;
}
    
    
    
struct Metadata {
    CameraStruct camera;
    int    numSpheres;
    int    randomSeed;
    int    renderPass;
};

    
    
kernel void raytrace(texture2d<float, access::read_write> buffer [[texture(0)]],
                     texture2d<float, access::write>      image  [[texture(1)]],
                     constant Metadata&     metadata [[buffer(0)]],
                     constant SphereStruct* spheres  [[buffer(1)]],
                     uint2 gridId [[thread_position_in_grid]]) {
    Loki rng = Loki(int(metadata.randomSeed * gridId.x), int(metadata.randomSeed * gridId.y), metadata.renderPass);
    
    const float u = (gridId.x + ((2.0 * rng.rand()) - 1.0)) / image.get_width();
    const float v = (gridId.y + ((2.0 * rng.rand()) - 1.0)) / image.get_height();
    
    if((u < 0) || (u > 1.0) || (v < 0) || (v > 1.0)) {
        return;
    }
    
    const Camera camera = Camera(metadata.camera);
    
    const Ray ray = camera.ray(u, v, rng);
    
    float3 color = shade(ray, spheres, metadata.numSpheres, rng);
    
    float4 buff = buffer.read(gridId) + float4(color, 1.0);

    buffer.write(buff, gridId);
    image.write(float4(sqrt(buff.xyz / buff.w), 1.0), gridId);
}



struct VertexOut {
    float4 positionCoordinates [[position]];
    float2 textureCoordinates;
};

vertex VertexOut vertexShader(unsigned int vertexId [[vertex_id]],
                              const device packed_float3* vertexArray [[buffer(0)]]) {
    VertexOut vertexOut;
    vertexOut.positionCoordinates = float4(vertexArray[vertexId], 1.0);
    vertexOut.textureCoordinates  = (vertexOut.positionCoordinates.xy * 0.5) + 0.5;
    
    return vertexOut;
    
}

fragment float4 fragmentShader(VertexOut vertexOut [[stage_in]],
                               texture2d<float, access::read> texture [[texture(0)]]) {
    uint2 gridId = uint2(int(vertexOut.textureCoordinates.x * texture.get_width()), int(vertexOut.textureCoordinates.y * texture.get_height()));
    
    return texture.read(gridId);
}
