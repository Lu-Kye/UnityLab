Shader "KGame/Editor/Mesh Splatting 6" {

Properties {
    _Control0("Control0", 2D) = "white" {}
    _Control1("Control1", 2D) = "white" {}
    _Metallic0("Metallic0", Vector) = (1.000000, 1.000000, 1.000000, 1.000000)
    _Metallic1("Metallic1", Vector) = (1.000000, 1.000000, 1.000000, 1.000000)
    _Normal0("Normal0", 2D) = "bump" {}
    _Normal1("Normal1", 2D) = "bump" {}
    _Normal2("Normal2", 2D) = "bump" {}
    _Normal3("Normal3", 2D) = "bump" {}
    _Normal4("Normal4", 2D) = "bump" {}
    _Normal5("Normal5", 2D) = "bump" {}
    _OverlayTexture("OverlayTexture", 2D) = "black" {}
    _Size0("Size0", Vector) = (1.000000, 1.000000, 1.000000, 1.000000)
    _Size1("Size1", Vector) = (1.000000, 1.000000, 1.000000, 1.000000)
    _Smoothness0("Smoothness0", Vector) = (1.000000, 1.000000, 1.000000, 1.000000)
    _Smoothness1("Smoothness1", Vector) = (1.000000, 1.000000, 1.000000, 1.000000)
    _Splat0("Splat0", 2D) = "white" {}
    _Splat1("Splat1", 2D) = "white" {}
    _Splat2("Splat2", 2D) = "white" {}
    _Splat3("Splat3", 2D) = "white" {}
    _Splat4("Splat4", 2D) = "white" {}
    _Splat5("Splat5", 2D) = "white" {}
    _SplattingUVSize("SplattingUVSize", Vector) = (0.000000, 0.000000, 1.000000, 1.000000)
}

SubShader {
Tags { "Queue" = "Geometry" "RenderType" = "Opaque" }
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
#define SHADOWS_SCREEN
#define UNITY_NO_SCREENSPACE_SHADOWS
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
    float2 uv2 : TEXCOORD1;
    float4 vertex : POSITION;
};

struct v2f {
    float4 pos : SV_Position;
    float4 lightmapUV : TEXCOORD0;
    float4 splattingPack0 : TEXCOORD1;
    float4 splattingPack1 : TEXCOORD2;
    float4 splattingPack2 : TEXCOORD3;
    float4 tspace0 : TEXCOORD4;
    float4 tspace1 : TEXCOORD5;
    float4 tspace2 : TEXCOORD6;
    float2 uv : TEXCOORD7;
    UNITY_FOG_COORDS(8)
    SHADOW_COORDS(9)
};
float4 _Size0;
float4 _Size1;
float4 _SplattingUVSize;

void LightmapUV(float2 uv2, out float4 lightmapUV) {
#ifdef DYNAMICLIGHTMAP_ON
    lightmapUV.zw = uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#else
    lightmapUV.zw = float2(0, 0);
#endif
    lightmapUV.xy = uv2.xy * unity_LightmapST.xy + unity_LightmapST.zw;
}

void SplattingMeshUVs6(float2 uv, out float4 splattingPack0, out float4 splattingPack1, out float4 splattingPack2) {
    float2 maxUv = uv * _SplattingUVSize.zw;
    splattingPack0.xy = maxUv / _Size0[0];
    splattingPack0.zw = maxUv / _Size0[1];
    splattingPack1.xy = maxUv / _Size0[2];
    splattingPack1.zw = maxUv / _Size0[3];
    splattingPack2.xy = maxUv / _Size1[0];
    splattingPack2.zw = maxUv / _Size1[1];
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

    float3 normal = v.normal;
    float4 tangent = v.tangent;
    float2 uv = v.uv;
    float2 uv2 = v.uv2;
    float4 vertex = v.vertex;

    float4 clipPos;
    clipPos = UnityObjectToClipPos(vertex);

    float4 splattingPack0;
    float4 splattingPack1;
    float4 splattingPack2;
    SplattingMeshUVs6(uv, splattingPack0, splattingPack1, splattingPack2);

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
    LightmapUV(uv2, lightmapUV);
    o.pos = clipPos;
    o.lightmapUV = lightmapUV;
    o.splattingPack0 = splattingPack0;
    o.splattingPack1 = splattingPack1;
    o.splattingPack2 = splattingPack2;
    o.tspace0 = tspace0;
    o.tspace1 = tspace1;
    o.tspace2 = tspace2;
    o.uv = uv;
    TRANSFER_SHADOW(o);
    UNITY_TRANSFER_FOG(o, o.pos);
    return o;
}

sampler2D _Control0;
sampler2D _Control1;
half4 _Metallic0;
half4 _Metallic1;
sampler2D _Normal0;
sampler2D _Normal1;
sampler2D _Normal2;
sampler2D _Normal3;
sampler2D _Normal4;
sampler2D _Normal5;
sampler2D _OverlayTexture;
half4 _Smoothness0;
half4 _Smoothness1;
sampler2D _Splat0;
sampler2D _Splat1;
sampler2D _Splat2;
sampler2D _Splat3;
sampler2D _Splat4;
sampler2D _Splat5;

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

void Lighting(half3 albedo, half3 lightmap, half4 overlay, half3 specular, out half4 color) {
    color = half4(lightmap * (length(_LightColor0.rgb) * (albedo + overlay.xyz) + specular), 1);
}

void Lightmap(float4 lightmapUV, out half3 lightmap) {
    //#ifdef LIGHTMAP_ON
    lightmap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, lightmapUV.xy));
    //#else
    //lightmap = half3(1.0, 1.0, 1.0);
    //#endif
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

