Shader "KGame/PBR AlphaTest" {

Properties {
    _BumpMap("BumpMap", 2D) = "white" {}
    _Cutoff("Cutoff", Range(0.000000, 1.000000)) = 1.000000
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

#pragma multi_compile_fwdbase
#pragma multi_compile_fog

#define UNITY_PASS_FORWARDBASE

#include "HLSLSupport.cginc"
#include "UnityShaderVariables.cginc"
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

half3 HUEtoRGB(in half H) {
    half R = abs(H * 6 - 3) - 1;
    half G = 2 - abs(H * 6 - 2);
    half B = 2 - abs(H * 6 - 4);
    return saturate(half3(R, G, B));
}

half Epsilon = 1e-10;

half3 RGBtoHCV(in half3 RGB) {
    // Based on work by Sam Hocevar and Emil Persson
    half4 P = (RGB.g < RGB.b) ? half4(RGB.bg, -1.0, 2.0 / 3.0) : half4(RGB.gb, 0.0, -1.0 / 3.0);
    half4 Q = (RGB.r < P.x) ? half4(P.xyw, RGB.r) : half4(RGB.r, P.yzx);
    half C = Q.x - min(Q.w, Q.y);
    half H = abs((Q.w - Q.y) / (6 * C + Epsilon) + Q.z);
    return half3(H, C, Q.x);
}

half3 HSVtoRGB(in half3 HSV) {
    half3 RGB = HUEtoRGB(HSV.x);
    return ((RGB - 1) * HSV.y + 1) * HSV.z;
}

half3 RGBtoHSV(in half3 RGB) {
    half3 HCV = RGBtoHCV(RGB);
    half S = HCV.y / (HCV.z + Epsilon);
    return half3(HCV.x, S, HCV.z);
}

#define STAR_GAMMA_TEXTURE


struct v2f {
    float4 pos : SV_Position;
    float4 lightmapUV : TEXCOORD0;
    float4 tspace0 : TEXCOORD1;
    float4 tspace1 : TEXCOORD2;
    float4 tspace2 : TEXCOORD3;
    float2 uv : TEXCOORD4;
    UNITY_FOG_COORDS(5)
    UNITY_SHADOW_COORDS(6)
#if !defined(LIGHTMAP_ON) && defined(UNITY_SHOULD_SAMPLE_SH)
    half3 sh : TEXCOORD7;
#endif
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

v2f vert (appdata_full v) {
    v2f o;
    UNITY_INITIALIZE_OUTPUT(v2f, o);

    float3 normal = v.normal;
    float4 tangent = v.tangent;
    float2 uv = v.texcoord;
    float2 uv1 = v.texcoord1;
    float2 uv2 = v.texcoord2;
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
#ifdef DYNAMICLIGHTMAP_ON
    lightmapUV.zw = uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#else
    lightmapUV.zw = float2(0, 0);
#endif

#ifdef LIGHTMAP_ON
    lightmapUV.xy = uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
#else
    lightmapUV.xy = float2(0, 0);
#endif

// SH/ambient and vertex lights
#ifndef LIGHTMAP_ON
#if UNITY_SHOULD_SAMPLE_SH
    o.sh = 0;
    // Approximated illumination from non-important point lights
#ifdef VERTEXLIGHT_ON
    o.sh += Shade4PointLights(
        unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
        unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
        unity_4LightAtten0, worldPos, worldNormal);
#endif
    o.sh = ShadeSHPerVertex(worldNormal, o.sh);
#endif
#endif // !LIGHTMAP_ON

    o.pos = clipPos;
    o.lightmapUV = lightmapUV;
    o.tspace0 = tspace0;
    o.tspace1 = tspace1;
    o.tspace2 = tspace2;
    o.uv = uv;
    UNITY_TRANSFER_SHADOW(o, v.texcoord1.xy);
    UNITY_TRANSFER_FOG(o, o.pos);
    return o;
}

sampler2D _BumpMap;
half _Cutoff;
sampler2D _MainTex;
sampler2D _PBRTexture;
half _SmoothnessScale;

void AlphaTest(half transparency) {
    clip (transparency - _Cutoff);
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

    specular = specularTerm * FresnelTerm (specularity, ldotH);
}

void LdotH(half3 halfAngle, half3 lightDir, out half ldotH) {
    ldotH = saturate(dot(lightDir, halfAngle));
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

void PBRFromMetallic(half metallic, inout half3 albedo, out half3 specularity, inout half transparency) {
    // see linear unity_ColorSpaceDielectricSpec definition
    specularity = lerp (half3(0.04, 0.04, 0.04), albedo, metallic);
    half oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
    albedo *= oneMinusReflectivity;
    half alpha = transparency;
    albedo = PreMultiplyAlpha(albedo, alpha, oneMinusReflectivity, /*out*/ transparency);
}

void UnityDiffuse(half nl, out half3 diffuse) {
    // diffuse = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;
    diffuse = nl;
}

void UnpackAlbedo(half4 albedo_transparency, out half3 albedo) {
#if defined(UNITY_COLORSPACE_GAMMA) && defined(STAR_GAMMA_TEXTURE)
    albedo = pow(albedo_transparency.xyz, 2.2);
#else
    albedo = albedo_transparency.xyz;
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
    half4 albedo_transparency;
    albedo_transparency = tex2D(_MainTex, IN.uv);

    half transparency;
    transparency = albedo_transparency.w;
    AlphaTest(transparency);

    float4 lightmapUV = IN.lightmapUV;
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

    UNITY_LIGHT_ATTENUATION(atten, IN, worldPos);

    half3 albedo;
    UnpackAlbedo(albedo_transparency, albedo);

    half metallic;
    half occlusion;
    half perceptualSmoothness;
    UnpackProjectKSmoothnessTextureWithOcclusion(uv, metallic, occlusion, perceptualSmoothness);

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

    half3 diffuse;
    UnityDiffuse(nl, diffuse);

    UnityGI gi;
#ifdef UNITY_COMPILER_HLSL
    SurfaceOutputStandard o = (SurfaceOutputStandard)0;
#else
    SurfaceOutputStandard o;
#endif
    o.Albedo = albedo;
    o.Normal = worldNormal;
    o.Emission = 0.0;
    o.Metallic = metallic;
    o.Alpha = transparency;
    o.Occlusion = occlusion;

    UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
    gi.indirect.diffuse = 0;
    gi.indirect.specular = 0;
    gi.light.color = _LightColor0.rgb;
    gi.light.dir = lightDir;

    UnityGIInput giInput;
    UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
    giInput.light = gi.light;
    giInput.worldPos = worldPos;
    giInput.worldViewDir = worldViewDir;
    giInput.atten = atten;
#if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
    giInput.lightmapUV = lightmapUV;
#else
    giInput.lightmapUV = 0.0;
#endif
#if UNITY_SHOULD_SAMPLE_SH
    giInput.ambient = IN.sh;
#else
    giInput.ambient.rgb = 0.0;
#endif
    giInput.probeHDR[0] = unity_SpecCube0_HDR;
    giInput.probeHDR[1] = unity_SpecCube1_HDR;
#if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
    giInput.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
#endif
#ifdef UNITY_SPECCUBE_BOX_PROJECTION
    giInput.boxMax[0] = unity_SpecCube0_BoxMax;
    giInput.probePosition[0] = unity_SpecCube0_ProbePosition;
    giInput.boxMax[1] = unity_SpecCube1_BoxMax;
    giInput.boxMin[1] = unity_SpecCube1_BoxMin;
    giInput.probePosition[1] = unity_SpecCube1_ProbePosition;
#endif

    LightingStandard_GI(o, giInput, gi);

    half3 specularity;
    PBRFromMetallic(metallic, albedo, specularity, transparency);

    half3 specular;
    ImageGGXUnity(ldotH, ndotH, ndotV, nl, roughness, specularity, specular);

    color.xyz = albedo * (gi.indirect.diffuse + gi.light.color * diffuse) + specular * gi.light.color;
    color.w = 1.0f;

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
