struct vs_input_entity_ids {
    uint4 ids: TEXCOORD4;
};

struct vs_output_material {
    float4 position: SV_POSITION0;
    float4 world_pos: TEXCOORD0;
    float4 texcoord: TEXCOORD1;
    float4 colour: TEXCOORD2;
    float3 normal: TEXCOORD3;
    float3 tangent: TEXCOORD4;
    float3 bitangent: TEXCOORD5;
    uint4  ids: TEXCOORD6;
};

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
    output.normal = normalize(mul(rot, input.normal));
    output.tangent = normalize(mul(rot, input.tangent));
    output.bitangent = normalize(mul(rot, input.bitangent));
    
    // mat
    material_data mat = get_material_data(entity_input.ids[1]);
    output.ids = uint4(mat.albedo_id, mat.normal_id, mat.roughness_id, mat.padding);
    
    return output;
}

vs_output_material vs_mesh_material_indirect(vs_input_mesh input) {
    vs_output_material output;

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

    float3x3 rot = (float3x3)draw.world_matrix;
    output.normal = normalize(mul(rot, input.normal));
    output.tangent = normalize(mul(rot, input.tangent));
    output.bitangent = normalize(mul(rot, input.bitangent));

    material_data mat = get_material_data(indirect_ids.y);
    output.ids = uint4(mat.albedo_id, mat.normal_id, mat.roughness_id, mat.padding);
    
    return output;
}

vs_output_material vs_mesh_lit(vs_input_mesh input) {
    vs_output_material output;

    float3x4 wm = world_matrix;
    float4 pos = float4(input.position.xyz, 1.0);
    pos.xyz = mul(wm, pos);

    output.position = mul(view_projection_matrix, pos);
    output.world_pos = pos;
    output.texcoord = float4(input.texcoord, 0.0, 0.0);

    float3x3 rot = (float3x3)wm;
    output.normal = normalize(mul(rot, input.normal));
    output.tangent = normalize(mul(rot, input.tangent));
    output.bitangent = normalize(mul(rot, input.bitangent));
    output.ids = uint4(0, 0, 0, 0);

    return output;
}

ps_output ps_mesh_debug_tangent_space(vs_output_material input) {
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