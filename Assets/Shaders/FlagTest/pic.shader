// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/pic"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_GrayProperty ("GrayThreshold", Range(0, 1)) = 0.5
		_GrayScale ("GrayScale", Range(0, 10)) = 3
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			uniform float _GrayProperty;
			uniform float _GrayScale;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv);

				fixed avg = (col.r + col.g + col.b) / 3.0;

				if (avg <= _GrayProperty)
					col.r = col.g = col.b = (col.r + col.g + col.b) / _GrayScale;

				return col;
			}
			ENDCG
		}
	}
}
