#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct Uniforms {
    float progress;
    float time;
    float scale;
    float rotation;
};

// Helper function to create a normalized point from angle and radius
float2 polarToCartesian(float angle, float radius) {
    return float2(cos(angle) * radius, sin(angle) * radius);
}

// Helper function to check if point is inside a triangle
float triangleShape(float2 uv, float2 p1, float2 p2, float2 p3) {
    float2 v1 = p2 - p1;
    float2 v2 = p3 - p1;
    float2 v3 = uv - p1;
    
    float dot11 = dot(v1, v1);
    float dot12 = dot(v1, v2);
    float dot13 = dot(v1, v3);
    float dot22 = dot(v2, v2);
    float dot23 = dot(v2, v3);
    
    float invDenom = 1.0 / (dot11 * dot22 - dot12 * dot12);
    float u = (dot22 * dot13 - dot12 * dot23) * invDenom;
    float v = (dot11 * dot23 - dot12 * dot13) * invDenom;
    
    return float(u >= 0.0 && v >= 0.0 && (u + v) <= 1.0);
}

// Helper function to create the center hexagon
float centerHexagon(float2 uv, float size, float progress) {
    const float PI = 3.14159265359;
    float result = 0.0;
    float hexSize = mix(size * 0.2, size, progress);
    
    for (int i = 0; i < 6; i++) {
        float angle1 = float(i) * PI / 3.0;
        float angle2 = float(i + 1) * PI / 3.0;
        float2 p1 = float2(0.0);
        float2 p2 = polarToCartesian(angle1, hexSize);
        float2 p3 = polarToCartesian(angle2, hexSize);
        result += triangleShape(uv, p1, p2, p3);
    }
    
    return min(result, 1.0);
}

// Helper function to create blade shape based on SVG path
float cliprBlade(float2 uv, float rotation, float progress) {
    // Rotate UV
    float c = cos(rotation);
    float s = sin(rotation);
    float2x2 rot = float2x2(c, -s, s, c);
    float2 rotatedUV = rot * uv;
    
    // Create blade shape based on SVG path
    float innerRadius = mix(0.3, 0.4, progress);
    float outerRadius = mix(0.4, 0.8, progress);
    float angle = atan2(rotatedUV.y, rotatedUV.x);
    float radius = length(rotatedUV);
    
    // Define blade shape
    float angleWidth = 0.5;
    float blade = step(innerRadius, radius) * 
                 step(radius, outerRadius) * 
                 step(abs(angle), angleWidth);
    
    return blade;
}

vertex VertexOut apertureVertex(uint vertexID [[vertex_id]],
                              constant float4* vertices [[buffer(0)]],
                              constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    float4 position = vertices[vertexID];
    
    // Apply scale
    position.xy *= uniforms.scale;
    
    // Apply rotation
    float cosR = cos(uniforms.rotation);
    float sinR = sin(uniforms.rotation);
    float2x2 rotation = float2x2(cosR, -sinR, sinR, cosR);
    position.xy = rotation * position.xy;
    
    out.position = position;
    out.uv = vertices[vertexID].zw;
    return out;
}

fragment float4 apertureFragment(VertexOut in [[stage_in]],
                               constant Uniforms& uniforms [[buffer(0)]]) {
    float2 uv = in.uv * 2.0 - 1.0;
    
    // Create center hexagon
    float center = centerHexagon(uv, 0.3, uniforms.progress);
    
    // Create blades based on SVG geometry
    float blades = 0.0;
    const float PI = 3.14159265359;
    for (int i = 0; i < 6; i++) {
        float angle = float(i) * PI / 3.0;
        blades += cliprBlade(uv, angle + uniforms.rotation, uniforms.progress);
    }
    
    // Combine shapes
    float shape = max(center, min(blades, 1.0));
    
    // Add outer circle mask
    float dist = length(uv);
    float circle = 1.0 - smoothstep(0.9, 1.0, dist);
    shape *= circle;
    
    // Color and glow
    float3 cliprOrange = float3(0.867, 0.431, 0.259); // #DD6E42
    float glow = (1.0 - dist) * 0.2 * uniforms.progress;
    
    float3 color = mix(float3(0.0), cliprOrange, shape);
    color += cliprOrange * glow * shape;
    
    return float4(color, shape);
} 