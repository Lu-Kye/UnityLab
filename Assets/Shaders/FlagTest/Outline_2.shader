Shader "ZFLAG/Outline_2" {
 Properties {
 // _Color ("Main Color", Color) = (.5,.5,.5,1)
  _MainTex ("Texture", 2D) = "white" {}
  _RimColor ("Hit Color", Color) = (0, 0, 0, 0)
  _RimRate ("Rim Rate", Range(0,5)) = 2
  _Cutoff ("Alpha cutoff", Range(0,1)) = 0.5
  _OutlineColor ("Outline Color", Color) = (1,0,0,1)
  _Outline ("Outline width", Float) = 0.01
    }
 
 SubShader {
  Tags {"Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType" = "Opaque"}
  
  ZWrite On
  
  Pass {
   //Tags { "LightMode" = "Always" "Queue" = "Overlay" }
   Cull front
  
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   
   #include "UnityCG.cginc"
   struct appdata_t {
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float2 texcoord : TEXCOORD0;
   };
   struct v2f {
    float4 vertex : POSITION;
    float4 color : COLOR;
    float2 texcoord : TEXCOORD0;
   };
   sampler2D _MainTex;
   float4 _MainTex_ST;
   float _Cutoff;
   float4 _OutlineColor;
   float _Outline;
   
   v2f vert (appdata_t v)
   {
    v2f o;
    o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
    float3 norm = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);
    o.color = _OutlineColor;
    o.vertex.xy += norm.xy * _Outline;
    o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
    return o;
   }
   
   half4 frag (v2f i) : COLOR
   {
    clip(tex2D(_MainTex,i.texcoord).a - _Cutoff);
    return i.color;
   }
   ENDCG
  }
  
  Pass {
   Offset 0,-500
   
   CGPROGRAM
   #pragma vertex vert
   #pragma fragment frag
   
   #include "UnityCG.cginc"
   struct appdata_t {
    float4 vertex : POSITION;
    float4 color : COLOR;
    float3 normal : NORMAL;
    float2 texcoord : TEXCOORD0;
   };
   struct v2f {
    float4 vertex : POSITION;
    float4 color : COLOR;
    float2 texcoord : TEXCOORD0;
   };
   sampler2D _MainTex;
   float4 _MainTex_ST;
   float4 _RimColor;
   float _RimRate;
   float _Cutoff;
   
   v2f vert (appdata_t v)
   {
    v2f o;
    o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
    
    float3 viewDir = normalize(ObjSpaceViewDir(v.vertex));
    float rim = clamp(1 - saturate ( dot(viewDir, v.normal))*10,0,1);
    o.color = 0.35f * _RimColor;
    o.color += clamp(_RimColor * pow (rim, _RimRate) * 2,0,1);
    o.color.a = 0;
    
    o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
    return o;
   }
   
  // float4 _Color;
   half4 frag (v2f i) : COLOR
   {
    half4 col = tex2D(_MainTex, i.texcoord) + i.color;
   // col *= _Color;
    clip(col.a - _Cutoff);
    return col;
   }
   ENDCG
  }
  
 }
 }