// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "ShaderPractice/SpecularBlinnPhongPixelLit"
{
	Properties
	{
		_Diffuse("Diffuse", Color) = (1, 1, 1, 1)
		_Specular("Specular", Color) = (1, 1, 1, 1)
		_Gloss("Gloss", Range(8.0, 256)) = 20
	}
	SubShader
	{
		Pass
		{
			Tags { "LightMode" = "ForwardBase" }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "Lighting.cginc"
			fixed4 _Diffuse;
			fixed4 _Specular;
			float _Gloss;
			struct a2v
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};
			struct v2f
			{
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
			};

			v2f vert(a2v v)
			{
				v2f o;
				float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.worldPos = worldPos.xyz;
				o.pos = mul(unity_MatrixVP, worldPos);
				o.worldNormal = mul(v.normal, (float3x3)unity_ObjectToWorld);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLightDir));
				fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
				fixed3 halfDir = normalize(worldLightDir + viewDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(worldNormal, halfDir)), _Gloss); //Blinn-Phong model specular
				fixed3 color = ambient + diffuse + specular;
				return fixed4(color, 1.0);
			}
			ENDCG
		}
	}
	FallBack "Specular"
}