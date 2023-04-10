#include "maths.hlsl"

struct vs_input_mesh {
    float3 position : POSITION;
    float2 texcoord: TEXCOORD0;
    float3 normal : TEXCOORD1;
    float3 tangent : TEXCOORD2;
    float3 bitangent : TEXCOORD3;
};

struct vs_input_instance {
    float4 row0 : TEXCOORD4;
    float4 row1 : TEXCOORD5;
    float4 row2 : TEXCOORD6;
    float4 row3 : TEXCOORD7;
};

struct vs_input_entity_ids {
    uint4 ids : TEXCOORD4;
};

struct vs_output {
    float4 position : SV_POSITION0;
    float4 world_pos: TEXCOORD0;
    float4 texcoord: TEXCOORD1;
    float4 colour: TEXCOORD2;
    float3 normal: TEXCOORD3;
};

struct vs_output_material {
    float4 position : SV_POSITION0;
    float4 world_pos: TEXCOORD0;
    float4 texcoord: TEXCOORD1;
    float4 colour: TEXCOORD2;
    float3 normal: TEXCOORD3;
    uint4  ids: TEXCOORD4;
};

struct ps_output {
    float4 colour : SV_Target;
};

cbuffer view_push_constants : register(b0) {
    float4x4 view_projection_matrix;
    float4   view_position;
};

cbuffer draw_push_constants : register(b1) {
    float3x4 world_matrix;
    float4   material_colour;
    uint4    draw_indices;
};

// move to test.hlsl
struct cbuffer_instance_data {
    float3x4 cbuffer_world_matrix[1024];
};
ConstantBuffer<cbuffer_instance_data> cbuffer_instance : register(b1);

struct draw_data {
    float3x4 entity_world_matrix;
};

struct material_data {
    uint albedo_id;
    uint normal_id;
    uint roughness_id;
    uint padding;
};

// the x value holds the srv index to look up in materials[] etc and the y component holds the count in the buffer
struct world_buffer_info_data {
    uint2 draw;
    uint2 material;
    uint2 point_light;
    uint2 spot_light;
    uint2 directional_light;
};

struct point_light_data {
    float3 pos;
    float  radius;
    float4 colour;
};

struct spot_light_data {
    float3 pos;
    float  cutoff;
    float3 dir;
    float  falloff;
    float4 colour;
};

ConstantBuffer<world_buffer_info_data> world_buffer_info : register(b2);

// alias texture types on t0
Texture2D textures[] : register(t0);
TextureCube cubemaps[] : register(t0);
Texture2DArray texture_arrays[] : register(t0);
Texture3D volume_textures[] : register(t0);

StructuredBuffer<draw_data> draws[] : register(t0, space0);
StructuredBuffer<material_data> materials[] : register(t0, space1);
StructuredBuffer<point_light_data> point_lights[] : register(t0, space2);
StructuredBuffer<spot_light_data> spot_lights[] : register(t0, space3);

Texture2D textures_debug[] : register(t1);

SamplerState sampler_wrap_linear : register(s0);

float3 uv_gradient(float x) {
    float3 rgb_uv = float3(0.0, 0.0, 0.0);
    float grad = x % 1.0;
    if (grad < 0.333) {
        rgb_uv = lerp(float3(1.0, 0, 0.0), float3(0.0, 1.0, 0.0), grad * 3.333);
    }
    else if (grad < 0.666) {
        rgb_uv = lerp(float3(0.0, 1.0, 0.0), float3(0.0, 0.0, 1.0), (grad - 0.333) * 3.333);
    }
    else {
        rgb_uv = lerp(float3(0.0, 0.0, 1.0), float3(1.0, 0.0, 0.0), (grad - 0.666) * 3.333);
    }
    return rgb_uv;
}

float3 chebyshev_normalize(float3 v) {
    return (v.xyz / max(max(abs(v.x), abs(v.y)), abs(v.z)));
}

vs_output vs_mesh(vs_input_mesh input) {
    vs_output output;

    float3x4 wm = world_matrix;
    
    float4 pos = float4(input.position.xyz, 1.0);
    pos.xyz = mul(wm, pos);

    output.position = mul(view_projection_matrix, pos);
    output.world_pos = pos;
    output.texcoord = float4(input.texcoord, 0.0, 0.0);
    output.colour = material_colour;
    output.normal = input.normal.xyz;
    
    return output;
}

