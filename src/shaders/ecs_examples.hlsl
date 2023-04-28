#include "maths.hlsl"
#include "ecs.hlsl"

//
// draw / draw indexed
//

vs_output vs_mesh_identity(vs_input_mesh input) {
    float4 pos = float4(input.position.xyz, 1.0);

    vs_output output;
    output.position = mul(view_projection_matrix, pos);
    output.world_pos = pos;
    output.texcoord = float4(input.texcoord, 0.0, 0.0);
    output.colour = float4(1.0, 1.0, 1.0, 1.0);
    output.normal = input.normal.xyz;
    
    return output;
}

//
// example vertex buffer instancing
//

struct vs_input_instance {
    float4 row0: TEXCOORD4;
    float4 row1: TEXCOORD5;
    float4 row2: TEXCOORD6;
    float4 row3: TEXCOORD7;
};

vs_output vs_mesh_vertex_buffer_instanced(vs_input_mesh input, vs_input_instance instance_input) {
    vs_output output;

    float3x4 instance_matrix;
    instance_matrix[0] = instance_input.row0;
    instance_matrix[1] = instance_input.row1;
    instance_matrix[2] = instance_input.row2;

	float4 pos = float4(input.position.xyz, 1.0);
    pos.xyz = mul(instance_matrix, pos);

    output.position = mul(view_projection_matrix, pos);
    output.world_pos = pos;
    output.texcoord = float4(input.texcoord, 0.0, 0.0);
    output.colour = float4(input.normal.xyz * 0.5 + 0.5, 1.0);
    output.normal = input.normal.xyz;
    
    return output;
}

//
// example using a cbuffer to lookup instance info from SV_InstanceID
//

struct cbuffer_instance_data {
    float3x4 cbuffer_world_matrix[1024];
};

ConstantBuffer<cbuffer_instance_data> cbuffer_instance : register(b1);

vs_output vs_mesh_cbuffer_instanced(vs_input_mesh input, uint iid: SV_InstanceID) {
    vs_output output;

	float4 pos = float4(input.position.xyz, 1.0);
    pos.xyz = mul(cbuffer_instance.cbuffer_world_matrix[iid], pos);

    output.position = mul(view_projection_matrix, pos);
    output.world_pos = pos;
    output.texcoord = float4(input.texcoord, 0.0, 0.0);
    output.colour = float4(input.normal.xyz * 0.5 + 0.5, 1.0);
    output.normal = input.normal.xyz;

    return output;
}

//
// compute shader writes noise to a 3D texture
//

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

    rw_volume_textures[resources.input0.index][did.xyz] = float4(nn, 0.0, 0.0, nn < 0.9 ? 0.0 : 1.0);
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
    uint4               ids;
    draw_indexed_args   args;
};

// potential draw calls we want to make
StructuredBuffer<indirect_draw> input_draws[] : register(t0, space11);

// draw calls to populate during the `cs_frustum_cull` dispatch
AppendStructuredBuffer<indirect_draw> output_draws[] : register(u0, space0);

[numthreads(128, 1, 1)]
void cs_frustum_cull(uint did : SV_DispatchThreadID) {
    uint index = did;

    pmfx_touch(resources);

    // grab entity draw data
    extent_data extents = get_extent_data(index);
    camera_data main_camera = get_camera_data();

    // grab potential draw call
    indirect_draw input = input_draws[resources.input1.index][index];

    bool use_aabb = true;
    bool no_cull = false;

    if(no_cull) {
        output_draws[resources.input0.index].Append(input);
    }
    else if(use_aabb) {
        if(aabb_vs_frustum(extents.pos, extents.extent, main_camera.planes)) {
            output_draws[resources.input0.index].Append(input);
        }
    }
    else {
        if(sphere_vs_frustum(extents.pos, length(extents.extent), main_camera.planes)) {
            output_draws[resources.input0.index].Append(input);
        }
    }
}

//
// multiple render target heightmap example
//

vs_output vs_heightmap(vs_input_mesh input) {
    vs_output output;

	float4 pos = float4(input.position.xyz, 1.0);
    pos.xyz = mul(world_matrix, pos);

    float step = 1024.0 / 10.0;
    float height = 200.0;

    float3 p1 = pos.xyz;
    
    float h = fbm(p1.xz + fbm(p1.xz + fbm(p1.xz, 6), 6), 6) * height;
    p1.y += h;

    // take a few pos to calculate a normal
    float3 p2 = pos.xyz + float3(step, 0.0, 0.0);
    float3 p3 = pos.xyz + float3(step, 0.0, step);

    p2.y += fbm(p2.xz + fbm(p2.xz + fbm(p2.xz, 6), 6), 6) * height;
    p3.y += fbm(p3.xz + fbm(p3.xz + fbm(p3.xz, 6), 6), 6) * height;

    float3 n = -cross(normalize(p2 - p1), normalize(p3 - p1));

    output.position = mul(view_projection_matrix, float4(p1, pos.w));
    output.colour = float4(h, h, h, 1.0) / float4(200.0, 200.0, 200.0, 1.0);
    output.world_pos = pos;
    output.texcoord = float4(input.texcoord, 0.0, 0.0);
    output.normal = n;

    return output;
}

struct ps_output_mrt {
    float4 albedo: SV_Target0;
    float4 normal: SV_Target1;
    float4 position: SV_Target2;
};

ps_output_mrt ps_heightmap_example_mrt(vs_output input) {
    ps_output_mrt output;
    output.albedo = float4(uv_gradient(input.colour.r), 1.0);
    output.normal = float4(input.normal.xyz * 0.5 + 0.5, 1.0);
    output.position = float4((input.position.xyz / float3(1024.0, 1024.0, 1024.0)) * 0.5 + 0.5, 1.0);
    return output;
}

[numthreads(32, 32, 1)]
void cs_heightmap_mrt_resolve(uint2 did: SV_DispatchThreadID, uint2 group_id: SV_GroupID) {
    // grab the output dimension from input0 (which we write to)
    uint2 half_dim = resources.input0.dimension / 2;
    
    // render into 4 quadrants
    float4 final = float4(0.0, 0.0, 0.0, 0.0);
    if(did.x < half_dim.x && did.y < half_dim.y) {
        // albedo
        final = msaa8x_textures[resources.input1.index].Load(did * 2, 0);
    }
    else if (did.x >= half_dim.x && did.y < half_dim.y) {
        // normals
        uint2 sc = did;
        sc.x -= half_dim.x;
        final = msaa8x_textures[resources.input2.index].Load(sc * 2, 0);
    }
    else if (did.x < half_dim.x && did.y >= half_dim.y) {
        // normals
        uint2 sc = did;
        sc.y -= half_dim.y;
        final = msaa8x_textures[resources.input3.index].Load(sc * 2, 0);
    }
    else if (did.x >= half_dim.x && did.y >= half_dim.y) {
        // depth
        uint2 sc = did;
        sc -= half_dim;
        final = msaa8x_textures[resources.input4.index].Load(sc * 2, 0);
    }

    rw_textures[resources.input0.index][did] = final;
}