// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/DrawLine"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_ScaleX("BlurScaleX", Range(0.0, 1.0)) = 0.0
		_ScaleY("BlurScaleY", Range(0.0, 1.0)) = 0.0
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
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			uniform float _ScaleX;
			uniform float _ScaleY;

			fixed4 blur(float2 uv)
			{
				fixed4 col = tex2D(_MainTex, uv);

				fixed4 negX = tex2D(_MainTex, float2(uv.x - _ScaleX, uv.y));
				fixed4 posX = tex2D(_MainTex, float2(uv.x + _ScaleX, uv.y));
				fixed4 negY = tex2D(_MainTex, float2(uv.x, uv.y - _ScaleY));
				fixed4 posY = tex2D(_MainTex, float2(uv.x, uv.y + _ScaleY));

				col = (col + negX + posX + negY + posY) / 5.0;

				return col;
			}

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				fixed4 col = blur(i.uv);
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}

			ENDCG
		}
	}
}
