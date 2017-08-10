// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Test/OIT BavoilMyers Blend" {

Properties {
    _MainTex ("", 2D) = "white" {}   
    _CountTex ("", 2D) = "white" {}   
}       

Subshader {
Pass {
    Blend OneMinusSrcAlpha SrcAlpha
    ZWrite Off
            
    CGPROGRAM
    #pragma vertex vert
    #pragma fragment frag

    #include "UnityCG.cginc"

    struct v2f {
        half4 pos : POSITION;
        half2 uv : TEXCOORD0;
    };

    sampler2D _MainTex;
    sampler2D _CountTex;

    v2f vert(appdata_img v) {
        v2f o;
        o.pos = UnityObjectToClipPos(v.vertex);
        o.uv = v.texcoord.xy;
        return o;
    }

    half4 frag(v2f pixelData) : SV_Target
    {
        half4 accum = tex2D(_MainTex, pixelData.uv);
        float n = max(1.0, 255.0 * tex2D(_CountTex, pixelData.uv).x);
        half4 color = half4(
            accum.xyz / max(accum.w, 0.0001),
            pow(max(0.0, 1.0 - accum.w / n), n));
#ifdef UNITY_COLORSPACE_GAMMA
        color.xyz = pow(color.xyz, 0.454545);
#endif
        return color;
    }            
    ENDCG
}  
}
    
Fallback off

}