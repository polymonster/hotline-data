//
// contains core descriptor layout to be used among different / shared ecs systems
//

// per view constants with basic camera transforms
cbuffer view_push_constants : register(b0) {
    float4x4 view_projection_matrix;
    float4   view_position;
};

// per entity draw constants used in CPU draw calls
cbuffer draw_push_constants : register(b1) {
    float3x4 world_matrix;
    float4   material_colour;
    uint4    draw_indices;
};

// per indirect draw, indirect_ids.x = entity_id
cbuffer indirect_push_constants : register(b1) {
    uint4 indirect_ids;
};

// bindless draw data for entites to look up by ID
struct draw_data {
    float3x4 world_matrix;
};

// bindless material ID's which can be looked up into textures array
struct material_data {
    uint albedo_id;
    uint normal_id;
    uint roughness_id;
    uint padding;
};

// the x value holds the srv index to look up in materials[] etc and the y component holds the count in the buffer
struct world_buffer_info_data {
    uint2 draw;
    uint2 extent;
    uint2 material;
    uint2 point_light;
    uint2 spot_light;
    uint2 directional_light;
    uint2 camera;
};

// point light parameters
struct point_light_data {
    float3 pos;
    float  radius;
    float4 colour;
};

// spot light parameters
struct spot_light_data {
    float3 pos;
    float  cutoff;
    float3 dir;
    float  falloff;
    float4 colour;
};

// directional light data
struct directional_light_data {
    float4 dir;
    float4 colour;
}

// camera data
struct camera_data {
    float4x4 view_projection_matrix;
    float4   view_position;
    float4   planes[6];
}

// extent data
struct extent_data {
    float3 pos;
    float3 extent;
};

// structures of arrays for indriect / bindless lookups
StructuredBuffer<draw_data> draws[] : register(t0, space0);
StructuredBuffer<extent_data> extents[] : register(t0, space0);
StructuredBuffer<material_data> materials[] : register(t0, space1);
StructuredBuffer<point_light_data> point_lights[] : register(t0, space2);
StructuredBuffer<spot_light_data> spot_lights[] : register(t0, space3);
StructuredBuffer<directional_light_data> directional_lights[] : register(t0, space4);

// main constants to obtain the indices of the buffer types
ConstantBuffer<world_buffer_info_data> world_buffer_info : register(b2);

// camera data for bindless camera lookups
ConstantBuffer<camera_data> cameras[] : register(b3);

// samplers
SamplerState sampler_wrap_linear : register(s0);

// utility functions to lookup entity draw data
draw_data get_draw_data(uint entity_index) {
    return draws[world_buffer_info.draw.x][entity_index];
}

// utility functions to lookup entity extent data used for culling
extent_data get_extent_data(uint entity_index) {
    return extents[world_buffer_info.extent.x][entity_index];
}

// utility functions to lookup material data
material_data get_material_data(uint material_index) {
    return materials[world_buffer_info.material.x][material_index];
}

// utility functions to lookup camera data
camera_data get_camera_data() {
    return cameras[world_buffer_info.camera.x];
}