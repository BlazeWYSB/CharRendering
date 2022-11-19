Shader "Unlit/PGR_Face"

{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _ilmTex ("Mask", 2D) = "white" {}
		_ShadowColor ("Shadow Color", Color) = (0.7, 0.7, 0.7)
        _ShadowRange ("ShadowRange", Range(0,1)) = 0.5
        _GradientRate ("GradientRate", Range(0,1)) = 1
        _SSRimWidth ("SSRimWidth", Range(0,2)) = 0
        _SpecularStrength ("SpecularStrength", Range(0,2)) = 1
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
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float fogCoord : TEXCOORD2;
                float3 viewDirWS : TEXCOORD3;
                float4 scrPos : TEXCOORD4;
                float4 positionCS : SV_POSITION;
            };

            struct BasicDir
            {
                float3 normalDir;
                float3 lightDir ;
                float3 viewDir  ;
                float3 halfDir  ;
                float3 frontDir ;
                float3 rightDir ;
                float  NdotL    ;
                float  Half_NdotL;
                float  NdotV    ;
                float  NdotH    ;
            };
            struct TextureCollection
            {
                float4 mainTex;
                float4 ilmTex;
                float4 rev_IlmTex;
                float shadowMsk;
            };
            
            CBUFFER_START(UnityPerMaterial)
            sampler2D _MainTex;
            sampler2D _ilmTex;
            sampler2D _CameraDepthTexture;
            float3 _ShadowColor;
            float _ShadowRange;
            float _GradientRate;
            float _SpecularStrength;
            float _SSRimWidth;
            TextureCollection texCol;
            BasicDir baseData;
            CBUFFER_END
            void ComputeBasicDir(v2f i)
            {
                Light lightData = GetMainLight(i.positionCS);
                baseData.normalDir = normalize(i.normalWS);//法向量
                baseData.lightDir  = normalize(lightData.direction);
                baseData.viewDir   = normalize(i.viewDirWS);
                baseData.halfDir   = normalize(baseData.viewDir+baseData.lightDir);

                baseData.NdotL     = dot(baseData.lightDir,i.normalWS);
                baseData.Half_NdotL= baseData.NdotL * 0.5 + 0.5;
                baseData.NdotV     = dot(baseData.normalDir, baseData.viewDir);
                baseData.NdotH     = dot(baseData.normalDir, baseData.halfDir);
                baseData.rightDir  = TransformObjectToWorldDir(float3(0, -1, 0));
                baseData.frontDir  = TransformObjectToWorldDir(float3(-1, 0, 0));
            }
            void ComputeBaseTexture(v2f i)
            {
                texCol.mainTex        = tex2D(_MainTex, i.uv);
                texCol.ilmTex         = tex2D(_ilmTex, i.uv);
                texCol.rev_IlmTex     = tex2D(_ilmTex, float2(1-i.uv.x,i.uv.y));
              
            }

         
            //------------------------------------漫反射---------------------------------------
            float3 Diffuse()
            {
                float shadowMask=(baseData.Half_NdotL*texCol.ilmTex.y);
                shadowMask=saturate(1-shadowMask);
                shadowMask=step(shadowMask,_ShadowRange);
                texCol.shadowMsk=shadowMask;
                float3 diffuse=lerp(texCol.mainTex,_ShadowColor*texCol.mainTex,1-texCol.shadowMsk);
                
                return diffuse;
            }
            
            float3 sdfDiffuse()
            {
                float3 LightDirXZ = normalize(float3(baseData.lightDir.x,0, baseData.lightDir.z));
                float sdfDot = saturate(dot(baseData.frontDir, LightDirXZ) * 0.5 + 0.5);//计算前向与灯光的角度差（0-1），1代表重合
                sdfDot *= saturate(texCol.ilmTex.g*15);//加上阴影权重
                float ilm = dot(LightDirXZ, baseData.rightDir) > 0 ? texCol.ilmTex.b :texCol.rev_IlmTex.b;//确定采样的贴图
                texCol.shadowMsk = step(ilm,sdfDot);
                float bias = smoothstep(0, _GradientRate, abs(sdfDot-ilm));//越靠近边界，约平滑


                float3 diffuse=lerp(texCol.mainTex,_ShadowColor*texCol.mainTex,bias*(1-texCol.shadowMsk));
                //背光是不要平滑，会突变
                if (sdfDot <0.2)
                    diffuse=lerp(texCol.mainTex,_ShadowColor*texCol.mainTex,1-texCol.shadowMsk);

                //diffuse=float3(bias,bias,bias);
                return diffuse;
            }
               float3 SSRim(v2f i)
               {
                    float3 normalVS=mul(UNITY_MATRIX_V,i.normalWS );
                    float2 scrPos = i.scrPos.xy / i.scrPos.w;
                    float depth = tex2D(_CameraDepthTexture, scrPos.xy).r;
                    float depthValue = Linear01Depth(depth,_ZBufferParams);
                    scrPos += normalVS.xy *_SSRimWidth * 0.01;//uv offset 
                    float depth2 = tex2D(_CameraDepthTexture, scrPos.xy).r;
                    float depthValue2 = Linear01Depth(depth2,_ZBufferParams);
                    //深度差
                    float3 rim=saturate((depthValue2-depthValue)*10000)*(1-texCol.shadowMsk)*texCol.mainTex*(1-_ShadowColor);
                    return rim;
               }
            
            float Hair_Spec(float spcePower,float specStrength){
               
                half spec_term = saturate(baseData.NdotV); //反射所占权重 
                float hairSpecular= saturate(step(max(0.01,spec_term),(texCol.ilmTex.r)*2)) * specStrength ;
                
                hairSpecular=lerp(hairSpecular,0,1-texCol.shadowMsk);
               
                return  hairSpecular;
            } 
            //float Hair_Spec2(float spcePower,float specStrength){
               
            //    half spec_term = baseData.NdotV;
            //    spec_term =  baseData.NdotV * 0.1 + baseData.Half_NdotL * 0.9; //反射所占权重 
            //    half toon_spec = saturate((spec_term - (1.0 - _GradientRate * texCol.ilmTex.r)) * texCol.ilmTex.b * 300);//色阶化处理得到高光mask 
                
            //    half3 dir_spec = toon_spec;//进行混合
            //    return  toon_spec;
            //}
           
            
            //------------------------------------高光---------------------------------------
            float3 Specular()
            {
                //r为黑色无高光
                float specCutOff=float(texCol.ilmTex.r>0.6);
                //specStep=texCol.ilmTex.r;
                float spcePower=(1.01-texCol.ilmTex.r);
                float specStrength=texCol.ilmTex.b*_SpecularStrength;
                float spec=Hair_Spec(spcePower,specStrength);
                //spec=pow(dot(baseData.halfDir,baseData.normalDir),1);
                float3 specular=float3(spec,spec,spec)* texCol.mainTex;

                
                return specular;
            }

           

            v2f vert (appdata v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                o.uv = v.uv;
                o.scrPos = ComputeScreenPos(o.positionCS);
				float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(v.normal).xyz;
                o.fogCoord = ComputeFogFactor(o.positionCS.z);
                o.viewDirWS=_WorldSpaceCameraPos.xyz - positionWS;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                ComputeBasicDir(i);
                ComputeBaseTexture(i);
            
                
                float3 sdf=sdfDiffuse();
                float3 rim=SSRim(i);
              
                float4 res = float4(sdf+rim+Specular(),1);
                //res = float4(Specular(),1);
                //res =float4(mask.r,mask.r,mask.r,1);
                return res;
            }
            ENDHLSL
        }
    }
}
