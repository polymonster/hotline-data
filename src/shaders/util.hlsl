//
// utilties to compile into the core hotline engine
//

cbuffer mip_info : register(b0) {
    uint read;
    uint write;
};

RWTexture2D<float4> rw_texture[] : register(u0, space0);
groupshared uint4 group_accumulated[5];

[numthreads(32, 32, 1)]
void cs_mip_chain_texture2d(uint2 did: SV_DispatchThreadID) {
    uint2 offsets[9];
    offsets[0] = uint2( 0,  0);
    offsets[1] = uint2(-1, -1);
    offsets[2] = uint2(-1,  0);
    offsets[3] = uint2(-1,  1);
    offsets[4] = uint2( 0,  1);
    offsets[5] = uint2( 1,  1);
    offsets[6] = uint2( 1,  0);
    offsets[7] = uint2( 1, -1);
    offsets[8] = uint2( 0, -1);

    pmfx_touch(group_accumulated[0]);

    float4 level_up = float4(0.0, 0.0, 0.0, 0.0);
    
    for(int i = 0; i < 9; ++i) {
        level_up += rw_texture[read][did.xy * 2];
    }
    
    //rw_texture[write][did.xy] = float4(1.0, 0.0, 1.0, 1.0);
    rw_texture[write][did.xy] = level_up / 9.0;
}