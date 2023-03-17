// #pragma pack_matrix(row_major)

struct vs_output {
    float4 position : SV_POSITION0;
    float4 colour: TEXCOORD0;
    float2 texcoord: TEXCOORD1;
};

struct ps_output {
    float4 colour : SV_Target;
};

cbuffer view_push_constants : register(b0) {
    float4x4 view_matrix;
    float4x4 projection_matrix;
    float4x4 view_projection_matrix;
};

cbuffer draw_push_constants : register(b1) {
    float3x4 world_matrix;
    float4   draw_colour;
};

struct cbuffer_instance_data {
    float3x4 cbuffer_world_matrix[1024];
};
ConstantBuffer<cbuffer_instance_data> cbuffer_instance : register(b1);

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

vs_output vs_mesh(vs_input_mesh input) {
    vs_output output;

    float3x4 wm = world_matrix;
    
    float4 pos = float4(input.position.xyz, 1.0);
    pos.xyz = mul(wm, pos);

    output.position = mul(view_projection_matrix, pos);
 
    output.colour = float4(input.normal.xyz * 0.5 + 0.5, 1.0);
    output.texcoord = input.texcoord;
    
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

    output.colour = float4(input.normal.xyz * 0.5 + 0.5, 1.0);
    output.texcoord = input.texcoord;
    
    return output;
}

vs_output vs_mesh_cbuffer_instanced(vs_input_mesh input, uint iid: SV_InstanceID) {
    vs_output output;

	float4 pos = float4(input.position.xyz, 1.0);
    pos.xyz = mul(cbuffer_instance.cbuffer_world_matrix[iid], pos);

    output.position = mul(view_projection_matrix, pos);
    output.colour = float4(input.normal.xyz * 0.5 + 0.5, 1.0);

    output.texcoord = input.texcoord;
    return output;
}

vs_output vs_billboard(vs_input_mesh input) {
    vs_output output;

    float4 pos = float4(input.position.xyz, 1.0);
    pos = mul(world_matrix, pos);

    output.position = mul(view_projection_matrix, pos);
    output.colour = float4(input.normal.xyz * 0.5 + 0.5, 1.0);
    output.texcoord = input.texcoord;

    return output;
}

ps_output ps_main(vs_output input) {
    ps_output output;
    output.colour = input.colour;
    return output;
}

ps_output ps_wireframe(vs_output input) {
    ps_output output;
    output.colour = float4(0.2, 0.2, 0.2, 1.0);
    return output;
}

ps_output ps_constant_colour(vs_output input) {
    ps_output output;
    output.colour = draw_colour;
    return output;
}

ps_output ps_checkerboard(vs_output input) {
    ps_output output;
    output.colour = input.colour;

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

    // u gradient
    //output.colour.rgb = uv_gradient(u % 1.0);

    // v gradient
    //output.colour.rgb = uv_gradient(v % 1.0);

    output.colour.a = 1.0;
    return output;
}