RWTexture3D<float4> rwtex[] : register(u0);

[numthreads(16, 16, 1)]
void cs_blank(uint3 did : SV_DispatchThreadID) {
    rwtex[0][did.xyz] = float4(0.0, 0.0, 0.0, 0.0);
}