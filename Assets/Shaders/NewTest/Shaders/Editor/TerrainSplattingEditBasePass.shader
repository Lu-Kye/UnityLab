Shader "KGame/Editor/Terrain Splatting Base Pass Edit" {

Properties {
    _MainTex("MainTex", 2D) = "white" {}
    _MetallicTex("MetallicTex", 2D) = "white" {}
}

SubShader {
Tags { "Queue" = "Geometry-100" "RenderType" = "Opaque" }
LOD 200

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
    float2 uv : TEXCOORD0;
    float4 vertex : POSITION;
};

struct v2f {
    float4 pos : SV_Position;
    float2 uv : TEXCOORD0;
    half3 worldNormal : TEXCOORD1;
    float3 worldPos : TEXCOORD2;
    UNITY_FOG_COORDS(3)
};

v2f vert (appdata v) {
    v2f o;

    float3 normal = v.normal;
    float2 uv = v.uv;
    float4 vertex = v.vertex;

    float4 clipPos;
    clipPos = UnityObjectToClipPos(vertex);

    float3 worldPos;
    worldPos = mul(unity_ObjectToWorld, vertex).xyz;

    half3 worldNormal;
    worldNormal = UnityObjectToWorldNormal(normal);
    o.pos = clipPos;
    o.uv = uv;
    o.worldNormal = worldNormal;
    o.worldPos = worldPos;
    UNITY_TRANSFER_FOG(o, o.pos);
    return o;
}

sampler2D _MainTex;
sampler2D _MetallicTex;

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
    color = half4(( (_LightColor0.rgb * nl + ambient) * albedo
        + specular), 1);
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

void SplattingBasicBase(float2 uv, out half3 albedo, out half metallic, out half perceptualSmoothness, out half transparency) {
    half4 c = tex2D(_MainTex, uv);
#if defined(UNITY_COLORSPACE_GAMMA) && defined(STAR_GAMMA_TEXTURE)
    albedo = pow(c.xyz, 2.2);
#else
    albedo = c.xyz;
#endif
    transparency = 1.0f;
    perceptualSmoothness = c.w;
    metallic = tex2D(_MetallicTex, uv).x;
}

void UnityAmbientSH(half3 worldNormal, out half3 ambient) {
#ifdef UNITY_COLORSPACE_GAMMA
    ambient = pow(ShadeSH9(half4(worldNormal, 1)), 2.2);
#else
    ambient = ShadeSH9(half4(worldNormal, 1));
#endif
}

void frag(v2f IN, out half4 color: SV_Target0) { 
    float2 uv = IN.uv;
    half3 worldNormal = IN.worldNormal;
    float3 worldPos = IN.worldPos;

    half3 lightDir;
    lightDir = normalize(UnityWorldSpaceLightDir(worldPos));

    half3 albedo;
    half metallic;
    half perceptualSmoothness;
    half transparency;
    SplattingBasicBase(uv, albedo, metallic, perceptualSmoothness, transparency);

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

    UNITY_APPLY_FOG(IN.fogCoord, color);

    color.w = transparency;
}
ENDCG

} // Pass end

} // SubShader end

} // Shader end
