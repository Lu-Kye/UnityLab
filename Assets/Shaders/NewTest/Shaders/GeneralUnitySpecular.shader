Shader "KGame/Unity Specular" {

Properties {
    _BumpMap("BumpMap", 2D) = "white" {}
    _GlossMapScale("GlossMapScale", Range(0.000000, 1.000000)) = 1.000000
    _MainTex("MainTex", 2D) = "white" {}
    _SpecGlossMap("SpecGlossMap", 2D) = "white" {}
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
half _GlossMapScale;
sampler2D _MainTex;
sampler2D _SpecGlossMap;

void GammaCompression(inout half4 color) {
#if defined(UNITY_COLORSPACE_GAMMA) && defined(STAR_GAMMA_TEXTURE)
    color.xyz = pow(color.xyz, 0.454545);
#endif 
}

void LocalNormal(float2 uv, out half3 localNormal) {
    localNormal = UnpackNormal(tex2D(_BumpMap, uv));
}

void UnityForward_Lightmap(half3 albedo, UnityGI gi, half oneMinusReflectivity, half perceptualSmoothness, half3 specularity, half3 worldNormal, half3 worldViewDir, out half4 color) {
    color = UNITY_BRDF_PBS (albedo, specularity, oneMinusReflectivity,
        perceptualSmoothness, worldNormal, worldViewDir, gi.light, gi.indirect);
}

void UnityFragmentGI_Lightmap(UnityGIInput giInput, Unity_GlossyEnvironmentData glossyData, half occlusion, bool reflections, inout UnityGI gi) {
    if (reflections) {
        gi.indirect.specular = UnityGI_IndirectSpecular(giInput, occlusion, glossyData);
    }
}

void UnityGIInput_Lightmap(fixed atten, UnityLight light, float4 lightmapUV, float3 worldPos, half3 worldViewDir, out UnityGIInput giInput) {
    giInput = (UnityGIInput)0;
    giInput.light = light;
    giInput.worldPos = worldPos;
    giInput.worldViewDir = worldViewDir;
    giInput.atten = atten;

#if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
        giInput.ambient = 0;
        giInput.lightmapUV = lightmapUV;
#else
        //giInput.ambient = lightmapUV.rgb;
        //giInput.lightmapUV = 0;
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
}

void UnityGI_Lightmap(UnityGIInput giInput, half occlusion, half3 worldNormal, out UnityGI gi) {
    ResetUnityGI(gi);
    // Base pass with Lightmap support is responsible for handling ShadowMask / blending here for performance reason
#if defined(HANDLE_SHADOWS_BLENDING_IN_GI)
        half bakedAtten = UnitySampleBakedOcclusion(giInput.lightmapUV.xy, giInput.worldPos);
        float zDist = dot(_WorldSpaceCameraPos - giInput.worldPos, UNITY_MATRIX_V[2].xyz);
        float fadeDist = UnityComputeShadowFadeDistance(giInput.worldPos, zDist);
        giInput.atten = UnityMixRealtimeAndBakedShadows(giInput.atten, bakedAtten, UnityComputeShadowFade(fadeDist));
#endif

    gi.light = giInput.light;
    gi.light.color *= giInput.atten;

#if UNITY_SHOULD_SAMPLE_SH
        gi.indirect.diffuse = ShadeSHPerPixel (worldNormal, giInput.ambient, giInput.worldPos);
#endif

#if defined(LIGHTMAP_ON)
        // Baked lightmaps
        half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, giInput.lightmapUV.xy);
        half3 bakedColor = DecodeLightmap(bakedColorTex);

        #ifdef DIRLIGHTMAP_COMBINED
            fixed4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER (unity_LightmapInd, unity_Lightmap, giInput.lightmapUV.xy);
            gi.indirect.diffuse = DecodeDirectionalLightmap (bakedColor, bakedDirTex, worldNormal);

            #if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK) && defined(SHADOWS_SCREEN)
                ResetUnityLight(gi.light);
                gi.indirect.diffuse = SubtractMainLightWithRealtimeAttenuationFromLightmap (gi.indirect.diffuse, giInput.atten, bakedColorTex, worldNormal);
            #endif

        #else // not directional lightmap
            gi.indirect.diffuse = bakedColor;

            #if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK) && defined(SHADOWS_SCREEN)
                ResetUnityLight(gi.light);
                gi.indirect.diffuse = SubtractMainLightWithRealtimeAttenuationFromLightmap(gi.indirect.diffuse, giInput.atten, bakedColorTex, worldNormal);
            #endif

        #endif
#endif

#ifdef DYNAMICLIGHTMAP_ON
        // Dynamic lightmaps
        fixed4 realtimeColorTex = UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, giInput.lightmapUV.zw);
        half3 realtimeColor = DecodeRealtimeLightmap (realtimeColorTex);

        #ifdef DIRLIGHTMAP_COMBINED
            half4 realtimeDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, giInput.lightmapUV.zw);
            gi.indirect.diffuse += DecodeDirectionalLightmap (realtimeColor, realtimeDirTex, worldNormal);
        #else
            gi.indirect.diffuse += realtimeColor;
        #endif