vs_output_material vs_mesh_material(vs_input_mesh input, vs_input_entity_ids entity_input) {
    vs_output_material output;

    // draw call lookup
    uint entity_id = entity_input.ids[0];
    uint draw_buffer_id = world_buffer_info.draw.x;
    float3x4 wm = draws[draw_buffer_id][entity_id].entity_world_matrix;
    float4 pos = float4(input.position.xyz, 1.0);
    pos.xyz = mul(wm, pos);

    // material lookup
    uint material_buffer_id = world_buffer_info.material.x;
    uint material_id = entity_input.ids[1];
    material_data mat = materials[material_buffer_id][material_id];

    output.position = mul(view_projection_matrix, pos);
    output.world_pos = pos;
    output.texcoord = float4(input.texcoord, 0.0, 0.0);
    output.colour = wm[0] * 0.5 + 0.5;
    output.normal = input.normal.xyz;
    output.ids = uint4(mat.albedo_id, mat.normal_id, mat.roughness_id, mat.padding);
    
    return output;
}

vs_output vs_texture3d(vs_input_mesh input) {
    vs_output output;

    float3x4 wm = world_matrix;
    
    float4 pos = float4(input.position.xyz, 1.0);
    pos.xyz = mul(wm, pos);

    output.position = mul(view_projection_matrix, pos);
    output.world_pos = pos;
    output.texcoord = float4(input.position, 0.0);
    output.colour = float4(input.normal.xyz, 1.0);
    output.normal = input.normal.xyz;
    
    return output;
}

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

ps_output ps_constant_colour(vs_output input) {
    ps_output output;
    output.colour = input.colour;
    return output;
}

ps_output ps_wireframe(vs_output input) {
    ps_output output;
    output.colour = float4(0.2, 0.2, 0.2, 1.0);
    return output;
}

ps_output ps_checkerboard(vs_output input) {
    ps_output output;
    output.colour = float4(input.normal.xyz * 0.5 + 0.5, 1.0);

    // checkerboard uv
    float u = (input.texcoord.x);
    float v = (input.texcoord.y);

    float size = 8.0;
    float x = u * size;
    float y = v * size;

    float ix;
    modf(x, ix);
    float rx = fmod(ix, 2.0) == 0.0 ? 0.0 : 1.0;

    float iy;
    modf(y, iy);
    float ry = fmod(iy, 2.0) == 0.0 ? 0.0 : 1.0;

    float rxy = rx + ry > 1.0 ? 0.0 : rx + ry;

    output.colour.rgb *= rxy < 0.001 ? 0.66 : 1.0;

    // debug switches

    // u gradient
    //output.colour.rgb = uv_gradient(u % 1.0);

    // v gradient
    //output.colour.rgb = uv_gradient(v % 1.0);

    output.colour.a = 1.0;

    return output;
}

ps_output ps_texture2d(vs_output input) {
    ps_output output;

    float2 tc = input.texcoord.xy;
    float4 albedo = textures[draw_indices.x].Sample(sampler_wrap_linear, tc);
    
    albedo *= albedo.a;
    output.colour = albedo;

    return output;
}

ps_output ps_cubemap(vs_output input) {
    ps_output output;

    float4 col = cubemaps[draw_indices.x]
        .SampleLevel(sampler_wrap_linear, input.normal, draw_indices.y);

    output.colour = col;
    output.colour.a = 1.0;

    return output;
}

ps_output ps_texture2d_array(vs_output input) {
    ps_output output;

    float2 tc = float2(input.texcoord.x, input.texcoord.y);

    float4 col = texture_arrays[draw_indices.x]
        .Sample(sampler_wrap_linear, float3(tc, draw_indices.y));

    if(col.a < 0.2) {
        discard;
    }

    output.colour = col;

    return output;
}

ps_output ps_volume_texture_ray_march_sdf(vs_output input) {
    ps_output output;

    float3 v = input.texcoord.xyz;
    float3 chebyshev_norm = chebyshev_normalize(v);
    float3 uvw = chebyshev_norm * 0.5 + 0.5;
    
    float max_samples = 64.0;

    float3x3 inv_rot;
    inv_rot[0] = world_matrix[0].xyz;
    inv_rot[1] = world_matrix[1].xyz;
    inv_rot[2] = world_matrix[2].xyz;
    inv_rot = transpose(inv_rot);

    float3 ray_dir = normalize(input.world_pos.xyz - view_position.xyz);
                    
    ray_dir = mul(inv_rot, ray_dir);
    ray_dir = normalize(ray_dir);
                    
    float3 vddx = ddx( uvw );
    float3 vddy = ddy( uvw );
    
    float3 scale = float3(
        length(world_matrix[0].xyz), 
        length(world_matrix[1].xyz), 
        length(world_matrix[2].xyz)
    ) * 2.0;
        
    float d = volume_textures[draw_indices.x].SampleGrad(sampler_wrap_linear, uvw, vddx, vddy).r;
    
    float3 col = float3( 0.0, 0.0, 0.0 );
    float3 ray_pos = input.world_pos.xyz;
    float taken = 0.0;
    float3 min_step = (scale / max_samples); 
    
    for( int s = 0; s < int(max_samples); ++s )
    {        
        taken += 1.0 / max_samples;
                
        d = volume_textures[draw_indices.x].SampleGrad(sampler_wrap_linear, uvw, vddx, vddy).r;
            
        float3 step = ray_dir.xyz * float3(d / scale) * 0.5;
        
        uvw += step;
 
        if(uvw.x >= 1.0 || uvw.x <= 0.0)
            discard;
        
        if(uvw.y >= 1.0 || uvw.y <= 0.0)
            discard;
        
        if(uvw.z >= 1.0 || uvw.z <= 0.0)
            discard;
            
        if( d <= 0.3 )
            break;
    }
    float vd = (1.0 - d);
    output.colour.rgb = float3(vd*vd,vd*vd, vd*vd);
    output.colour.rgb = float3(taken, taken, taken);
    output.colour.a = 1.0;

    return output;
}