void SplattingMesh6(float4 splattingPack0, float4 splattingPack1, float4 splattingPack2, float2 splattingUV, out half3 albedo, out half3 localNormal, out half metallic, out half perceptualSmoothness, out half transparency) {
    half weight = 0.f;
    fixed4 mixedDiffuse = fixed4(0.f, 0.f, 0.f, 0.f);
    fixed4 nrm = fixed4(0.f, 0.f, 0.f, 0.f);
    metallic = 0.f;

    half4 splat_control0 = tex2D(_Control0, splattingUV);
    weight += dot(splat_control0, half4(1, 1, 1, 1));
    half4 splat_control1 = tex2D(_Control1, splattingUV);
    weight += dot(splat_control1, half4(1, 1, 1, 1));
    {
        splat_control0 /= (weight + 1e-3f);
        mixedDiffuse += splat_control0.r * tex2D(_Splat0, splattingPack0.xy) * half4(1.0, 1.0, 1.0, _Smoothness0.r);
        mixedDiffuse += splat_control0.g * tex2D(_Splat1, splattingPack0.zw) * half4(1.0, 1.0, 1.0, _Smoothness0.g);
        mixedDiffuse += splat_control0.b * tex2D(_Splat2, splattingPack1.xy) * half4(1.0, 1.0, 1.0, _Smoothness0.b);
        mixedDiffuse += splat_control0.a * tex2D(_Splat3, splattingPack1.zw) * half4(1.0, 1.0, 1.0, _Smoothness0.a);
        nrm += splat_control0.r * tex2D(_Normal0, splattingPack0.xy);
        nrm += splat_control0.g * tex2D(_Normal1, splattingPack0.zw);
        nrm += splat_control0.b * tex2D(_Normal2, splattingPack1.xy);
        nrm += splat_control0.a * tex2D(_Normal3, splattingPack1.zw);
        metallic += dot(splat_control0, _Metallic0);
    }
    {
        splat_control1 /= (weight + 1e-3f);
        mixedDiffuse += splat_control1.r * tex2D(_Splat4, splattingPack2.xy) * half4(1.0, 1.0, 1.0, _Smoothness1.r);
        mixedDiffuse += splat_control1.g * tex2D(_Splat5, splattingPack2.zw) * half4(1.0, 1.0, 1.0, _Smoothness1.g);
        nrm += splat_control1.r * tex2D(_Normal4, splattingPack2.xy);
        nrm += splat_control1.g * tex2D(_Normal5, splattingPack2.zw);
        metallic += dot(splat_control1, _Metallic1);
    }

    localNormal = UnpackNormal(nrm);
#if defined(UNITY_COLORSPACE_GAMMA) && defined(STAR_GAMMA_TEXTURE)
    albedo = pow(mixedDiffuse.xyz, 2.2);
#else
    albedo = mixedDiffuse.xyz;
#endif

    transparency = 1.0;
    perceptualSmoothness = mixedDiffuse.a;
}

void WorldTangentNormal(half3 localNormal, float4 tspace0, float4 tspace1, float4 tspace2, out half3 worldNormal) {
    worldNormal.x = dot(half3(tspace0.xyz), localNormal);
    worldNormal.y = dot(half3(tspace1.xyz), localNormal);
    worldNormal.z = dot(half3(tspace2.xyz), localNormal);
    worldNormal = normalize(worldNormal);
}

void frag(v2f IN, out half4 color: SV_Target0) { 
    float4 lightmapUV = IN.lightmapUV;
    float4 splattingPack0 = IN.splattingPack0;
    float4 splattingPack1 = IN.splattingPack1;
    float4 splattingPack2 = IN.splattingPack2;
    float4 tspace0 = IN.tspace0;
    float4 tspace1 = IN.tspace1;
    float4 tspace2 = IN.tspace2;
    float2 uv = IN.uv;

    float3 worldPos;
    worldPos = float3(tspace0.w, tspace1.w, tspace2.w);

    half3 lightDir;
    lightDir = normalize(UnityWorldSpaceLightDir(worldPos));

    float2 splattingUV;
    splattingUV = uv;

    half3 albedo;
    half3 localNormal;
    half metallic;
    half perceptualSmoothness;
    half transparency;
    SplattingMesh6(splattingPack0, splattingPack1, splattingPack2, splattingUV, albedo, localNormal, metallic, perceptualSmoothness, transparency);

    half3 worldNormal;
    WorldTangentNormal(localNormal, tspace0, tspace1, tspace2, worldNormal);

    half4 overlay;
    overlay = tex2D(_OverlayTexture, uv);

    half ndotL;
    NdotL(lightDir, worldNormal, ndotL);

    half nl;
    nl = saturate(ndotL);

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

    half perceptualRoughness;
    perceptualRoughness = 1.0 - perceptualSmoothness;

    half roughness;
    roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

    half3 specularity;
    ProjectKMaterial(metallic, albedo, specularity, transparency);

    half3 specular;
    ImageGGXUnity(ldotH, ndotH, ndotV, nl, roughness, specularity, specular);

    half3 lightmap;
    Lightmap(lightmapUV, lightmap);

    Lighting(albedo, lightmap, overlay, specular, color);

    GammaCompression(color);

    UNITY_APPLY_FOG(IN.fogCoord, color);

    color.w = transparency;
}
ENDCG

} // Pass end

} // SubShader end

} // Shader end
