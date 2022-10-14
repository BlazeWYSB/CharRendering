Shader "Unlit/PGR_Hair"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MaskTex ("Mask", 2D) = "white" {}
        _ShadowLerp ("ShadowLerp", Range(0,1)) = 0.5
    }
    SubShader
    {
        Tags {
            "RenderPipeline" = "UniversalRenderPipeline"
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float fogCoord : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _MaskTex;
            float4 _MaskTex_ST;
            float _ShadowLerp;
            CBUFFER_END
           

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                o.normalWS = TransformObjectToWorldNormal(v.normal).xyz;
                o.fogCoord = ComputeFogFactor(o.vertex.z);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // sample the texture
                Light lightData = GetMainLight(i.vertex);
                float4 lightDir =float4(normalize(lightData.direction),1);
                float NDL = max(0,dot(lightDir,i.normalWS));
                float mask= tex2D(_MaskTex, i.uv).y*NDL*1.4;
                float4 abedo= tex2D(_MainTex, i.uv);
                float4 shadow=step(mask,_ShadowLerp);
                float4 col=abedo-shadow*abedo*0.3;
                 col = float4(MixFog(col.xyz, i.fogCoord),1);
                //col =mask;
                return col;
            }
            ENDHLSL
        }
    }
}
