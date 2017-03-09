Shader "ZFLAG/Outline_2" {
 Properties {
  _OutlineColor ("Outline Color", Color) = (0,0,0,1) 
  _OutlineWidth ("Outline width",Range(0.001, 0.1)) = 0.007
  _MainTex ("Base (RGB)", 2D) = "white" { }
 }
 
 
SubShader
{
  Tags { "Queue" = "Geometry" }
  LOD 200  
  Pass {
   Name "OUTLINE"
   Tags { "LightMode" = "Always" }
   ZWrite Off
   ZTEST off
   ColorMask RGB
  CGPROGRAM
  #pragma vertex vert
  #pragma fragment frag
  #include "UnityCG.cginc"
  struct appdata {
   float4 vertex : POSITION;
   float3 normal : NORMAL;
  };
  struct v2f {
   float4 pos : POSITION;
   float4 color : COLOR;
  };
  uniform float _OutlineWidth;
  uniform float4 _OutlineColor;
  v2f vert(appdata v)
  {
    v2f o;
    v.vertex.xyz *= 1 + _OutlineWidth;
    o.pos=mul(UNITY_MATRIX_MVP,v.vertex);

    o.color = _OutlineColor;
    return o;
  }
  
  half4 frag(v2f i) :COLOR
  {
   return i.color;
  }
  ENDCG
  }
  Pass
  {
    NAME"BASE"
    cull back
             CGPROGRAM
             #pragma vertex vert
             #pragma fragment frag
             #include "UnityCG.cginc"
             struct vertOut {
                 float4 pos:SV_POSITION;
                 float4 tex: TEXCOORD0;
             };
    float _Amount;
             vertOut vert(appdata_base v) {
                 vertOut o;
                 o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
                 o.tex = v.texcoord;
                 return o;
             }
    sampler2D _MainTex;
             fixed4 frag(vertOut i) : COLOR0
             {
                 fixed4 col    = tex2D(_MainTex,i.tex.xy);
                 return col;
             }
            ENDCG
            }
  } 
 Fallback "Diffuse"

}