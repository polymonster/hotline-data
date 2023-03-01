float random(float2 st) {
    return frac(sin(dot(st.xy, float2(12.9898,78.233))) * 43758.5453123);
}

// https://www.shadertoy.com/view/4dS3Wd
float noise(float2 st) {

    float2 i = floor(st);
    float2 f = frac(st);

    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + float2(1.0, 0.0));
    float c = random(i + float2(0.0, 1.0));
    float d = random(i + float2(1.0, 1.0));

    float2 u = f * f * (3.0 - 2.0 * f);

    return lerp(a, b, u.x) + (c - a)* u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

#define OCTAVES 6
float fbm(float2 st) {
    float value = 0.0;
    float amplitude = 0.3;
    float frequency = 0.0;

    for (int i = 0; i < OCTAVES; i++) {
        value += amplitude * noise(st);
        st *= 3.0;
        amplitude *= 0.8;
    }
    return value;
}

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