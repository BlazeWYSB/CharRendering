Shader "Unlit/PGR_Eye"

{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Dis("Dis",Range(0,10))=0
    }
    SubShader
    {
        Pass
        { 
            Tags { "RenderPipeline" = "UniversalRenderPipeline"
            "RenderType"="Opaque"
            "Queue" = "Geometry-10" }
            Stencil
            {
                Ref 2
                Comp GEqual
                Pass Replace
                Fail Keep
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog



            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float fogCoord : TEXCOORD1;
                float4 positionCS : SV_POSITION;
            };

          
            CBUFFER_START(UnityPerMaterial)
            sampler2D _MainTex;
            float _Dis;
            CBUFFER_END
         

            v2f vert (appdata v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                o.uv = v.uv;
                o.fogCoord = ComputeFogFactor(o.positionCS.z);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 mainTex= tex2D(_MainTex, i.uv);
                float dis=1.5*(i.uv.x-0.56)*(i.uv.x-0.56)+(i.uv.y-0.5)*(i.uv.y-0.5);
                return float4(mainTex*(1+_Dis),1);
            }
            ENDHLSL
        }
    }
}
