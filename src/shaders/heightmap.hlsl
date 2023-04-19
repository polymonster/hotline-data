#include "maths.hlsl"

vs_output vs_heightmap(vs_input_mesh input) {
    vs_output output;

	float4 pos = float4(input.position.xyz, 1.0);

    float2 p = pos.xz;
    float h = fbm(p + fbm( p + fbm(p)));
    pos.y += h;

    (world_matrix);
    pos = mul(pos, world_matrix);

    output.position = mul(pos, projection_matrix);
    output.colour = float4(h, h, h, 1.0);
    return output;
}