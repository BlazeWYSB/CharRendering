Shader "Unlit/PGR_Hair"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MaskTex ("Mask", 2D) = "white" {}
		_ShadowColor ("Shadow Color", Color) = (0.7, 0.7, 0.7)
        _ShadowRange ("ShadowRange", Range(0,1)) = 0.5
        _AngelCurvity ("天使环弯曲度",Range(0,10))=1
        _SpecularRange ("SpecularRange", Range(0,40)) = 1
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
                float2 uv1 : TEXCOORD1;
				float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float fogCoord : TEXCOORD2;
                float3 viewDirWS : TEXCOORD3;
                float2 uv1 : TEXCOORD4;
                float4 positionCS : SV_POSITION;
            };

            struct BasicDir
            {
                float3 normalDir;
                float3 lightDir ;
                float3 viewDir  ;
                float3 halfDir  ;
                float  NdotL    ;
                float  Half_NdotL;
                float  NdotV    ;
                float  NdotH    ;
            };
            struct TextureCollection
            {
                float4 mainTex;
                float4 maskTex;
            };

            sampler2D _MainTex;
            sampler2D _MaskTex;
            float3 _ShadowColor;
            float _ShadowRange;
            float _SpecularRange;
            float _SpecularStrength;
            float _AngelCurvity;
            TextureCollection texCol;
            BasicDir baseData;
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
            }
            void ComputeBaseTexture(v2f i)
            {
                texCol.mainTex        = tex2D(_MainTex, i.uv);
                texCol.maskTex        = tex2D(_MaskTex, i.uv1);
            }

           
            //------------------------------------漫反射---------------------------------------
            float3 Diffuse()
            {

                float shadowMask=(baseData.Half_NdotL*texCol.maskTex.y);
                shadowMask=saturate(1-shadowMask);
                shadowMask=step(shadowMask,_ShadowRange);
                float3 diffuse=lerp(texCol.mainTex,_ShadowColor*texCol.mainTex,1-shadowMask);
                
                return diffuse;
            } 
            float Buling_Feng(float spcePower,float specStrength){
                float3 specular = 0;
                specular = pow(saturate(baseData.NdotH), spcePower) *specStrength ;    
                specular = max(0, specular);
                return specular;
                //pow(dot(baseData.halfDir,baseData.normalDir),spcePower)*specStrength;
            }
            
            float Hair_Spec(float spcePower,float specStrength){
               
                half spec_term = saturate(baseData.NdotV * _AngelCurvity+ baseData.Half_NdotL * (1-_AngelCurvity)); //反射所占权重 
                float hairSpecular= saturate(step(max(0.01,spec_term),(texCol.maskTex.r)*_SpecularRange)) * specStrength ;
               
                return  hairSpecular;
            } 
            float Hair_Spec2(float spcePower,float specStrength){
               
                half spec_term = baseData.NdotV;
                spec_term =  baseData.NdotV * 0.1 + baseData.Half_NdotL * 0.9; //反射所占权重 
                half toon_spec = saturate((spec_term - (1.0 - _SpecularRange * texCol.maskTex.r)) * texCol.maskTex.b * 300);//色阶化处理得到高光mask 
                
                half3 dir_spec = toon_spec;//进行混合
                return  toon_spec;
            }
           
            
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
                o.uv = v.uv;
                o.uv1=v.uv1;
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
            

              
                float4 res = float4(Diffuse()+Specular(),1);
                //res = float4(Specular(),1);
                //res =float4(mask.r,mask.r,mask.r,1);
                return res;
            }
            ENDHLSL
        }
    }
}
