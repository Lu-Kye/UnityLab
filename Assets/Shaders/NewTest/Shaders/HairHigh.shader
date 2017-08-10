Shader "KGame/Hair High" {

Properties {
    _AmbientColor("AmbientColor", Color) = (1.000000, 1.000000, 1.000000, 1.000000)
    _AmbientScale("AmbientScale", Range(0.010002, 2.000000)) = 1.000000
    _BumpMap("BumpMap", 2D) = "white" {}
    _HairDiffuseColor("HairDiffuseColor", Color) = (1.000000, 1.000000, 1.000000, 1.000000)
    _HairSpecExp1("HairSpecExp1", Range(0.000000, 500.000000)) = 0.500000
    _HairSpecularColor1("HairSpecularColor1", Color) = (1.000000, 1.000000, 1.000000, 1.000000)
    _MainTex("MainTex", 2D) = "white" {}
    _PrimaryShift("PrimaryShift", Range(-1.000000, 1.000000)) = 0.000000
}

SubShader {
Tags { "Queue" = "Transparent-1" "RenderType" = "Transparent" }
LOD 100

Blend SrcAlpha OneMinusSrcAlpha 

Cull Off

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


half3 ShiftTangent(half3 T, half3 N, half shift) {
    half3 shiftedT = T + shift * N;
    return normalize(shiftedT);
}

half StrandSpecular(half3 tsTangent, half3 halfAngle, half specularExponent) {
    half dotTH = dot(tsTangent, halfAngle);
    half sinTH = sqrt(1.0 - dotTH * dotTH);
    half dirAtten = smoothstep(-1.0, 0.0, dotTH);
    return pow(sinTH, specularExponent);
}

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
fixed4 _HairDiffuseColor;
half _HairSpecExp1;
fixed4 _HairSpecularColor1;
sampler2D _MainTex;
half _PrimaryShift;

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

void KajiyaKayDiffuse(half ndotL, out half3 diffuse) {
    diffuse = saturate(lerp(0.25, 1.0, ndotL)) * _HairDiffuseColor.xyz;
}

void KajiyaKaySpecular(half3 halfAngle, half ndotL, half3 tsBitangent, half3 tsTangent, half3 worldNormal, out half3 specular) {
    half shiftTex = 0;
    half3 tangent = cross(tsBitangent, worldNormal);
    half3 bitangent = cross(worldNormal, tangent);
    half3 t1 = ShiftTangent(tangent, worldNormal, _PrimaryShift + shiftTex);
    //half3 t2 = ShiftTangent(tangent, worldNormal, SecondaryShift + shiftTex);
    specular = _HairSpecularColor1.xyz * StrandSpecular(t1, halfAngle, _HairSpecExp1);
    //specular += HairSpecularColor2.xyz * StrandSpecular(t2, halfAngle, HairSpecExp2);
    specular *= max(0, lerp(0.25, 1.0, ndotL));
}

void LocalNormal(float2 uv, out half3 localNormal) {
    localNormal = UnpackNormal(tex2D(_BumpMap, uv));
}

void NdotL(half3 lightDir, half3 worldNormal, out half ndotL) {
    ndotL = dot(worldNormal, lightDir);
}

void Output(half3 albedo, half3 ambient, half3 diffuse, half3 lightInten, half3 specular, half transparency, out half4 color) {
    color = half4((diffuse * lightInten + ambient) * albedo + specular * lightInten, transparency);
}

void UnpackAlbedo(half4 albedo_transparency, out half3 albedo) {
#if defined(UNITY_COLORSPACE_GAMMA) && defined(STAR_GAMMA_TEXTURE)
    albedo = pow(albedo_transparency.xyz, 2.2);
#else
    albedo = albedo_transparency.xyz;
#endif
}

void WorldTangentNormal(half3 localNormal, float4 tspace0, float4 tspace1, float4 tspace2, out half3 worldNormal) {
    worldNormal.x = dot(half3(tspace0.xyz), localNormal);
    worldNormal.y = dot(half3(tspace1.xyz), localNormal);
    worldNormal.z = dot(half3(tspace2.xyz), localNormal);
    worldNormal = normalize(worldNormal);
}

void frag(v2f IN, out half4 color: SV_Target0) { 
    half3 ambient = IN.ambient;
    float4 tspace0 = IN.tspace0;
    float4 tspace1 = IN.tspace1;
    float4 tspace2 = IN.tspace2;
    float2 uv = IN.uv;

    float3 worldPos;
    worldPos = float3(tspace0.w, tspace1.w, tspace2.w);

    half3 lightDir;
    lightDir = normalize(UnityWorldSpaceLightDir(worldPos));

    half3 localNormal;
    LocalNormal(uv, localNormal);

    half3 worldNormal;
    WorldTangentNormal(localNormal, tspace0, tspace1, tspace2, worldNormal);

    half3 tsTangent;
    tsTangent = half3(tspace0.x, tspace1.x, tspace2.x);

    half3 tsBitangent;
    tsBitangent = half3(tspace0.y, tspace1.y, tspace2.y);

    half3 lightInten;
    lightInten = _LightColor0.rgb;

    half4 albedo_transparency;
    albedo_transparency = tex2D(_MainTex, uv);

    half transparency;
    transparency = albedo_transparency.w;

    half3 albedo;
    UnpackAlbedo(albedo_transparency, albedo);

    half3 worldViewDir;
    worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));

    half3 h;
    HalfAngleUnnormalized(lightDir, worldViewDir, h);

    half3 halfAngle;
    HalfAngleNormalized(h, halfAngle);

    half ndotL;
    NdotL(lightDir, worldNormal, ndotL);

    half3 specular;
    KajiyaKaySpecular(halfAngle, ndotL, tsBitangent, tsTangent, worldNormal, specular);

    half3 diffuse;
    KajiyaKayDiffuse(ndotL, diffuse);

    Output(albedo, ambient, diffuse, lightInten, specular, transparency, color);

    GammaCompression(color);
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