ps_output ps_volume_texture_ray_march(vs_output input) {
    ps_output output;
    
    float depth = 1.0;
    float max_samples = 256.0;
        
    float3 v = input.texcoord.xyz;
    float3 chebyshev_norm = chebyshev_normalize(v);
    float3 uvw = chebyshev_norm * 0.5 + 0.5;
    
    float3x3 inv_rot;
    inv_rot[0] = world_matrix[0].xyz;
    inv_rot[1] = world_matrix[1].xyz;
    inv_rot[2] = world_matrix[2].xyz;
    inv_rot = transpose(inv_rot);
        
    float3 ray_dir = normalize(input.world_pos.xyz - view_position.xyz);    
    ray_dir = mul( inv_rot, ray_dir );
    
    float3 ray_step = chebyshev_normalize(ray_dir.xyz) / max_samples;
                
    float depth_step = 1.0 / max_samples;
    
    float3 vddx = ddx( uvw );
    float3 vddy = ddy( uvw );
    
    for(int s = 0; s < int(max_samples); ++s )
    {
        output.colour = 
            volume_textures[draw_indices.x].SampleGrad(sampler_wrap_linear, uvw, vddx, vddy);
        
        if(output.colour.a != 0.0)
            break;
        
        depth -= depth_step;
        uvw += ray_step;
        
        if(uvw.x > 1.0 || uvw.x < 0.0)
            discard;
            
        if(uvw.y > 1.0 || uvw.y < 0.0)
            discard;
            
        if(uvw.z > 1.0 || uvw.z < 0.0)
            discard;
        
        if(s == int(max_samples)-1)
            discard;
    }
    
    output.colour.rgb *= lerp( 0.5, 1.0, depth );
            
    return output;
}

ps_output ps_mesh_material(vs_output_material input) {
    ps_output output;
    output.colour = input.colour;

    float2 tc = input.texcoord.xy;
    float4 albedo = textures_debug[input.ids[0]].Sample(sampler_wrap_linear, tc);
    output.colour = albedo;

    return output;
}

 ps_output ps_mesh_lit(vs_output input) {
    ps_output output;
    output.colour = input.colour;

    int i = 0;
    float ks = 2.0;
    float shininess = 32.0;
    float roughness = 0.1;
    float k = 0.3;

    float3 v = normalize(input.world_pos.xyz - view_position.xyz);
    float3 n = input.normal;

    // point lights
    uint point_lights_id = world_buffer_info.point_light.x;
    uint point_lights_count = world_buffer_info.point_light.y;
    for(i = 0; i < point_lights_count; ++i) {
        point_light_data light = point_lights[point_lights_id][i];

        float3 l = normalize(input.world_pos.xyz - light.pos);

        float diffuse = lambert(l, n);
        float specular = cook_torrence(l, n, v, roughness, k);

        float atteniuation = point_light_attenuation(
            light.pos,
            light.radius,
            input.world_pos
        );
        
        output.colour += atteniuation * light.colour * diffuse;
        output.colour += atteniuation * light.colour * specular;
    }

    // spot lights
    uint spot_lights_id = world_buffer_info.spot_light.x;
    uint spot_lights_count = world_buffer_info.spot_light.y;
    for(i = 0; i < spot_lights_count; ++i) {
        spot_light_data light = spot_lights[spot_lights_id][i];

        float3 l = normalize(input.world_pos.xyz - light.pos);

        float diffuse = lambert(l, n);
        float specular = cook_torrence(l, n, v, roughness, k);

        float atteniuation = spot_light_attenuation(
            l,
            light.dir,
            light.cutoff,
            light.falloff
        );
        
        output.colour += atteniuation * light.colour * diffuse;
        output.colour += atteniuation * light.colour * specular;
    }

    return output;
 }