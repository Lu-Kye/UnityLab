Shader "KGame/Emi_2sid" {

	Properties
	{
		
		_Emi("Emi", 2D) = "white" {}
	_Em_power("Em_power", Float) = 1
		_DIffuse("DIffuse", 2D) = "white" {}
	}

		SubShader
	{
		Tags{ "RenderType" = "Opaque"  "Queue" = "Geometry+0" }
		Cull Off
		CGPROGRAM
#pragma target 3.0
#pragma multi_compile_instancing
#pragma surface surf BlinnPhong keepalpha addshadow fullforwardshadows 
		struct Input
	{
		float2 uv_DIffuse;
		float2 uv_Emi;
	};

	uniform sampler2D _DIffuse;
	uniform sampler2D _Emi;

	UNITY_INSTANCING_CBUFFER_START(Ashader)
		UNITY_DEFINE_INSTANCED_PROP(float, _Em_power)
		UNITY_INSTANCING_CBUFFER_END

		void surf(Input input , inout SurfaceOutput output)
	{
		output.Albedo = tex2D(_DIffuse,input.uv_DIffuse).xyz;
		output.Emission = (tex2D(_Emi,input.uv_Emi) * UNITY_ACCESS_INSTANCED_PROP(_Em_power)).xyz;
		output.Alpha = 1;
	}

	ENDCG
	}
		Fallback "Diffuse"
		//CustomEditor "ASEMaterialInspector"
}
