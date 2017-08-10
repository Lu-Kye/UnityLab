// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/Mobius" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
	}
	
	CGINCLUDE
    #include "UnityCG.cginc"  
    #pragma target 3.0  
 
    #define vec2 float2
    #define vec3 float3
    #define vec4 float4
    #define mat2 float2x2
    #define iGlobalTime _Time.y
    #define mod fmod
    #define mix lerp
    #define atan atan2
    #define fract frac 
    #define texture2D tex2D
    #define iResolution _ScreenParams
    #define gl_FragCoord ((_iParam.srcPos.xy/_iParam.srcPos.w)*_ScreenParams.xy)  
 
    struct vertOut {      
        float4 pos : SV_POSITION;      
        float4 srcPos : TEXCOORD0;    
    };    
 
    vertOut vert(appdata_base v) {    
        vertOut o;    
        o.pos = UnityObjectToClipPos(v.vertex);
        o.srcPos = ComputeScreenPos(o.pos);   
        return o;    
    }
 
    vec4 main(vec2 fragCoord) {
        return vec4(1, 1, 1, 1);
    }
 
    fixed4 frag(vertOut _iParam) : COLOR0 {  
       	vec2 fragCoord = gl_FragCoord;
        return main(fragCoord);
    }  
    ENDCG
    
	SubShader {
		Pass {
			CGPROGRAM
 
            #pragma vertex vert
            #pragma fragment frag
            #pragma fragmentoption ARB_precision_hint_fastest   
 
            ENDCG
		}
	} 
	FallBack "Diffuse"
}
