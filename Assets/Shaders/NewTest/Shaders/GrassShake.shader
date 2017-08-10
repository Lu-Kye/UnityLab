// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "KGame/Transparent/GrassShake" {
 
Properties {
    _Color ("Main Color", Color) = (1,1,1,1)
    _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
    _Cutoff ("Alpha cutoff", Range(0,1)) = 0.5
    _ShakeTime ("Shake Time", Range (0, 1.0)) = 1.0
	_NormalShakeVector("NormalShakeVector", Vector) = (0.25, 0.075, 0.25, 1.0)
	_ForceShakeVector("ForceShakeVector", Vector) = (0.0, 0.0, 0.0, 0.0)
	_ECutoff ("Emisive cutoff", Range(0,1)) = 0.5
}
 
SubShader {
    Tags {"Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType"="TransparentCutout"}
    LOD 200
   Cull off
CGPROGRAM
#pragma target 3.0
#pragma surface surf Lambert alphatest:_Cutoff vertex:vert nodirlightmap nodynlightmap
 
sampler2D _MainTex;
fixed4 _Color;
float _ShakeTime;
fixed4 _NormalShakeVector;
fixed4 _ForceShakeVector;
fixed _ECutoff;
struct Input {
    float2 uv_MainTex;
}; 
 
void vert (inout appdata_full v) {
   
	float4 newPos = v.vertex;   
	newPos.xyz += _NormalShakeVector.xyz * v.texcoord.y * _SinTime.w * _ShakeTime + _ForceShakeVector.xyz* v.texcoord.y * 0.3;
	//newPos.xyz += _ForceShakeVector.xyz* v.texcoord.y;
	v.vertex = newPos;  
	v.texcoord = v.texcoord;
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