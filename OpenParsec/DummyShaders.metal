// DummyShaders.metal

#include <metal_stdlib>

using namespace metal;

struct VertexOut {
    float4 position [[position]];
};

// Dummy vertex function
vertex VertexOut dummyVertex(uint vertexID [[vertex_id]]) {
    VertexOut out;
    out.position = float4(0.0, 0.0, 0.0, 1.0);
    return out;
}

// Dummy fragment function
fragment float4 dummyFragment(VertexOut in [[stage_in]]) {
    return float4(1.0, 1.0, 1.0, 1.0); // White color
}
