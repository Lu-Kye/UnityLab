Shader "KGame/Fog Ground" {

Properties {
    _Distance("Distance", Range(0.000000, 0.999000)) = 0.000000
    _DistanceFallOff("DistanceFallOff", Range(0.000100, 0.500000)) = 0.070000
    _FogAlpha("FogAlpha", Range(0.000000, 1.000000)) = 0.799805
    _FogColor("FogColor", Color) = (1.000000, 1.000000, 1.000000, 1.000000)
    _FogColor2("FogColor2", Color) = (1.000000, 1.000000, 1.000000, 1.000000)
    _FogSpeed("FogSpeed", Range(0.000000, 0.500000)) = 0.099976
    _Height("Height", Range(0.000000, 500.000000)) = 4.400000
    _HeightFallOff("HeightFallOff", Range(0.000000, 1.000000)) = 1.000000
    _MaxDistance("MaxDistance", Range(0.000000, 1.100000)) = 1.100000
    _MaxDistanceFallOff("MaxDistanceFallOff", Range(0.000100, 0.500000)) = 0.150000
    _NoiseStrength("NoiseStrength", Range(0.000000, 1.000000)) = 0.600000
    _NoiseTex("NoiseTex", 2D) = "white" {}
    _Turbulence("Turbulence", Range(0.000000, 15.000000)) = 0.000000
}

SubShader {
Tags { "Queue" = "Transparent+1" "RenderType" = "Transparent" }
LOD 100

Blend SrcAlpha OneMinusSrcAlpha 

Pass {
Tags { "LightMode" = "Always" }

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
    float4 vertex : POSITION;
};

struct v2f {
    float4 pos : SV_Position;
    float4 worldPosWithDepth : TEXCOORD0;
};

v2f vert (appdata v) {
    v2f o;
    UNITY_INITIALIZE_OUTPUT(v2f, o);

    float4 vertex = v.vertex;

    float4 clipPos;
    clipPos = UnityObjectToClipPos(vertex);

    float4 worldPosWithDepth;
    worldPosWithDepth.xyz = mul(unity_ObjectToWorld, vertex).xyz;
    worldPosWithDepth.w = COMPUTE_DEPTH_01;

    o.pos = clipPos;
    o.worldPosWithDepth = worldPosWithDepth;
    return o;
}

float _Distance;
float _DistanceFallOff;
half _FogAlpha;
fixed4 _FogColor;
fixed4 _FogColor2;
half _FogSpeed;
float _Height;
float _HeightFallOff;
float _MaxDistance;
float _MaxDistanceFallOff;
float _NoiseStrength;
sampler2D _NoiseTex;
float _Turbulence;

void FogArguments(out float baselineHeight, out float cameraFogFar, out float clipUnderBaseline, out float distance, out float distanceFallOff, out float height, out float heightFallOff, out float maxDistance, out float maxDistanceFallOff, out float noiseStrength, out float turbulence) {
    noiseStrength = _NoiseStrength;
    turbulence = _Turbulence;
    cameraFogFar = 15.f; //CameraFogFar;

    height = _Height;
    baselineHeight = 0.f; // BaselineHeight;
    clipUnderBaseline = -10000.f; //ClipUnderBaseline;
    heightFallOff = _HeightFallOff;

    distance = _Distance;
    distanceFallOff = _DistanceFallOff;
    maxDistance = _MaxDistance;
    maxDistanceFallOff = _MaxDistanceFallOff;
}

void FogGround(float depth, float distance, float distanceFallOff, float height, float heightFallOff, float maxDistance, float maxDistanceFallOff, half noise, float noiseStrength, half nt, out float fogHeight, inout float3 fogPos, out half groundColor) {
    fogPos.y -= nt;
    float d = (depth - distance) / distanceFallOff;
    float dmax = (maxDistance - depth) / maxDistanceFallOff;
    d = min(d, dmax);
    fogHeight = height + nt;
    float h = (fogHeight - fogPos.y) / (fogHeight * heightFallOff);
    groundColor = saturate(min(d, h)) * saturate(_FogAlpha * (1 - noise * noiseStrength));
}

void FogNoise(float cameraFogFar, float depth, float3 fogPos, float turbulence, out half noise, out half nt) {
    noise = tex2D(_NoiseTex, fogPos.xz * 0.01f/*TextureScale*/ + _Time[1] * _FogSpeed).g;
    nt = noise * turbulence;
    noise /= (depth * cameraFogFar); // attenuate with distance
}

void Output(float fogHeight, float3 fogPos, half groundColor, out half4 color) {
    fixed4 fogColor = lerp(_FogColor, _FogColor2, saturate(fogPos.y / fogHeight));
    color = half4(fogColor.xyz, groundColor);
}

void frag(v2f IN, out half4 color: SV_Target0) { 
    float4 worldPosWithDepth = IN.worldPosWithDepth;

    float baselineHeight;
    float cameraFogFar;
    float clipUnderBaseline;
    float distance;
    float distanceFallOff;
    float height;
    float heightFallOff;
    float maxDistance;
    float maxDistanceFallOff;
    float noiseStrength;
    float turbulence;
    FogArguments(baselineHeight, cameraFogFar, clipUnderBaseline, distance, distanceFallOff, height, heightFallOff, maxDistance, maxDistanceFallOff, noiseStrength, turbulence);

    float depth;
    float3 fogPos;
    fogPos = worldPosWithDepth.xyz;
    depth = worldPosWithDepth.w;
    fogPos.y -= baselineHeight;
    if (fogPos.y < clipUnderBaseline || fogPos.y > height + turbulence) {
        color = half4(0,0,0,0);
        return;
    }

    half noise;
    half nt;
    FogNoise(cameraFogFar, depth, fogPos, turbulence, noise, nt);

    float fogHeight;
    half groundColor;
    FogGround(depth, distance, distanceFallOff, height, heightFallOff, maxDistance, maxDistanceFallOff, noise, noiseStrength, nt, fogHeight, fogPos, groundColor);

    Output(fogHeight, fogPos, groundColor, color);
}
ENDCG

} // Pass end

} // SubShader end

} // Shader end
