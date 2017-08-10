Shader "KGame/Editor/PBR Edit" {

Properties {
    _BumpMap("BumpMap", 2D) = "white" {}
    _MainTex("MainTex", 2D) = "white" {}
    _PBRTexture("PBRTexture", 2D) = "white" {}
    _SmoothnessScale("SmoothnessScale", Range(0.000000, 1.000000)) = 1.000000
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

inline half3 DiffuseAndSpecularFromMetallic2(half3 albedo, half metallic,
    out half3 specColor, out half oneMinusReflectivity
) {    
    half3 spec = half3(0.04, 0.04, 0.04); // see linear unity_ColorSpaceDielectricSpec definition
    specColor = lerp (spec, albedo, metallic);
    oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
    return albedo * oneMinusReflectivity;
}

struct appdata {
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
    float4 vertex : POSITION;
};

struct v2f {
    float4 pos : SV_Position;
    float4 tspace0 : TEXCOORD0;
    float4 tspace1 : TEXCOORD1;
    float4 tspace2 : TEXCOORD2;
    float2 uv : TEXCOORD3;
    UNITY_FOG_COORDS(4)
    SHADOW_COORDS(5)
};

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

    float3 normal = v.normal;
    float4 tangent = v.tangent;
    float2 uv = v.uv;
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
    o.pos = clipPos;
    o.tspace0 = tspace0;
    o.tspace1 = tspace1;
    o.tspace2 = tspace2;
    o.uv = uv;
    TRANSFER_SHADOW(o);
    UNITY_TRANSFER_FOG(o, o.pos);
    return o;
}

sampler2D _BumpMap;
sampler2D _MainTex;
sampler2D _PBRTexture;
half _SmoothnessScale;

void AlbedoAndTransparency(float2 uv, out half3 albedo, out half transparency) {
    half4 value = tex2D(_MainTex, uv);
#if defined(UNITY_COLORSPACE_GAMMA) && defined(STAR_GAMMA_TEXTURE)
    albedo = pow(value.xyz, 2.2);
#else
    albedo = value.xyz;
#endif
    transparency = value.w;
}

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

void Lighting(half3 albedo, half3 ambient, half nl, half occlusion, half3 specular, out half4 color) {
    color = half4(occlusion * ((_LightColor0.rgb*nl + ambient) * albedo
         + specular), 1);
}

void LocalNormal(float2 uv, out half3 localNormal) {
    localNormal = UnpackNormal(tex2D(_BumpMap, uv));
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

void UnityAmbientSH(half3 worldNormal, out half3 ambient) {
#ifdef UNITY_COLORSPACE_GAMMA
    ambient = pow(ShadeSH9(half4(worldNormal, 1)), 2.2);
#else
    ambient = ShadeSH9(half4(worldNormal, 1));
#endif
}

void UnpackProjectKSmoothnessTextureWithOcclusion(float2 uv, out half metallic, out half occlusion, out half perceptualSmoothness) {
    fixed4 value = tex2D(_PBRTexture, uv);
    metallic = value.x;
    perceptualSmoothness = _SmoothnessScale * value.y;
    occlusion = value.z;
}

void WorldTangentNormal(half3 localNormal, float4 tspace0, float4 tspace1, float4 tspace2, out half3 worldNormal) {
    worldNormal.x = dot(half3(tspace0.xyz), localNormal);
    worldNormal.y = dot(half3(tspace1.xyz), localNormal);
    worldNormal.z = dot(half3(tspace2.xyz), localNormal);
    worldNormal = normalize(worldNormal);
}

void frag(v2f IN, out half4 color: SV_Target0) { 
    float4 tspace0 = IN.tspace0;
    float4 tspace1 = IN.tspace1;
    float4 tspace2 = IN.tspace2;
    float2 uv = IN.uv;

    float3 worldPos;
    worldPos = float3(tspace0.w, tspace1.w, tspace2.w);

    half3 lightDir;
    lightDir = normalize(UnityWorldSpaceLightDir(worldPos));

    half3 albedo;
    half transparency;
    AlbedoAndTransparency(uv, albedo, transparency);

    half3 localNormal;
    LocalNormal(uv, localNormal);

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

    half metallic;
    half occlusion;
    half perceptualSmoothness;
    UnpackProjectKSmoothnessTextureWithOcclusion(uv, metallic, occlusion, perceptualSmoothness);

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

    Lighting(albedo, ambient, nl, occlusion, specular, color);

    GammaCompression(color);

    UNITY_APPLY_FOG(IN.fogCoord, color);

    color.w = transparency;
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
