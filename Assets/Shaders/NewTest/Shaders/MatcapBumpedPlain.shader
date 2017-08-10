Shader "KGame/Matcap Bumped Plain" {

Properties {
    _AmbientColor("AmbientColor", Color) = (1.000000, 1.000000, 1.000000, 1.000000)
    _AmbientScale("AmbientScale", Range(0.010002, 2.000000)) = 1.000000
    _BumpMap("BumpMap", 2D) = "white" {}
    _Color("Color", Color) = (1.000000, 1.000000, 1.000000, 1.000000)
    _MatCap("MatCap", 2D) = "white" {}
}

SubShader {
Tags { "RenderType" = "Opaque" }
LOD 100

Pass {
Tags { "LightMode" = "ForwardBase" }

CGPROGRAM

#pragma vertex vert
#pragma fragment frag

//#pragma multi_compile_fwdbase
#pragma multi_compile_fog
//#define FOG_LINEAR
#define LIGHTMAP_ON
#define UNITY_PASS_FORWARDBASE

#include "HLSLSupport.cginc"
#include "UnityShaderVariables.cginc"
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

#define STAR_GAMMA_TEXTURE


struct appdata {
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float4 vertex : POSITION;
};

struct v2f {
    half3 ambient : COLOR0;
    float4 pos : SV_Position;
    float4 lightmapUV : TEXCOORD0;
    float4 tspace0 : TEXCOORD1;
    float4 tspace1 : TEXCOORD2;
    float4 tspace2 : TEXCOORD3;
    float2 uv : TEXCOORD4;
    UNITY_FOG_COORDS(5)
};
fixed4 _AmbientColor;
half _AmbientScale;

void AmbientSH(half3 worldNormal, out half3 ambient) {
#ifdef UNITY_COLORSPACE_GAMMA
    //ambient = _AmbientScale * pow(ShadeSH9(half4(worldNormal, 1)), 2.2);
    ambient = _AmbientScale * _AmbientColor.xyz;
#else
    //ambient = _AmbientScale * ShadeSH9(half4(worldNormal, 1));
    ambient = _AmbientScale * _AmbientColor.xyz;
#endif
}

void LightmapUV(float2 uv1, out float4 lightmapUV) {
    lightmapUV.xy = uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
    lightmapUV.zw = float2(0, 0);
}

void WorldBitangent(float4 tangent, half3 worldNormal, half3 worldTangent, out half3 worldBitangent) {
    half tangentSign = tangent.w * unity_WorldTransformParams.w;
    worldBitangent = cross(worldNormal, worldTangent) * tangentSign;
}

void WorldTangentSpaceWithPos(half3 worldBitangent, half3 worldNormal, float3 worldPos, half3 worldTangent, out float4 tspace0, out float4 tspace1, out float4 tspace2) {
    tspace0 = float4(worldTangent.x, worldBitangent.x, worldNormal.x, worldPos.x);
    tspace1 = float4(worldTangent.y, worldBitangent.y, worldNormal.y, worldPos.y);
    tspace2 = float4(worldTangent.z, worldBitangent.z, worldNormal.z, worldPos.z);
}

v2f vert (appdata v) {
    v2f o;
    UNITY_INITIALIZE_OUTPUT(v2f, o);

    float3 normal = v.normal;
    float4 tangent = v.tangent;
    float2 uv = v.uv;
    float2 uv1 = v.uv1;
    float4 vertex = v.vertex;

    float4 clipPos;
    clipPos = UnityObjectToClipPos(vertex);

    float3 worldPos;
    worldPos = mul(unity_ObjectToWorld, vertex).xyz;

    half3 worldTangent;
    worldTangent = UnityObjectToWorldDir(tangent.xyz);

    half3 worldNormal;
    worldNormal = UnityObjectToWorldNormal(normal);

    half3 worldBitangent;
    WorldBitangent(tangent, worldNormal, worldTangent, worldBitangent);

    float4 tspace0;
    float4 tspace1;
    float4 tspace2;
    WorldTangentSpaceWithPos(worldBitangent, worldNormal, worldPos, worldTangent, tspace0, tspace1, tspace2);

    float4 lightmapUV;
    LightmapUV(uv1, lightmapUV);

    half3 ambient;
    AmbientSH(worldNormal, ambient);

    o.ambient = ambient;
    o.pos = clipPos;
    o.lightmapUV = lightmapUV;
    o.tspace0 = tspace0;
    o.tspace1 = tspace1;
    o.tspace2 = tspace2;
    o.uv = uv;
    UNITY_TRANSFER_FOG(o, o.pos);
    return o;
}

sampler2D _BumpMap;
fixed4 _Color;
sampler2D _MatCap;

void GammaCompression(inout half4 color) {
#if defined(UNITY_COLORSPACE_GAMMA) && defined(STAR_GAMMA_TEXTURE)
    color.xyz = pow(color.xyz, 0.454545);
#endif 
}

void Lightmap(float4 lightmapUV, out half3 lightmap) {
    //#ifdef LIGHTMAP_ON
    lightmap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, lightmapUV.xy));
    //#else
    //lightmap = half3(1.0, 1.0, 1.0);
    //#endif
}

void LocalNormal(float2 uv, out half3 localNormal) {
    localNormal = UnpackNormal(tex2D(_BumpMap, uv));
}

void WorldTangentNormal(half3 localNormal, float4 tspace0, float4 tspace1, float4 tspace2, out half3 worldNormal) {
    worldNormal.x = dot(half3(tspace0.xyz), localNormal);
    worldNormal.y = dot(half3(tspace1.xyz), localNormal);
    worldNormal.z = dot(half3(tspace2.xyz), localNormal);
    worldNormal = normalize(worldNormal);
}

void frag(v2f IN, out half4 color: SV_Target0) { 
    float4 lightmapUV = IN.lightmapUV;
    float4 tspace0 = IN.tspace0;
    float4 tspace1 = IN.tspace1;
    float4 tspace2 = IN.tspace2;
    float2 uv = IN.uv;

    half3 localNormal;
    LocalNormal(uv, localNormal);

    half3 worldNormal;
    WorldTangentNormal(localNormal, tspace0, tspace1, tspace2, worldNormal);

    half3 lightmap;
    Lightmap(lightmapUV, lightmap);

    half2 capCoord;
    worldNormal = mul((half3x3)UNITY_MATRIX_V, worldNormal);
            capCoord = worldNormal.xy * 0.5 + 0.5;

    half3 mc;
    mc = tex2D(_MatCap, capCoord).xyz;

    color = half4(lightmap * mc * _Color * 2.0, 1);

    GammaCompression(color);

    UNITY_APPLY_FOG(IN.fogCoord, color);


}
ENDCG

} // Pass end

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
