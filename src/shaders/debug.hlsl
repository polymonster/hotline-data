#include "maths.hlsl"
#include "ecs.hlsl"

struct vs_input_entity_ids {
    uint4 ids: TEXCOORD4;
};

struct vs_output {
    float4 position: SV_POSITION0;
    float4 world_pos: TEXCOORD0;
    float4 texcoord: TEXCOORD1;
    float4 colour: TEXCOORD2;
    float3 normal: TEXCOORD3;
};

struct vs_output_material {
    float4 position: SV_POSITION0;
    float4 world_pos: TEXCOORD0;
    float4 texcoord: TEXCOORD1;
    float4 colour: TEXCOORD2;
    float3 normal: TEXCOORD3;
    float4 tangent: TEXCOORD4;
    float4 bitangent: TEXCOORD5;
    uint4  ids: TEXCOORD6;
};

struct vs_output_lit {
    float4 position: SV_POSITION0;
    float4 world_pos: TEXCOORD0;
    float4 texcoord: TEXCOORD1;
    float4 normal: TEXCOORD2;
    float4 tangent: TEXCOORD3;
    float4 bitangent: TEXCOORD4;
};

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

    // get draw call info and transform world matrix
    draw_data draw = get_draw_data(entity_input.ids[0]);
    float4 pos = float4(input.position.xyz, 1.0);    
    pos.xyz = mul(draw.world_matrix, pos);

    output.position = mul(view_projection_matrix, pos);
    output.world_pos = pos;
    output.texcoord = float4(input.texcoord, 0.0, 0.0);
    
    float3x3 rot = (float3x3)draw.world_matrix;
    output.normal = float4(normalize(mul(rot, input.normal)), 1.0);
    output.tangent = float4(normalize(mul(rot, input.tangent)), 1.0);
    output.bitangent = float4(normalize(mul(rot, input.bitangent)), 1.0);
    
    // mat
    material_data mat = get_material_data(entity_input.ids[1]);
    output.ids = uint4(mat.albedo_id, mat.normal_id, mat.roughness_id, mat.padding);
    
    return output;
}

vs_output_lit vs_mesh_lit(vs_input_mesh input) {
    vs_output_lit output;

    float3x4 wm = world_matrix;
    float4 pos = float4(input.position.xyz, 1.0);
    pos.xyz = mul(wm, pos);

    output.position = mul(view_projection_matrix, pos);
    output.world_pos = pos;
    output.texcoord = float4(input.texcoord, 0.0, 0.0);

    float3x3 rot = (float3x3)wm;
    output.normal = float4(normalize(mul(rot, input.normal)), 1.0);
    output.tangent = float4(normalize(mul(rot, input.tangent)), 1.0);
    output.bitangent = float4(normalize(mul(rot, input.bitangent)), 1.0);
    
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

ps_output ps_mesh_debug_tangent_space(vs_output_lit input) {
    ps_output output;
    output.colour = float4(0.0, 0.0, 0.0, 0.0);

    float3 ts_normal = textures[draw_indices.x].Sample(sampler_wrap_linear, input.texcoord.xy).xyz;
    ts_normal = ts_normal * 2.0 - 1.0;

    float3x3 tbn;
    tbn[0] = input.tangent.xyz;
    tbn[1] = input.bitangent.xyz;
    tbn[2] = input.normal.xyz;

    float3 normal = mul(ts_normal, tbn);

    output.colour.rgb = normal;
    output.colour.rgb = output.colour.rgb * 0.5 + 0.5;

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
    output.colour = float4(0.0, 0.0, 0.0, 0.0);

    float2 tc = input.texcoord.xy;
    
    // sample maps

    // albedo
    float4 albedo = textures[input.ids.x].Sample(sampler_wrap_linear, tc);

    // normal
    float3 ts_normal = textures[input.ids.y].Sample(sampler_wrap_linear, tc).xyz;
    ts_normal = ts_normal * 2.0 - 1.0;

    float3x3 tbn;
    tbn[0] = input.tangent.xyz;
    tbn[1] = input.bitangent.xyz;
    tbn[2] = input.normal.xyz;
    float3 n = mul(ts_normal, tbn);

    // roughness
    float roughness = textures[input.ids.z].Sample(sampler_wrap_linear, tc).r;

    float k = 0.3;
    float3 v = normalize(input.world_pos.xyz - view_position.xyz);

    // point lights
    uint point_lights_id = world_buffer_info.point_light.x;
    uint point_lights_count = world_buffer_info.point_light.y;

    if(point_lights_id != 0) {
        int i = 0;
        for(i = 0; i < point_lights_count; ++i) {
            point_light_data light = point_lights[point_lights_id][i];

            float3 l = normalize(input.world_pos.xyz - light.pos);

            float diffuse = lambert(l, n);
            float specular = cook_torrance(l, n, v, roughness, k);

            float atteniuation = point_light_attenuation(
                light.pos,
                light.radius,
                input.world_pos.xyz
            );
            
            output.colour += atteniuation * light.colour * diffuse * albedo;
            output.colour += atteniuation * light.colour * specular;
        }
    }

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
        float specular = cook_torrance(l, n, v, roughness, k);

        float atteniuation = point_light_attenuation(
            light.pos,
            light.radius,
            input.world_pos.xyz
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
        float specular = cook_torrance(l, n, v, roughness, k);

        float atteniuation = spot_light_attenuation(
            l,
            light.dir,
            light.cutoff,
            light.falloff
        );
        
        output.colour += atteniuation * light.colour * diffuse;
        output.colour += atteniuation * light.colour * specular;
    }

    // directional lights
    uint directional_lights_id = world_buffer_info.directional_light.x;
    uint directional_lights_count = world_buffer_info.directional_light.y;
    for(i = 0; i < directional_lights_count; ++i) {
        directional_light_data light = directional_lights[directional_lights_id][i];

        float3 l = light.dir.xyz;
        float diffuse = lambert(l, n);
        float specular = cook_torrance(l, n, v, roughness, k);

        output.colour += light.colour * diffuse;
        output.colour += light.colour * specular;
    }

    return output;
}

vs_output vs_mesh_indirect(vs_input_mesh input) {
    vs_output output;

    // get draw call info and transform world matrix
    draw_data draw = get_draw_data(indirect_ids.x);
    float4 pos = float4(input.position.xyz, 1.0);    
    pos.xyz = mul(draw.world_matrix, pos);

    // get camera data and transform projection matrix
    camera_data main_camera = get_camera_data();

    output.position = mul(main_camera.view_projection_matrix, pos);
    output.world_pos = pos;
    output.texcoord = float4(input.texcoord, 0.0, 0.0);
    output.colour = float4(1.0, 1.0, 1.0, 1.0);
    output.normal = input.normal.xyz;
    
    return output;
}