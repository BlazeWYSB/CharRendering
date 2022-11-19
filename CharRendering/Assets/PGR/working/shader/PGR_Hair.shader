Shader "Unlit/PGR_Hair"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MaskTex ("Mask", 2D) = "white" {}
		_ShadowColor ("Shadow Color", Color) = (0.7, 0.7, 0.7)
        _ShadowRange ("ShadowRange", Range(0,2)) = 0.5
        _AngelCurvity ("天使环弯曲度",Range(0,10))=1
        _SpecularRange ("SpecularRange", Range(0,40)) = 1
        _SpecularStrength ("SpecularStrength", Range(0,2)) = 1
        _SSRimWidth ("SSRimWidth", Range(0,2)) = 0
        _Smooth ("Smooth", Range(0,1)) = 1
        _Alpha ("Alpha", Range(0,1)) = 1
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            Stencil
            {
                Ref 1
                Comp Greater
                Pass Keep
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
                float  NdotL    ;
                float  Half_NdotL;
                float  NdotV    ;
                float  NdotH    ;
            };
            struct TextureCollection
            {
                float4 mainTex;
                float4 maskTex;
                float shadowMsk;
                float bias;
            };
            CBUFFER_START(UnityPerMaterial)
            sampler2D _MainTex;
            sampler2D _MaskTex;
            sampler2D _CameraDepthTexture;
            float3 _ShadowColor;
            float _ShadowRange;
            float _AngelCurvity;
            float _SpecularRange;
            float _SpecularStrength;
            float _SSRimWidth;
            float _Smooth;
            float _Alpha;
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

                baseData.NdotL     = dot(-baseData.lightDir,i.normalWS);
                baseData.Half_NdotL= baseData.NdotL *_ShadowRange + _ShadowRange;
                baseData.NdotV     = dot(baseData.normalDir, baseData.viewDir);
                baseData.NdotH     = dot(baseData.normalDir, baseData.halfDir);
                baseData.frontDir  = TransformObjectToWorldDir(float3(-1, 0, 0));
           }
           void ComputeBaseTexture(v2f i)
           {
                _Smooth=(1-_Smooth)*0.06+0.94;//方便调参
                texCol.mainTex        = tex2D(_MainTex, i.uv);
                texCol.maskTex        = tex2D(_MaskTex, i.uv);
                float shadowMask=step(baseData.Half_NdotL,texCol.maskTex.y);
                //shadowMask=1-step(saturate(baseData.NdotL)*saturate(-_ShadowRange+texCol.maskTex.y),0);
                //提取明暗交界处
                float NDL_Bias=step(_ShadowRange,texCol.maskTex.y)*saturate(1-abs(baseData.NdotL)-_Smooth);//白条渐变带
                float ILM_B_Bias=step(0,baseData.NdotL)*saturate(1-abs(texCol.maskTex.y-_ShadowRange)-_Smooth);

                texCol.bias =saturate(NDL_Bias*20+ILM_B_Bias*20);
                texCol.shadowMsk=shadowMask;
           }

         
            //------------------------------------漫反射---------------------------------------
            float3 Diffuse()
            {
                float3 diffuse=lerp(texCol.mainTex,_ShadowColor*texCol.mainTex,(1-texCol.shadowMsk)*(1-texCol.bias));
                return diffuse;
            } 
            
            //---------------------------屏幕空间深度边缘光----------------
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
            
            float Hair_Spec(float spcePower,float specStrength)
            {
               
                half spec_term = saturate(baseData.NdotV * _AngelCurvity+ baseData.Half_NdotL * (1-_AngelCurvity)); //反射所占权重 
                float hairSpecular= saturate(step(max(0.01,spec_term),(texCol.maskTex.r)*_SpecularRange)) * specStrength ;
                
                hairSpecular=lerp(hairSpecular,0,1-texCol.shadowMsk);
               
                return  hairSpecular;
            } 
            //float Hair_Spec2(float spcePower,float specStrength){
               
            //    half spec_term = baseData.NdotV;
            //    spec_term =  baseData.NdotV * 0.1 + baseData.Half_NdotL * 0.9; //反射所占权重 
            //    half toon_spec = saturate((spec_term - (1.0 - _SpecularRange * texCol.maskTex.r)) * texCol.maskTex.b * 300);//色阶化处理得到高光mask 
                
            //    half3 dir_spec = toon_spec;//进行混合
            //    return  toon_spec;
            //}
           
            
            //------------------------------------高光---------------------------------------
            float3 Specular()
            {
                //r为黑色无高光
                float specCutOff=float(texCol.maskTex.r>0.6);
                //specStep=texCol.maskTex.r;
                float spcePower=(1.01-texCol.maskTex.r);
                float specStrength=texCol.maskTex.b*_SpecularStrength;
                float spec=Hair_Spec(spcePower,specStrength);
                //spec=pow(dot(baseData.halfDir,baseData.normalDir),1);
                float3 specular=float3(spec,spec,spec)* texCol.mainTex;

                
                return specular;
            }

           

            v2f vert (appdata v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                o.scrPos = ComputeScreenPos(o.positionCS);
                o.uv = v.uv;
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
                float3 rim=SSRim(i);
                float4 res = float4(Diffuse()+rim +Specular(),1);
                //res = float4(Specular(),1);
                
                //res =float4(rim,rim,rim,1);
                return res;
            }
            ENDHLSL
        }

        Pass
        { 
            
            Name "HairAlpha"
 	        Tags{"LightMode"="HairAlpha"}
            Stencil
            {
                Ref 1
                Comp Less
                Pass Keep
                Fail Keep
            } 
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Back
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
                float4 color : COLOR;
				float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float fogCoord : TEXCOORD2;
                float3 viewDirWS : TEXCOORD3;
                float4 scrPos : TEXCOORD4;
                float colorA: TEXCOORD5;
                float4 positionCS : SV_POSITION;
            };

            struct BasicDir
            {
                float3 normalDir;
                float3 lightDir ;
                float3 viewDir  ;
                float3 halfDir  ;
                float3 frontDir ;
                float  NdotL    ;
                float  Half_NdotL;
                float  NdotV    ;
                float  NdotH    ;
            };
            struct TextureCollection
            {
                float4 mainTex;
                float4 maskTex;
                float shadowMsk;
                float bias;
            };
            CBUFFER_START(UnityPerMaterial)
            sampler2D _MainTex;
            sampler2D _MaskTex;
            sampler2D _CameraDepthTexture;
            float3 _ShadowColor;
            float _ShadowRange;
            float _AngelCurvity;
            float _SpecularRange;
            float _SpecularStrength;
            float _SSRimWidth;
            float _Smooth;
            float _Alpha;
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
                baseData.frontDir  = TransformObjectToWorldDir(float3(-1, 0, 0));
           }
           void ComputeBaseTexture(v2f i)
           {
                _Smooth=(1-_Smooth)*0.06+0.94;//方便调参
                texCol.mainTex        = tex2D(_MainTex, i.uv);
                texCol.maskTex        = tex2D(_MaskTex, i.uv);
                float shadowMask=saturate(-baseData.NdotL)*saturate(texCol.maskTex.y-_ShadowRange);
                shadowMask=1-step(saturate(baseData.NdotL)*saturate(-_ShadowRange+texCol.maskTex.y),0);
                //提取明暗交界处
                float NDL_Bias=step(_ShadowRange,texCol.maskTex.y)*saturate(1-abs(baseData.NdotL)-_Smooth);//白条渐变带
                float ILM_B_Bias=step(0,baseData.NdotL)*saturate(1-abs(texCol.maskTex.y-_ShadowRange)-_Smooth);

                texCol.bias =saturate(NDL_Bias*20+ILM_B_Bias*20);
                texCol.shadowMsk=shadowMask;
           }

         
            //------------------------------------漫反射---------------------------------------
            float3 Diffuse()
            {
                float3 diffuse=lerp(texCol.mainTex,_ShadowColor*texCol.mainTex,(1-texCol.shadowMsk)*(1-texCol.bias));
                return diffuse;
            } 
            
            //---------------------------屏幕空间深度边缘光----------------
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
                float3 rim=saturate((depthValue2-depthValue)*1000)*(1-texCol.shadowMsk)*texCol.mainTex*(1-_ShadowColor);
                return rim;
           }
            
     
           

            v2f vert (appdata v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                o.scrPos = ComputeScreenPos(o.positionCS);
                o.uv = v.uv;
				float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(v.normal).xyz;
                o.fogCoord = ComputeFogFactor(o.positionCS.z);
                o.viewDirWS=_WorldSpaceCameraPos.xyz - positionWS;
                o.colorA=v.color.a;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                ComputeBasicDir(i);
                ComputeBaseTexture(i);
                float3 rim=SSRim(i);
                float4 res = float4((Diffuse()+rim),saturate(_Alpha+1-i.colorA));
                //res = float4(Specular(),1);
                
                //res =float4(rim,rim,rim,1);
                return res;
            }
            ENDHLSL
        }

   


    }
}
//