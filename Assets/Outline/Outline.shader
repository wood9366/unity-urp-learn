Shader "Custom/URP/Outline"
{
    Properties
    {
        _OutlineColor ("Outline Color", Color) = (0, 1, 0, 1)
        _OutlineSize ("Outline Size", Range(1, 10)) = 1
        _ZBias ("Bias", Range(0.001, 0.01)) = 0.001
        [Toggle(OUTLINE_DEPTH_FEATURE)] _OutlineDepthFeature ("Outline Depth Feature", Float) = 0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            // Outline Shape Pass
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local __ OUTLINE_DEPTH_FEATURE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                float4 posScreen : TEXCOORD0;
                float4 positionHCS  : SV_POSITION;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            float _ZBias;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.posScreen = ComputeScreenPos(OUT.positionHCS);
                return OUT;
            }

            half4 frag(Varyings i) : SV_Target
            {
#if OUTLINE_DEPTH_FEATURE
                i.posScreen.xyz /= i.posScreen.w;

                float d = SampleSceneDepth(i.posScreen.xy);

                float z = i.posScreen.z + _ZBias * (UNITY_REVERSED_Z == 0 ? -1 : 1);

                if (UNITY_REVERSED_Z == 0 ? z <= d : d <= z)
                {
                    return 1;
                }
                else
                {
                    return 0;
                }
#else
                return 1;
#endif
            }
            ENDHLSL
        }

        Pass
        {
            // Outline Edge Detect Pass
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 pos   : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 pos  : SV_POSITION;
                float4 uv : TEXCOORD0;
                float4 uv2 : TEXCOORD1;
                float4 uv3 : TEXCOORD2;
                float4 uv4 : TEXCOORD3;
                float2 uv5 : TEXCOORD4;
            };

            float2 _MainTex_TexelSize;
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            float _OutlineSize;

            Varyings vert(Attributes i)
            {
                Varyings o;

                o.pos = TransformObjectToHClip(i.pos.xyz);

                float dx = _MainTex_TexelSize.x * _OutlineSize;
                float dy = _MainTex_TexelSize.y * _OutlineSize;

                o.uv.xy = i.uv + float2(-dx, dy);
                o.uv.zw = i.uv + float2(0, dy);
                o.uv2.xy = i.uv + float2(dx, dy);
                o.uv2.zw = i.uv + float2(-dx, 0);
                o.uv3.xy = i.uv;
                o.uv3.zw = i.uv + float2(dx, 0);
                o.uv4.xy = i.uv + float2(-dx, -dy);
                o.uv4.zw = i.uv + float2(0, -dy);
                o.uv5.xy = i.uv + float2(dx, -dy);

                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float p0 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy).r;
                float p1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.zw).r;
                float p2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv2.xy).r;
                float p3 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv2.zw).r;
                float p4 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv3.xy).r;
                float p5 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv3.zw).r;
                float p6 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv4.xy).r;
                float p7 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv4.zw).r;
                float p8 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv5.xy).r;

                half edge = abs(-p0 + p2 - 2 * p3 + 2 * p5 - p6 + p8) +
                    abs(p0 + 2 * p1 + p2 - p6 - 2 * p7 - p8);

                return edge;
            }
            ENDHLSL
        }

        Pass
        {
            // Outline Pass
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 pos   : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 pos  : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_OutlineEdgeTex);
            SAMPLER(sampler_OutlineEdgeTex);

            float4 _OutlineColor;

            Varyings vert(Attributes i)
            {
                Varyings o;

                o.pos = TransformObjectToHClip(i.pos.xyz);
                o.uv = i.uv;

                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 screen = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                half outline = SAMPLE_TEXTURE2D(_OutlineEdgeTex, sampler_OutlineEdgeTex, i.uv).r;

                half4 color;

                color.rgb = lerp(screen.rgb, _OutlineColor.rgb, outline * _OutlineColor.a);
                color.a = screen.a;

                return color;
            }
            ENDHLSL
        }
    }
}
