Shader "KGame/Editor/Terrain Splatting Add Pass Edit" {

Properties {
    [HideInInspector] _Control("Control", 2D) = "red" {}
    _Metallic0("Metallic0", Range(0.000000, 1.000000)) = 0.000000
    _Metallic1("Metallic1", Range(0.000000, 1.000000)) = 0.000000
    _Metallic2("Metallic2", Range(0.000000, 1.000000)) = 0.000000
    _Metallic3("Metallic3", Range(0.000000, 1.000000)) = 0.000000
    [HideInInspector] _Normal0("Normal0", 2D) = "bump" {}
    [HideInInspector] _Normal1("Normal1", 2D) = "bump" {}
    [HideInInspector] _Normal2("Normal2", 2D) = "bump" {}
    [HideInInspector] _Normal3("Normal3", 2D) = "bump" {}
    _Smoothness0("Smoothness0", Range(0.000000, 1.000000)) = 1.000000
    _Smoothness1("Smoothness1", Range(0.000000, 1.000000)) = 1.000000
    _Smoothness2("Smoothness2", Range(0.000000, 1.000000)) = 1.000000
    _Smoothness3("Smoothness3", Range(0.000000, 1.000000)) = 1.000000
    [HideInInspector] _Splat0("Splat0", 2D) = "white" {}
    [HideInInspector] _Splat0_ST("Splat0_ST", Vector) = (0.000000, 0.000000, 0.000000, 0.000000)
    [HideInInspector] _Splat1("Splat1", 2D) = "white" {}
    [HideInInspector] _Splat1_ST("Splat1_ST", Vector) = (0.000000, 0.000000, 0.000000, 0.000000)
    [HideInInspector] _Splat2("Splat2", 2D) = "white" {}
    [HideInInspector] _Splat2_ST("Splat2_ST", Vector) = (0.000000, 0.000000, 0.000000, 0.000000)
    [HideInInspector] _Splat3("Splat3", 2D) = "white" {}
    [HideInInspector] _Splat3_ST("Splat3_ST", Vector) = (0.000000, 0.000000, 0.000000, 0.000000)
}

SubShader {
Tags { "Queue" = "Geometry-100" "RenderType" = "Opaque" }
LOD 100

Blend One One 

ZWrite Off

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

inline half3 DiffuseAndSpecularFromMetallic2(half3 albedo, half metallic,
    out half3 specColor, out half oneMinusReflectivity
) {    
    half3 spec = half3(0.04, 0.04, 0.04); // see linear unity_ColorSpaceDielectricSpec definition
    specColor = lerp (spec, albedo, metallic);
    oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
    return albedo * oneMinusReflectivity;
}
#define TERRAIN_SPLAT_ADDPASS
#define TERRAIN_STANDARD_SHADER
#define _TERRAIN_NORMAL_MAP
#include "TerrainSplatmapCommon.cginc"

float4 _Splat0_ST;
float4 _Splat1_ST;
float4 _Splat2_ST;
float4 _Splat3_ST;

struct appdata {
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
    float4 vertex : POSITION;
};

struct v2f {
    float4 pos : SV_Position;
    float4 splattingPack0 : TEXCOORD0;
    float4 splattingPack1 : TEXCOORD1;
    float2 splattingUV : TEXCOORD2;
    float4 tspace0 : TEXCOORD3;
    float4 tspace1 : TEXCOORD4;
    float4 tspace2 : TEXCOORD5;
    UNITY_FOG_COORDS(6)
};

void WorldTangentSpaceWithPos(half3 worldBitangent, half3 worldNormal, float3 worldPos, half3 worldTangent, out float4 tspace0, out float4 tspace1, out float4 tspace2) {
    tspace0 = float4(worldTangent.x, worldBitangent.x, worldNormal.x, worldPos.x);
    tspace1 = float4(worldTangent.y, worldBitangent.y, worldNormal.y, worldPos.y);
    tspace2 = float4(worldTangent.z, worldBitangent.z, worldNormal.z, worldPos.z);
}

v2f vert (appdata v) {
    v2f o;

    float3 normal = v.normal;
    float2 uv = v.uv;
    float4 vertex = v.vertex;

    float4 clipPos;
    clipPos = UnityObjectToClipPos(vertex);

    float2 splattingUV;
    splattingUV = TRANSFORM_TEX(uv, _Control);

    float4 splattingPack0;
    float4 splattingPack1;
    splattingPack0.xy = TRANSFORM_TEX(uv, _Splat0);
    splattingPack0.zw = TRANSFORM_TEX(uv, _Splat1);
    splattingPack1.xy = TRANSFORM_TEX(uv, _Splat2);
    splattingPack1.zw = TRANSFORM_TEX(uv, _Splat3);

    float3 worldPos;
    worldPos = vertex.xyz;

    half3 worldBitangent;
    half3 worldNormal;
    half3 worldTangent;
    worldNormal = normal;
    worldTangent = -cross(worldNormal, float3(0,0,1));
    worldBitangent = cross(worldNormal, worldTangent);

    float4 tspace0;
    float4 tspace1;
    float4 tspace2;
    WorldTangentSpaceWithPos(worldBitangent, worldNormal, worldPos, worldTangent, tspace0, tspace1, tspace2);
    o.pos = clipPos;
    o.splattingPack0 = splattingPack0;
    o.splattingPack1 = splattingPack1;
    o.splattingUV = splattingUV;
    o.tspace0 = tspace0;
    o.tspace1 = tspace1;
    o.tspace2 = tspace2;
    UNITY_TRANSFER_FOG(o, o.pos);
    return o;
}

half _Metallic0;
half _Metallic1;
half _Metallic2;
half _Metallic3;
half _Smoothness0;
half _Smoothness1;
half _Smoothness2;
half _Smoothness3;

void GammaCompression(inout half4 color) {
#if defined(UNITY_COLORSPACE_GAMMA) && defined(STAR_GAMMA_TEXTURE)
    color.xyz = pow(color.xyz, 0.454545);
#endif 
}

void HalfAngleNormalized(half3 h, out half3 halfAngle) {
    halfAngle = normalize(h);
}

void HalfAngleUnnormalized(half3 lightDir, half3 worldViewDir, out half3 h) {
    h = lightDir + worldViewDir;
}

void ImageGGXUnity(half ldotH, half ndotH, half ndotV, half nl, half roughness, half3 specularity, out half3 specular) {
    half V = SmithJointGGXVisibilityTerm(nl, ndotV, roughness);
    half D = GGXTerm(ndotH, roughness);
    half specularTerm = V * D * UNITY_PI;

    specularTerm = max(0, specularTerm * nl);

    specular = specularTerm * _LightColor0.xyz * FresnelTerm (specularity, ldotH);
}

void LdotH(half3 halfAngle, half3 lightDir, out half ldotH) {
    ldotH = saturate(dot(lightDir, halfAngle));
}

void Lighting(half3 albedo, half3 ambient, half nl, half3 specular, out half4 color) {
    color = half4((_LightColor0.rgb * nl + ambient) * albedo
        + specular/* * SpecularScale*/, 1);
}

void NdotH(half3 halfAngle, half3 worldNormal, out half ndotH) {
    ndotH = saturate(dot(worldNormal, halfAngle));
}

void NdotL(half3 lightDir, half3 worldNormal, out half ndotL) {
    ndotL = dot(worldNormal, lightDir);
}

void NdotV(half3 worldNormal, half3 worldViewDir, out half ndotV) {
    ndotV = saturate(dot(worldNormal, worldViewDir));
}

void ProjectKMaterial(half metallic, inout half3 albedo, out half3 specularity, inout half transparency) {
    half oneMinusReflectivity;
    albedo = DiffuseAndSpecularFromMetallic2(albedo, metallic, specularity, oneMinusReflectivity);
    half alpha = transparency;
    albedo = PreMultiplyAlpha(albedo, alpha, oneMinusReflectivity, /*out*/ transparency);
}

void SplattingBasic(float4 splattingPack0, float4 splattingPack1, float2 splattingUV, out half3 albedo, out half3 localNormal, out half metallic, out half multipassWeight, out half perceptualSmoothness, out half transparency) {
    Input input;
    input.uv_Splat0 = splattingPack0.xy;
    input.uv_Splat1 = splattingPack0.zw;
    input.uv_Splat2 = splattingPack1.xy;
    input.uv_Splat3 = splattingPack1.zw;
    input.tc_Control = splattingUV.xy;

#ifdef DONT_USE_TERRAIN_NORMAL_MAP
    localNormal = half3(0, 0, 1);
#endif
    half4 splat_control;
    fixed4 mixedDiffuse;
    half4 defaultSmoothness = half4(_Smoothness0, _Smoothness1, _Smoothness2, _Smoothness3);
    SplatmapMix(input, defaultSmoothness, splat_control, multipassWeight, mixedDiffuse, localNormal);
#if defined(UNITY_COLORSPACE_GAMMA) && defined(STAR_GAMMA_TEXTURE)
    albedo = pow(mixedDiffuse.xyz, 2.2);
#else
    albedo = mixedDiffuse.xyz;
#endif
    transparency = 1.0;
    perceptualSmoothness = mixedDiffuse.a;
    metallic = dot(splat_control, half4(_Metallic0, _Metallic1, _Metallic2, _Metallic3));
}

void UnityAmbientSH(half3 worldNormal, out half3 ambient) {
#ifdef UNITY_COLORSPACE_GAMMA
    ambient = pow(ShadeSH9(half4(worldNormal, 1)), 2.2);
#else
    ambient = ShadeSH9(half4(worldNormal, 1));
#endif
}

void WorldTangentNormal(half3 localNormal, float4 tspace0, float4 tspace1, float4 tspace2, out half3 worldNormal) {
    worldNormal.x = dot(half3(tspace0.xyz), localNormal);
    worldNormal.y = dot(half3(tspace1.xyz), localNormal);
    worldNormal.z = dot(half3(tspace2.xyz), localNormal);
    worldNormal = normalize(worldNormal);
}

void frag(v2f IN, out half4 color: SV_Target0) { 
    float4 splattingPack0 = IN.splattingPack0;
    float4 splattingPack1 = IN.splattingPack1;
    float2 splattingUV = IN.splattingUV;
    float4 tspace0 = IN.tspace0;
    float4 tspace1 = IN.tspace1;
    float4 tspace2 = IN.tspace2;

    float3 worldPos;
    worldPos = float3(tspace0.w, tspace1.w, tspace2.w);

    half3 lightDir;
    lightDir = normalize(UnityWorldSpaceLightDir(worldPos));

    half3 albedo;
    half3 localNormal;
    half metallic;
    half multipassWeight;
    half perceptualSmoothness;
    half transparency;
    SplattingBasic(splattingPack0, splattingPack1, splattingUV, albedo, localNormal, metallic, multipassWeight, perceptualSmoothness, transparency);

    half3 worldNormal;
    WorldTangentNormal(localNormal, tspace0, tspace1, tspace2, worldNormal);

    half3 worldViewDir;
    worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));

    half ndotV;
    NdotV(worldNormal, worldViewDir, ndotV);

    half3 h;
    HalfAngleUnnormalized(lightDir, worldViewDir, h);

    half3 halfAngle;
    HalfAngleNormalized(h, halfAngle);

    half ndotH;
    NdotH(halfAngle, worldNormal, ndotH);

    half ldotH;
    LdotH(halfAngle, lightDir, ldotH);

    half ndotL;
    NdotL(lightDir, worldNormal, ndotL);

    half nl;
    nl = saturate(ndotL);

    half perceptualRoughness;
    perceptualRoughness = 1.0 - perceptualSmoothness;

    half roughness;
    roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

    half3 specularity;
    ProjectKMaterial(metallic, albedo, specularity, transparency);

    half3 specular;
    ImageGGXUnity(ldotH, ndotH, ndotV, nl, roughness, specularity, specular);

    half3 ambient;
    UnityAmbientSH(worldNormal, ambient);

    Lighting(albedo, ambient, nl, specular, color);

    GammaCompression(color);

    // apply multi-pass weight and fog
    color.xyz *= multipassWeight;
#ifdef TERRAIN_SPLAT_ADDPASS
        UNITY_APPLY_FOG_COLOR(IN.fogCoord, color, fixed4(0,0,0,0));
#else
        UNITY_APPLY_FOG(IN.fogCoord, color);
#endif

    color.w = transparency;
}
ENDCG

} // Pass end

} // SubShader end

} // Shader end
