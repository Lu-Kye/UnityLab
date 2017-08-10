// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/SurfaceToVF"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {} 
		_MainColor("Main Color",Color) = (1,1,1,1)
    	_RimColor ("Rim Color", Color) = (0.17,0.36,0.81,0.0)  
   		//_RimPower ("Rim Power", Range(0.1,9)) = 0.5
   		_RimWidth("Rim Width",Range(0,2)) = 0.5
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vertTest
			#pragma fragment fragTest
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata_test
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct vertex_data
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				fixed3 color : COLOR;
			};

			sampler2D _MainTex;
			fixed4 _MainTex_ST;
			fixed4 _RimColor;
			float _RimWidth;
			fixed4 _MainColor;
			
			vertex_data vertTest (appdata_test v)
			{
				vertex_data o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				
				float3 viewDir = normalize(ObjSpaceViewDir(v.vertex));
				float dotProduct = 1 - dot(v.normal,viewDir) ;
				o.color = smoothstep(1 - _RimWidth,1.0,dotProduct);
				o.color *= _RimColor;
				
				o.uv = v.uv.xy;
				return o;
			}
			
			fixed4 fragTest (vertex_data i) : SV_Target
			{
				
				fixed4 col = tex2D(_MainTex, i.uv);
				col *= _MainColor;
				col.rgb += i.color; 
				 				
				return col;
			}
			ENDCG
		}
	}
}
