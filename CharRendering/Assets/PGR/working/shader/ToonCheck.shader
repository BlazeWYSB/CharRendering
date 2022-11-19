Shader "Unlit/ToonCheck"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [KeywordEnum(R, G, B, A, Vert_R, Vert_G, Vert_B, Vert_A)] _Channel("Channel ", Float) = 0
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
            #pragma multi_compile _CHANNEL_R _CHANNEL_G _CHANNEL_B _CHANNEL_A _CHANNEL_VERT_R _CHANNEL_VERT_G _CHANNEL_VERT_B _CHANNEL_VERT_A
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                fixed4 color : COLOR;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0; 
                fixed4 color : COLOR;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o; 
                o.color = v.color;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                
                float zz=sqrt(1-dot(i.color.rg*2-1,i.color.rg*2-1));
                #if _CHANNEL_R
                col=fixed4(col.x,col.x,col.x,col.w);
                #endif 
                 
                 #if _CHANNEL_G
                 col=fixed4(col.y,col.y,col.y,col.w);
                 #endif  

                #if _CHANNEL_B
                col=fixed4(col.z,col.z,col.z,col.w);
                #endif
                
                #if _CHANNEL_A
                col=fixed4(col.w,col.w,col.w,col.w);
                #endif

                #if _CHANNEL_VERT_R
                col=fixed4(i.color.x,i.color.x,i.color.x,i.color.w);
                //col=fixed4(i.color.x,i.color.y,i.color.z,i.color.w);
                #endif

                #if _CHANNEL_VERT_G
                col=fixed4(i.color.y,i.color.y,i.color.y,i.color.w);
                //col=fixed4(i.color.x,i.color.y,i.color.z,i.color.w);
                #endif

                #if _CHANNEL_VERT_B
                col=fixed4(i.color.z,i.color.z,i.color.z,i.color.w);
                //col=fixed4(i.color.x,i.color.y,i.color.z,i.color.w);
                #endif

                #if _CHANNEL_VERT_A
                col=fixed4(i.color.a,i.color.a,i.color.a,i.color.w);
               // col=fixed4(i.color.x,i.color.y,zz,i.color.w);
                #endif
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
