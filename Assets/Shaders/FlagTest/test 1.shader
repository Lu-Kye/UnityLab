// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "ZFLAG/test_1"
{
	Properties
	{

	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		Pass
		{
			CGPROGRAM
// Upgrade NOTE: excluded shader from DX11 and Xbox360; has structs without semantics (struct appdata members normal)
#pragma exclude_renderers d3d11 xbox360
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			struct appdata
			{
				float4 vertex : POSITION;
				float2 texcoord : TEXCOORD0;
				float4 color : COLOR;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float2 texcoord : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float4 color : COLOR;
			};
			
			v2f vert (appdata v)
			{
				v2f o;
								
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.texcoord = v.texcoord;
				o.color = o.vertex;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				//fixed4 col = fixed4(i.color.a, i.color.a, i.color.a, 1.0);
				return fixed4(1.0, 1.0, 1.0, 1.0);
			}
			ENDCG
		}
	}
}






