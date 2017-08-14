Shader "KGame/Terrain Mesh Splatting Rain 3" {

Properties {
    _Control0("Control0", 2D) = "white" {}
    _Metallic0("Metallic0", Vector) = (1.000000, 1.000000, 1.000000, 1.000000)
    _Normal0("Normal0", 2D) = "bump" {}
    _Normal1("Normal1", 2D) = "bump" {}
    _Normal2("Normal2", 2D) = "bump" {}
    _Size0("Size0", Vector) = (1.000000, 1.000000, 1.000000, 1.000000)
    _Smoothness0("Smoothness0", Vector) = (1.000000, 1.000000, 1.000000, 1.000000)
    _Splat0("Splat0", 2D) = "white" {}
    _Splat1("Splat1", 2D) = "white" {}
    _Splat2("Splat2", 2D) = "white" {}
    _TerrainLightmapScaleOffset("TerrainLightmapScaleOffset", Vector) = (0.000000, 0.000000, 0.000000, 0.000000)
    _TerrainSize("TerrainSize", Vector) = (0.000000, 0.000000, 1.000000, 1.000000)
    _WetCoeff("WetCoeff", Range(0.000000, 1.000000)) = 1.000000
    _WetScale("WetScale", Range(0.000000, 0.199951)) = 0.099976
}

SubShader {
Tags { "DisableBatching" = "True" "Queue" = "Geometry-100" "RenderType" = "Opaque" }
LOD 100

Pass {
Tags { "LightMode" = "ForwardBase" }

CGPROGRAM

#pragma vertex vert
#pragma fragment frag

#pragma multi_compile_fwdbase
#pragma multi_compile_fog

#define UNITY_PASS_FORWARDBASE
#ifndef LIGHTMAP_ON
#define LIGHTMAP_ON
#endif
#ifndef LIGHTMAP_SHADOW_MIXING
#define LIGHTMAP_SHADOW_MIXING
#endif
#ifndef SHADOWS_SCREEN
#define SHADOWS_SCREEN
#endif

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
    float4 splattingPack0 : TEXCOORD0;
    float4 splattingPack1 : TEXCOORD1;
    float4 tspace0 : TEXCOORD2;
    float4 tspace1 : TEXCOORD3;
    float4 tspace2 : TEXCOORD4;
    float2 uv : TEXCOORD5;
    UNITY_FOG_COORDS(6)
    UNITY_SHADOW_COORDS(7)
#if !defined(LIGHTMAP_ON) && defined(UNITY_SHOULD_SAMPLE_SH)
    half3 sh : TEXCOORD8;
#endif
};
float4 _Size0;
float4 _TerrainSize;

void SplattingMeshTerrainUVs3(float2 uv, out float4 splattingPack0, out float4 splattingPack1) {
    float2 maxUv = uv * _TerrainSize.zw;
    splattingPack0.xy = maxUv / _Size0[0];
    splattingPack0.zw = maxUv / _Size0[1];
    splattingPack1.xy = maxUv / _Size0[2];
    splattingPack1.zw = float2(0, 0);
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
    float2 uv = v.texcoord;
    float4 vertex = v.vertex;

    float4 clipPos;
    clipPos = UnityObjectToClipPos(vertex);

    float4 splattingPack0;
    float4 splattingPack1;
    SplattingMeshTerrainUVs3(uv, splattingPack0, splattingPack1);

    float3 worldPos;
    worldPos = mul(unity_ObjectToWorld, vertex).xyz;

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
    o.splattingPack0 = splattingPack0;
    o.splattingPack1 = splattingPack1;
    o.tspace0 = tspace0;
    o.tspace1 = tspace1;
    o.tspace2 = tspace2;
    o.uv = uv;
    UNITY_TRANSFER_SHADOW(o, v.texcoord1.xy);
    UNITY_TRANSFER_FOG(o, o.pos);
    return o;
}

sampler2D _Control0;
half4 _Metallic0;
sampler2D _Normal0;
sampler2D _Normal1;
sampler2D _Normal2;
half4 _Smoothness0;
sampler2D _Splat0;
sampler2D _Splat1;
sampler2D _Splat2;
float4 _TerrainLightmapScaleOffset;
half _WetCoeff;
half _WetScale;

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

void SplattingMesh3(float4 splattingPack0, float4 splattingPack1, float2 splattingUV, out half3 albedo, out half3 localNormal, out half metallic, out half perceptualSmoothness, out half transparency) {
    half weight = 0.f;
    fixed4 mixedDiffuse = fixed4(0.f, 0.f, 0.f, 0.f);
    fixed4 nrm = fixed4(0.f, 0.f, 0.f, 0.f);
    metallic = 0.f;

    half4 splat_control0 = tex2D(_Control0, splattingUV);
    weight += dot(splat_control0, half4(1, 1, 1, 1));
    {
        splat_control0 /= (weight + 1e-3f);
        mixedDiffuse += splat_control0.r * tex2D(_Splat0, splattingPack0.xy) * half4(1.0, 1.0, 1.0, _Smoothness0.r);
        mixedDiffuse += splat_control0.g * tex2D(_Splat1, splattingPack0.zw) * half4(1.0, 1.0, 1.0, _Smoothness0.g);
        mixedDiffuse += splat_control0.b * tex2D(_Splat2, splattingPack1.xy) * half4(1.0, 1.0, 1.0, _Smoothness0.b);
        nrm += splat_control0.r * tex2D(_Normal0, splattingPack0.xy);
        nrm += splat_control0.g * tex2D(_Normal1, splattingPack0.zw);
        nrm += splat_control0.b * tex2D(_Normal2, splattingPack1.xy);
        metallic += dot(splat_control0, _Metallic0);
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

void UnityDiffuse(half nl, out half3 diffuse) {
    // diffuse = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;
    diffuse = nl;
}

void WetMaterial(half metallic, float2 uv, inout half3 albedo, inout half perceptualSmoothness) {
    //half rain_mask = tex2D(WetMask, uv);
    //half rain_mask = occlusion;
    half rain_mask = _WetCoeff;
    perceptualSmoothness += _WetScale * rain_mask;
    perceptualSmoothness = min(1.0f, perceptualSmoothness);
    half porosity = saturate(((1 - perceptualSmoothness) - 0.5) * 10.f );
    float factor = lerp(0.1, 1, metallic * porosity);
    albedo *= lerp(1, (factor * 5), rain_mask);
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
    float4 tspace0 = IN.tspace0;
    float4 tspace1 = IN.tspace1;
    float4 tspace2 = IN.tspace2;
    float2 uv = IN.uv;

    half occlusion;
    occlusion = 1.0;

    float4 lightmapUV;
#ifdef DYNAMICLIGHTMAP_ON
    lightmapUV.zw = uv * _TerrainLightmapScaleOffset.xy + _TerrainLightmapScaleOffset.zw;
#else
    lightmapUV.zw = float2(0, 0);
#endif

#ifdef LIGHTMAP_ON
    lightmapUV.xy = uv * _TerrainLightmapScaleOffset.xy + _TerrainLightmapScaleOffset.zw;
#else
    lightmapUV.xy = float2(0, 0);
#endif

    float3 worldPos;
    worldPos = float3(tspace0.w, tspace1.w, tspace2.w);

    half3 lightDir;
    lightDir = normalize(UnityWorldSpaceLightDir(worldPos));

    UNITY_LIGHT_ATTENUATION(atten, IN, worldPos);

    float2 splattingUV;
    splattingUV = uv;

    half3 albedo;
    half3 localNormal;
    half metallic;
    half perceptualSmoothness;
    half transparency;
    SplattingMesh3(splattingPack0, splattingPack1, splattingUV, albedo, localNormal, metallic, perceptualSmoothness, transparency);

    half3 worldNormal;
    WorldTangentNormal(localNormal, tspace0, tspace1, tspace2, worldNormal);

    WetMaterial(metallic, uv, albedo, perceptualSmoothness);

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
