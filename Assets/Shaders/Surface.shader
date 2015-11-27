Shader "Custom/SurfaceShader"   
{  
  //-------------------------------【属性】-----------------------------------------  
  Properties   
  {  
    _MainTex ("Texture", 2D) = "white" {}  
    _RimColor ("Rim Color", Color) = (0.17,0.36,0.81,0.0)  
    _RimPower ("Rim Power", Range(0,10)) = 1.0  
  }  
  //----------------------------【开始一个子着色器】---------------------------  
  SubShader   
  {  
    //渲染类型为Opaque，不透明  
    Tags { "RenderType" = "Opaque" }  
    //-------------------开始CG着色器编程语言段-----------------  
    CGPROGRAM  
    //使用兰伯特光照模式  
    #pragma surface surf Lambert  
    //输入结构  
    struct Input   
    {  
      float2 uv_MainTex;//纹理贴图  
      float3 viewDir;//观察方向  
    };  
    //变量声明  
    sampler2D _MainTex;//主纹理
    float4 _RimColor;//边缘颜色  
    float _RimPower;//边缘颜色强度  
    //表面着色函数的编写  
    void surf (Input IN, inout SurfaceOutput o)  
    {  
      //表面反射颜色为纹理颜色  
      o.Albedo = tex2D (_MainTex, IN.uv_MainTex).rgb;   
      //边缘颜色  
      half rim = 1.0 - saturate(dot (normalize(IN.viewDir), o.Normal));  
      //边缘颜色强度  
      o.Emission = _RimColor.rgb * pow (rim, _RimPower);  
    }  
    //-------------------结束CG着色器编程语言段------------------  
    ENDCG  
  }   
  //“备胎”为普通漫反射  
  Fallback "Diffuse"  
}
