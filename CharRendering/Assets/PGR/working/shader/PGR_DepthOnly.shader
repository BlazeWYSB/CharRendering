Shader "Unlit/PGR_DepthOnly"
{
   
    SubShader
    {
        Tags {
            "RenderPipeline" = "UniversalRenderPipeline"
            "RenderType"="Opaque"
        }
        LOD 100

           Pass {
 	        Tags{"LightMode"="DepthOnly"}
 	        ZWrite On
 	        ColorMask 0
         }
    }
}
