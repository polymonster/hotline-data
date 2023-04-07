// returns constant pi
float pi() {
    return 3.141592653589793238462643;
}

// returns constant inverse pi (1.0/pi)
float inv_pi() {
    return 0.318309886;
}

// returns constant phi (golden ratio)
float phi() {
    return 1.61803399;
}

// returns constant tau which is the ratio of the circumference to the radius of a circle
float tau() {
    return 6.283185307179586;
}

// performs signed distance union of `d1` and `d2`
float op_union(float d1, float d2) {
    return min(d1,d2);
}

// performs subtract operation from 2 distance fields `d1` and `d2`
float op_subtract(float d1, float d2) {
    return max(-d1,d2);
}

// intersects 2 distance fields `d1` and `d2`
float op_intersect(float d1, float d2) {
    return max(d1,d2);
}

// signed distance from point `p` to a to sphere centred at 0 with radius `s`
float sd_sphere(float3 p, float s) {
    return length(p)-s;
}

// signed distance from point `p` to a box centred at 0 with half extents `b`
float sd_box(float3 p, float3 b) {
    float3 d = abs(p) - b;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

// signed distance from point `p` to an octahedron centred at 0 with half extents `b`
float sd_octahedron(float3 p, float s) {
    p = abs(p);
    return (p.x + p.y + p.z - s) * 0.57735027;
}

// unsigned distance from point `p` to a box centred at 0 with half extents `b`
float ud_box(float3 p, float3 b) {
    return length(max(abs(p) - b, 0.0));
}

// unsigned distance from point `p` to rounded box centred at 0 with extents `b` and roundness `r`
float ud_round_box(float3 p, float3 b, float r) {
    return length(max(abs(p) - b, 0.0)) - r;
}

// signed distance from point `p` to a cross with size `s`
float sd_cross(float3 p, float2 s) {
    float da = sd_box(p.xyz, float3(s.y, s.x, s.x));
    float db = sd_box(p.yzx, float3(s.x, s.y, s.x));
    float dc = sd_box(p.zxy, float3(s.x, s.x, s.y));
    return op_union(da, op_union(db, dc));
}

// signed distance from point `p` to a tourus with size `t`
float sd_torus(float3 p, float2 t) {
    float2 q = float2(length(p.xy) - t.x,p.z);
    return length(q)-t.y;
}

// signed distance from point `p` to a cylinder with size `c`
float sd_cylinder(float3 p, float3 c) {
    return length(p.xz - c.xy) - c.z;
}

// signed distance from point `p` to a cone with size `c` where `c` must be normalized
float sd_cone(float3 p, float2 c) {
    float q = length(p.xy);
    return dot(c, float2(q, p.z));
}

// signed distance from point `p` to a plane with equation `n` where `n` must be normalized
// and n.xyz = plane normal, n.w = plane constant
float sd_plane(float3 p, float4 n) {
  return dot(p, n.xyz) + n.w;
}

// hash3 is used for voronoise
float3 hash3(float2 p) {
    float3 q = float3(
        dot(p, float2(127.1,311.7)), 
        dot(p, float2(269.5,183.3)), 
        dot(p, float2(419.2,371.9))
    );
	return frac(sin(q)*43758.5453);
}

// supply a 2d coordniate to sample the noise (p)
// control the noise type with u and v:
// cell noise (blocky squares): u = 0, v = 0
// voronoi (voronoi like): u = 1, v = 0
// voronoi noise (voronoi like but soomth): u = 1, v = 1
// noise (perlin like): u = 0, v = 1
float voronoise(float2 p, float u, float v) {
	float k = 1.0 + 63.0 * pow(1.0-v, 6.0);
    float2 i = floor(p);
    float2 f = frac(p);
	float2 a = float2(0.0,0.0);
    for(int y = -2; y <= 2; y++) {
        for(int x = -2; x <= 2; x++) {
            float2 g = float2(x, y);
            float3 o = hash3(i + g) * float3(u, u, 1.0);
            float2 d = g - f + o.xy;
            float w = pow(1.0 - smoothstep( 0.0, 1.414, length(d)), k);
            a += float2(o.z * w, w);
        }
    }
    return a.x/a.y;
}

// lambertian diffuse, where `l` is the direction from the light to the surface and `n` is the surface normal
float lambert(float3 l, float3 n) {
    return saturate(1.0 - dot(n, l));
}

// phong specular term, where `l` is the direction from the light to the surface, `n` is the surface normal
// `v` is the direction from the camera to the surface, `ks` is the specular coefficient useful in range 0-1
// `shininess controls the size of the highlight and useful ranges from 0-1000
float phong(
    float3 l,
    float3 n,
    float3 v,
    float ks,
    float shininess
) {
    return saturate(ks * pow(max(dot(reflect(-l, n), v), 0.0), shininess));
}

// blinn specular term, where `l` is the direction from surface to the light and `n` is the surface normal
// `v` is the direction from the camera to the surface, `ks` is the specular coefficient useful in range 0-1
// `shininess controls the size of the highlight and useful ranges from 0-1000
float blinn(
    float3 l,
    float3 n,
    float3 v,
    float ks,
    float shininess
) {
    float3 half_vector = -normalize(l + v);
    return saturate(ks * pow(saturate(dot(half_vector, n)), shininess));
}

// cook-torrence specular term with microfacet distribution
// where `l` is the direction from the light to the surface, `n` is the surface normal and `v` is the direction from the
// camera to the surface, `roughness` is the surface roughness in 0-1 range and `k` is the reflectivity coefficient
float3 cook_torrence(
    float3 l,
    float3 n,
    float3 v,
    float roughness,
    float k
) {
    l = -l;

    float n_dot_l = dot(n, l);
    if( n_dot_l > 0.0f )
    {
        float roughness_sq = roughness * roughness;
        float3 hv = normalize(-v + l);
        
        float n_dot_v = dot(n, -v);
        float n_dot_h = dot(n, hv);
        float v_dot_h = dot(-v, hv);
        
        // geometric attenuation
        float n_dot_h_2 = 2.0f * n_dot_h;
        float g1 = (n_dot_h_2 * n_dot_v) / v_dot_h;
        float g2 = (n_dot_h_2 * n_dot_l) / v_dot_h;
        float geom_atten = min(1.0, min(g1, g2));
        
        // microfacet distribution function: beckmann
        float r1 = 1.0f / ( 4.0f * roughness_sq * pow(n_dot_h, 4.0f));
        float r2 = (n_dot_h * n_dot_h - 1.0) / (roughness_sq * n_dot_h * n_dot_h);
        float roughness_atten = r1 * exp(r2);
        
        // fresnel: schlick approximation
        float fresnel = pow(1.0 - v_dot_h, 5.0);
        fresnel *= roughness;
        fresnel += k;
                
        // specular
        float specular = (fresnel * geom_atten * roughness_atten) / (n_dot_v * n_dot_l * pi());
        return saturate(n_dot_l * (k + specular * (1.0 - k)));
    }
        
    return float3( 0.0, 0.0, 0.0 );
}

// oren nayar diffuse to model reflection from rough surfaces
// where `l` is the direction from the light to the surface, `n` is the surface normal 
// `v` is the direction from the camera to the surface, `lum` represents the surface luminosity
// and `roughness` controls surface roughness in 0-1 range
float3 oren_nayar(
    float3 l,
    float3 n,
    float3 v,
    float lum,
    float roughness
) {
    l = -l;
    float l_dot_v = dot(l, v);
    float n_dot_l = dot(n, l);
    float n_dot_v = dot(n, v);

    float s = l_dot_v - n_dot_l * n_dot_v;
    float t = lerp(1.0, max(n_dot_l, n_dot_v), step(0.0, s));

    float sigma2 = roughness * roughness;
    float A = 1.0 + sigma2 * (lum / (sigma2 + 0.13) + 0.5 / (sigma2 + 0.33));
    float B = 0.45 * sigma2 / (sigma2 + 0.09);

    return saturate(n_dot_l) * (A + B * s / t) / 3.141592653589793238462643;
}

// calculates point light attenuation in respect to radius, where the light pos and world pos
// are both in world space, the atteniuation has infinite fall off
float point_light_attenuation(float3 light_pos, float radius, float3 world_pos) {
    float d = length(world_pos.xyz - light_pos.xyz);
    float r = radius;    
    float denom = d/r + 1.0;
    return 1.0 / (denom*denom);
}

// calculates a point light attentuation falloff such that the returned value reaches 0.0
// at the radius of the light and 1.0 when the distance to light is 0
float point_light_attenuation_cutoff(float3 light_pos, float radius, float3 world_pos) {
    float r = radius;
    float d = length(world_pos.xyz - light_pos.xyz);
    d = max(d - r, 0.0);
    float denom = d/r + 1.0;
    float attenuation = 1.0 / (denom*denom);
    float cutoff = 0.2;
    attenuation = (attenuation - cutoff) / (1.0 - cutoff);
    return max(attenuation, 0.0);
}

// creates a crt scaline effect, returning src modulated, `tc` defines 0-1 uv space and tscale defines
// the scale of the crt texel size, use 1.0/image_size for 1:1 mapping, but you can tweak that for different effects
float3 crt_c(float3 src, float2 tc, float2 tscale) {
    float2 ca = float2(tscale.x * 2.0, 0.0);
    src.rgb *= saturate(abs(sin(tc.y / tscale.y/2.0)) + 0.5);
    return src;
}

// bends texcoords to create a crt monitor like curvature for the given `uv` in 0-1 range
float2 bend_tc(float2 uv){
    float2 tc = uv;
    float2 cc = tc - 0.5;
    float dist = dot(cc, cc) * 0.07;
    tc = tc * (tc + cc * (1.0 + dist) * dist) / tc;
    return tc;
}

// biased sin
float bsin(float v) {
    return sin(v) * 0.5 + 1.0;
}

// biased cos
float bcos(float v) {
    return cos(v) * 0.5 + 1.0;
}