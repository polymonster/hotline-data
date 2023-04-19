#include "maths.hlsl"
#include "ecs.hlsl"

//
// writes noise to a texture
//

RWTexture3D<float4> rwtex[] : register(u0, space0);

cbuffer resource_indices : register(b0) {
    uint4 srv_index;
};

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

    rwtex[srv_index.x][did.xyz] = float4(nn, 0.0, 0.0, nn < 0.9 ? 0.0 : 1.0);
}

//
// frustum cull entity aabb's and build indirect commands
//

struct buffer_view {
    uint2 location;
    uint  size_bytes;
    uint  stride_bytes;
};

struct draw_indexed_args {
    uint index_count_per_instance;
    uint instance_count;
    uint start_index_location;
    uint base_vertex_location;
    uint start_instance_location;
};

struct indirect_draw {
    buffer_view         vb;
    buffer_view         ib;
    uint                draw_id;
    draw_indexed_args   args;
};

// potential draw calls we want to make
StructuredBuffer<indirect_draw> input_draws[] : register(t0, space5);

// draw calls to populate during the `cs_frustum_cull` dispatch
AppendStructuredBuffer<indirect_draw> output_draws[] : register(u0, space0);

[numthreads(128, 1, 1)]
void cs_frustum_cull(uint did : SV_DispatchThreadID) {
    uint index = did;

    // grab entity draw data
    draw_data draw = get_draw_data(index);
    camera_data main_camera = get_camera_data();

    // grab potential draw call
    indirect_draw input = input_draws[srv_index.y][index];

    // frustum cull
    float3 pos;
    pos[0] = draw.world_matrix[0][3];
    pos[1] = draw.world_matrix[1][3];
    pos[2] = draw.world_matrix[2][3];
    float radius = 10.0;

    if(sphere_vs_frustum(pos, radius, main_camera.planes)) {

        output_draws[srv_index.x].Append(input);
    }
}   