#include "maths.hlsl"

RWTexture3D<float4> rwtex[] : register(u0, space0);

cbuffer cbuffer_resource_indices : register(b0) {
    uint4 srv_index;
};

// writes noise to a texture
[numthreads(8, 8, 8)]
void cs_write_texture3d(uint3 did : SV_DispatchThreadID) {
    float3 dim = float3(64.0, 64.0, 64.0);
    float3 grid_pos = did.xyz * 2.0 - float3(64.0, 64.0, 64.0);

    float4 sphere;
    float d = 1.0;

    float nxz = voronoise(did.xz / 8.0, 1.0, 0.0);
    float nxy = voronoise(did.xy / 8.0, 1.0, 0.0);
    float nyz = voronoise(did.yz / 8.0, 1.0, 0.0);

    float3 n = normalize(grid_pos);

    float nn = 
        abs(dot(n, float3(0.0, 1.0, 0.0))) * nxz 
        + abs(dot(n, float3(0.0, 0.0, 1.0))) * nxy
        + abs(dot(n, float3(1.0, 0.0, 0.0))) * nyz;

    (srv_index);

    rwtex[srv_index.x][did.xyz] = float4(nn, 0.0, 0.0, nn < 0.9 ? 0.0 : 1.0);
}