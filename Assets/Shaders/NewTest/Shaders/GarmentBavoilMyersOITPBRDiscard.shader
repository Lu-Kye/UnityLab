Shader "KGame/Garment BavoilMyers OIT PBR Discard" {

Properties {
    _AmbientColor("AmbientColor", Color) = (1.000000, 1.000000, 1.000000, 1.000000)
    _AmbientScale("AmbientScale", Range(0.010002, 2.000000)) = 1.000000
    _BumpMap("BumpMap", 2D) = "white" {}
    _ClothSoften("ClothSoften", Range(0.000000, 1.000000)) = 0.000000
    _MainTex("MainTex", 2D) = "white" {}
    _PBRTexture("PBRTexture", 2D) = "white" {}
    _SmoothnessScale("SmoothnessScale", Range(0.000000, 1.000000)) = 1.000000
}

SubShader {
Tags { "OIT" = "Accumulate" "Queue" = "Transparent" }
LOD 100

Blend One One 

Cull Off

ZWrite Off

Pass {
Tags { "LightMode" = "ShadowCaster" }

ZWrite On

CGPROGRAM

#pragma vertex vert
#pragma fragment frag
#pragma multi_compile_shadowcaster
#include "UnityCG.cginc"

struct v2f { 
    V2F_SHADOW_CASTER;
};

v2f vert(appdata_base v)
{
    v2f o;
    TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
    return o;
}

float4 frag(v2f i) : SV_Target
{
    SHADOW_CASTER_FRAGMENT(i)
}
ENDCG

} // Pass end

} // SubShader end

} // Shader end