#endif

    gi.indirect.diffuse *= occlusion;
}

void UnityGlossyEnvironmentSetup2(half perceptualRoughness, half3 worldRefl, out Unity_GlossyEnvironmentData glossyData) {
    glossyData.roughness = perceptualRoughness;
    glossyData.reflUVW = worldRefl;
}

void UnityMainLight(out UnityLight light) {
    light.color = _LightColor0.rgb;
    light.dir = _WorldSpaceLightPos0.xyz;
    light.ndotl = 0;
}

void UnitySpecularSetup(float2 uv, inout half3 albedo, out half oneMinusReflectivity, out half perceptualRoughness, out half perceptualSmoothness, out half3 specularity, inout half transparency) {
    half4 specGloss = tex2D(_SpecGlossMap, uv);
#if defined(UNITY_COLORSPACE_GAMMA) && defined(STAR_GAMMA_TEXTURE)
    specularity = pow(specGloss.xyz, 2.2);
#else
    specularity = specGloss.xyz;
#endif

    perceptualSmoothness = specGloss.w * _GlossMapScale;
    perceptualRoughness = max(0, 1.0 - perceptualSmoothness);

    //albedo = _Color.rgb * albedo;
    half alpha = transparency;
    albedo = EnergyConservationBetweenDiffuseAndSpecular(albedo, specularity, /*out*/ oneMinusReflectivity);
    albedo = PreMultiplyAlpha(albedo, alpha, oneMinusReflectivity, transparency);
}

void UnpackAlbedo(half4 albedo_transparency, out half3 albedo) {
#if defined(UNITY_COLORSPACE_GAMMA) && defined(STAR_GAMMA_TEXTURE)
    albedo = pow(albedo_transparency.xyz, 2.2);
#else
    albedo = albedo_transparency.xyz;
#endif
}

void WorldRelf(half3 worldNormal, half3 worldViewDir, out half3 worldRefl) {
    worldRefl = reflect(-worldViewDir, worldNormal);
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

    float3 worldPos;
    worldPos = float3(tspace0.w, tspace1.w, tspace2.w);

    half4 albedo_transparency;
    albedo_transparency = tex2D(_MainTex, uv);

    half transparency;
    transparency = albedo_transparency.w;

    half3 albedo;
    UnpackAlbedo(albedo_transparency, albedo);

    half3 localNormal;
    LocalNormal(uv, localNormal);

    half3 worldNormal;
    WorldTangentNormal(localNormal, tspace0, tspace1, tspace2, worldNormal);

    half3 worldViewDir;
    worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));

    half3 worldRefl;
    WorldRelf(worldNormal, worldViewDir, worldRefl);

    bool reflections;
    reflections = true;

    half occlusion;
    occlusion = 1.0;

    UNITY_LIGHT_ATTENUATION(atten, IN, worldPos);

    UnityLight light;
    UnityMainLight(light);

    UnityGIInput giInput;
    UnityGIInput_Lightmap(atten, light, lightmapUV, worldPos, worldViewDir, giInput);

    UnityGI gi;
    UnityGI_Lightmap(giInput, occlusion, worldNormal, gi);

    half oneMinusReflectivity;
    half perceptualRoughness;
    half perceptualSmoothness;
    half3 specularity;
    UnitySpecularSetup(uv, albedo, oneMinusReflectivity, perceptualRoughness, perceptualSmoothness, specularity, transparency);

    Unity_GlossyEnvironmentData glossyData;
    UnityGlossyEnvironmentSetup2(perceptualRoughness, worldRefl, glossyData);

    UnityFragmentGI_Lightmap(giInput, glossyData, occlusion, reflections, gi);

    UnityForward_Lightmap(albedo, gi, oneMinusReflectivity, perceptualSmoothness, specularity, worldNormal, worldViewDir, color);

    color.w = transparency;

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
