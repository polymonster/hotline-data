
float4 vs_depth_only(vs_input_mesh input) : SV_POSITION {
    float4 pos = float4(input.position.xyz, 1.0);
    pos.xyz = mul(world_matrix, pos);

    float4 output = mul(view_projection_matrix, pos);
    return output;
}

float4 ps_single_directional_shadow(vs_output input) : SV_Target {
    float4 output = input.colour;

    int i = 0;
    float ks = 2.0;
    float shininess = 32.0;
    float roughness = 0.1;
    float k = 0.3;

    float3 v = normalize(input.world_pos.xyz - view_position.xyz);
    float3 n = input.normal;

    // single directional light
    uint directional_lights_id = world_buffer_info.directional_light.x;
    directional_light_data light = directional_lights[directional_lights_id][0];

    int shadow_map_index = light.shadow_map.srv_index;
    float4x4 shadow_matrix = get_shadow_matrix(light.shadow_map.matrix_index);
    
    // project shadow coord
    float4 offset_pos = float4(input.world_pos.xyz + n.xyz * 0.001, 1.0);

    float4 sp = mul(shadow_matrix, offset_pos);
    sp.xyz /= sp.w;
    sp.y *= -1.0;
    sp.xy = sp.xy * 0.5 + 0.5;

    float shadow_sample = textures[shadow_map_index].Sample(sampler_clamp_point, sp.xy).r;
    float shadow = sp.z < shadow_sample;
    

    float3 l = light.dir.xyz;
    float diffuse = lambert(l, n);
    float specular = cook_torrance(l, n, v, roughness, k);

    output += light.colour * diffuse;
    output += light.colour * specular;

    output *= max(shadow, 0.3);

    return output;
}