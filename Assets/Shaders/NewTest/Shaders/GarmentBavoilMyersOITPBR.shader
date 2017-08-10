Shader "KGame/Garment BavoilMyers OIT PBR" {

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
Tags { "LightMode" = "ForwardBase" }

CGPROGRAM

#pragma vertex vert
#pragma fragment frag

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
    float4 vertex : POSITION;
};

struct v2f {
    half3 ambient : COLOR0;
    float4 pos : SV_Position;
    float4 tspace0 : TEXCOORD0;
    float4 tspace1 : TEXCOORD1;
    float4 tspace2 : TEXCOORD2;
    float2 uv : TEXCOORD3;
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

    half3 ambient;
    AmbientSH(worldNormal, ambient);

    o.ambient = ambient;
    o.pos = clipPos;
    o.tspace0 = tspace0;
    o.tspace1 = tspace1;
    o.tspace2 = tspace2;
    o.uv = uv;
    return o;
}

sampler2D _BumpMap;
half _ClothSoften;
sampler2D _MainTex;
sampler2D _PBRTexture;
half _SmoothnessScale;

void FinalBlend(half transparency, inout half4 color) {
    color.w = transparency;
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

    specular = specularTerm * FresnelTerm (specularity, ldotH);
}

void LdotH(half3 halfAngle, half3 lightDir, out half ldotH) {
    ldotH = saturate(dot(lightDir, halfAngle));
}

void LightDualLambertian(half ndotL, out half3 diffuse) {
    diffuse = (_ClothSoften + (1.0f - _ClothSoften) * abs(ndotL));
}

void Lighting(half3 albedo, half3 ambient, half3 diffuse, half3 lightInten, half3 specular, out half4 color) {
    color = half4((diffuse * lightInten + ambient) * albedo, 1);
    color.xyz += specular.xyz * lightInten;
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

void Output2(out half4 count) {
    count = half4(1/255.f, 0, 0, 0);
}

void PBRFromMetallic(half metallic, inout half3 albedo, out half3 specularity, inout half transparency) {
    // see linear unity_ColorSpaceDielectricSpec definition
    specularity = lerp (half3(0.04, 0.04, 0.04), albedo, metallic);
    half oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
    albedo *= oneMinusReflectivity;
    half alpha = transparency;
    albedo = PreMultiplyAlpha(albedo, alpha, oneMinusReflectivity, /*out*/ transparency);
}

void UnpackAlbedo(half4 albedo_transparency, out half3 albedo) {
#if defined(UNITY_COLORSPACE_GAMMA) && defined(STAR_GAMMA_TEXTURE)
    albedo = pow(albedo_transparency.xyz, 2.2);
#else
    albedo = albedo_transparency.xyz;
#endif
}

void UnpackProjectKSmoothnessTexture(float2 uv, out half metallic, out half perceptualSmoothness) {
    fixed4 value = tex2D(_PBRTexture, uv);
    metallic = value.x;
    perceptualSmoothness = _SmoothnessScale * value.y;
}

void WorldTangentNormal(half3 localNormal, float4 tspace0, float4 tspace1, float4 tspace2, out half3 worldNormal) {
    worldNormal.x = dot(half3(tspace0.xyz), localNormal);
    worldNormal.y = dot(half3(tspace1.xyz), localNormal);
    worldNormal.z = dot(half3(tspace2.xyz), localNormal);
    worldNormal = normalize(worldNormal);
}

void frag(v2f IN, out half4 color: SV_Target0, out half4 count: SV_Target1) { 
    half3 ambient = IN.ambient;
    float4 tspace0 = IN.tspace0;
    float4 tspace1 = IN.tspace1;
    float4 tspace2 = IN.tspace2;
    float2 uv = IN.uv;

    half3 localNormal;
    LocalNormal(uv, localNormal);

    half3 worldNormal;
    WorldTangentNormal(localNormal, tspace0, tspace1, tspace2, worldNormal);

    float3 worldPos;
    worldPos = float3(tspace0.w, tspace1.w, tspace2.w);

    half3 lightDir;
    lightDir = normalize(UnityWorldSpaceLightDir(worldPos));

    half4 albedo_transparency;
    albedo_transparency = tex2D(_MainTex, uv);

    half transparency;
    transparency = albedo_transparency.w;

    half3 albedo;
    UnpackAlbedo(albedo_transparency, albedo);

    half3 lightInten;
    lightInten = _LightColor0.rgb;

    half metallic;
    half perceptualSmoothness;
    UnpackProjectKSmoothnessTexture(uv, metallic, perceptualSmoothness);

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
    PBRFromMetallic(metallic, albedo, specularity, transparency);

    half3 specular;
    ImageGGXUnity(ldotH, ndotH, ndotV, nl, roughness, specularity, specular);

    half3 diffuse;
    LightDualLambertian(ndotL, diffuse);

    Lighting(albedo, ambient, diffuse, lightInten, specular, color);

    FinalBlend(transparency, color);



    Output2(count);
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
