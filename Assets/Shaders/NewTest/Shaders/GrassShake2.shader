// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "KGame/Transparent/GrassShake2" {
 
Properties {
    _Color ("Main Color", Color) = (1,1,1,1)
    _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
    _Cutoff ("Alpha cutoff", Range(0,1)) = 0.5
    _ShakeDisplacement ("Displacement", Range (0, 1.0)) = 1.0
    _ShakeTime ("Shake Time", Range (0, 1.0)) = 1.0
    _ShakeWindspeed ("Shake Windspeed", Range (0, 1.0)) = 1.0
    _ShakeBending ("Shake Bending", Range (0, 1.0)) = 1.0
    _ECutoff ("Emisive cutoff", Range(0,1)) = 0.5
}
 
SubShader {
    Tags {"Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType"="TransparentCutout"}
	Cull Off
   
CGPROGRAM
#pragma target 3.0
#pragma surface surf Lambert alphatest:_Cutoff vertex:vert nodirlightmap nodynlightmap
#include "TerrainEngine.cginc"
sampler2D _MainTex;
fixed4 _Color;
float _ShakeDisplacement;
float _ShakeTime;
float _ShakeWindspeed;
float _ShakeBending;
fixed _ECutoff;
 
struct Input {
    float2 uv_MainTex;
};
 
void vert (inout appdata_full v) {
   
    float factor = (1 - _ShakeDisplacement -  v.color.r) * 0.5;
       
    const float _WindSpeed  = (_ShakeWindspeed  +  v.color.g );    
    const float _WaveScale = _ShakeDisplacement;
   
    const float4 _waveXSize = float4(0.048, 0.06, 0.24, 0.096);
    const float4 _waveZSize = float4 (0.024, .08, 0.08, 0.2);
    const float4 waveSpeed = float4 (1.2, 2, 1.6, 4.8);
 
    float4 _waveXmove = float4(0.024, 0.04, -0.12, 0.096);
    float4 _waveZmove = float4 (0.006, .02, -0.02, 0.1);
   
    float4 waves;
    waves = v.vertex.x * _waveXSize;
    waves += v.vertex.z * _waveZSize;
 
    waves += _Time.x * (1 - _ShakeTime * 2 - v.color.b ) * waveSpeed *_WindSpeed;
 
    float4 s, c;
    waves = frac (waves);
    FastSinCos (waves, s,c);
 
    float waveAmount = v.texcoord.y * (v.color.a + _ShakeBending);
    s *= waveAmount;
 
    s *= normalize (waveSpeed);
 
    s = s * s;
    float fade = dot (s, 1.3);
    s = s * s;
    float3 waveMove = float3 (0,0,0);
    waveMove.x = dot (s, _waveXmove);
    waveMove.z = dot (s, _waveZmove);
    v.vertex.xz -= mul ((float3x3)unity_WorldToObject, waveMove).xz;
   
}
 
void surf (Input IN, inout SurfaceOutput o) {
    fixed4 col = tex2D(_MainTex, IN.uv_MainTex);
    fixed4 c = col * _Color;
    o.Albedo = c.rgb;
    o.Emission = col*_ECutoff;
    o.Alpha = c.a;
}
ENDCG
}
 
Fallback "Transparent/Cutout/VertexLit"
}