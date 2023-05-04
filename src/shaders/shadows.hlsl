
float4 vs_depth_only(vs_input_mesh input) : SV_POSITION {
    float4 pos = float4(input.position.xyz, 1.0);
    pos.xyz = mul(world_matrix, pos);

    float4 output = mul(view_projection_matrix, pos);
    return output;
}

float sample_shadow_pcf_9(float3 sp, uint sm_index, float2 sm_size) {
    float2 samples[9];
    float2 inv_sm_size = 1.0 / sm_size;
    samples[0] = float2(-1.0, -1.0) * inv_sm_size;
    samples[1] = float2(-1.0, 0.0) * inv_sm_size;
    samples[2] = float2(-1.0, 1.0) * inv_sm_size;
    samples[3] = float2(0.0, -1.0) * inv_sm_size;
    samples[4] = float2(0.0, 0.0) * inv_sm_size;
    samples[5] = float2(0.0, 1.0) * inv_sm_size;
    samples[6] = float2(1.0, -1.0) * inv_sm_size;
    samples[7] = float2(1.0, 0.0) * inv_sm_size;
    samples[8] = float2(1.0, 1.0) * inv_sm_size;
    
    float shadow = 0.0;
    for(int j = 0; j < 9; ++j) {
        shadow += textures[sm_index].SampleCmp(sampler_shadow_compare, sp.xy + samples[j], 0.0);
    }
    shadow /= 9.0;


    shadow = textures[sm_index].SampleCmp(sampler_shadow_compare, sp.xy, sp.z);
    return shadow;
}

float4 ps_single_directional_shadow(vs_output input) : SV_Target {
    float4 output = float4(0.0, 0.0, 0.0, 0.0);

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
    float4 offset_pos = float4(input.world_pos.xyz, 1.0);

    float4 sp = mul(shadow_matrix, offset_pos);
    sp.xyz /= sp.w;
    sp.y *= -1.0;
    sp.xy = sp.xy * 0.5 + 0.5;

    float shadow_sample = textures[shadow_map_index].Sample(sampler_clamp_point, sp.xy).r;
    float shadow = sp.z >= shadow_sample ? 0.0 : 1.0;

    shadow = sample_shadow_pcf_9(sp, shadow_map_index, float2(4096, 4096));

    float3 l = light.dir.xyz;
    float diffuse = lambert(l, n);
    float specular = cook_torrance(l, n, v, roughness, k);

    if(dot(n, l) >= 0.0) {
        shadow = 0.0;
    }

    float4 lit_colour = light.colour * diffuse + light.colour * specular;
    output = lit_colour * shadow + light.colour * 0.2;

    //output = float4(shadow, shadow, shadow, 1.0);

    return output;
}