Shader "ZFLAG/test"
{
	Properties
	{
		_Alpha ("Alpha", Range (0, 1)) = 1
		_xOffset ("xOffset", Range(0, 1)) = 0.5
		_yOffset ("yOffset", Range(0, 1)) = 0.5
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 200
		Blend SrcAlpha OneMinusSrcAlpha
		
		Pass
		{
			CGPROGRAM
// Upgrade NOTE: excluded shader from DX11 and Xbox360; has structs without semantics (struct appdata members normal)
#pragma exclude_renderers d3d11 xbox360
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			uniform float _Alpha;
			uniform float _xOffset;
			uniform float _yOffset;
			
			struct appdata
			{
				float4 vertex : POSITION;
				float2 texcoord : TEXCOORD0;
				float4 color : COLOR;
			};

			struct v2f
			{
				float2 texcoord : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float4 color : COLOR;
			};
			
			float4 drawcircle(float4 color, float2 uv)
			{
				float xcoord = uv.x - 0.5;
				float ycoord = uv.y - 0.5;
				
//				if(pow(xcoord, 2) + pow(ycoord, 2) < 0.1 * abs(sin(_Time.y)))
				if(pow(xcoord, 2) + pow(ycoord, 2) < 0.01)
				{
					return color;
				}
				else
				{
					color.a = _Alpha;
					return color;
				}
			}
			
			float4 move(float4 color, float2 uv)
			{
				float xcoord = uv.x - 0.5;
				float ycoord = uv.y - 0.5;
				
				if(color.a != _Alpha)
				{
					
				}
				
				return color;
			}
			
			v2f vert (appdata v)
			{
				v2f o;
				
				//_Offset = pow(v.vertex.x, 2) + pow(v.vertex.y, 2);
				
//				if((v.vertex.x < 0 && v.vertex.y < 0) || (v.vertex.x > 0 && v.vertex.y > 0))
//				{
//					v.vertex += float4(0, 0, _Offset, 0);
//				}
//				else
//				{
//					v.vertex -= float4(0, 0, _Offset, 0);					
//				}
				
				o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
				o.texcoord = v.texcoord;
				o.color = v.color;
				return o;
			}
			
			fixed4 frag (v2f i) : COLOR
			{	
				i.color = drawcircle(i.color, i.texcoord);
				return i.color;
			}
			ENDCG
		}
	}
}






