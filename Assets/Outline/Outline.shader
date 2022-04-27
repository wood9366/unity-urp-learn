Shader "Custom/URP/Outline"
{
    Properties
    {
        _OutlineColor ("Outline Color", Color) = (0, 1, 0, 1)
        _OutlineBackColor ("Outline Back Color", Color) = (1, 0, 0, 1)
        _OutlineSize ("Outline Size", Range(1, 10)) = 1
        _ZBias ("Bias", Range(0.001, 0.01)) = 0.001
        [KeywordEnum(COMMON, DEPTH, BACK)] Mode ("Mode", Float) = 0
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
            #pragma shader_feature_local MODE_COMMON MODE_DEPTH MODE_BACK

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
#if defined(MODE_DEPTH) || defined(MODE_BACK)
                float4 posScreen : TEXCOORD0;
#endif
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _OutlineColor;
            float4 _OutlineBackColor;
            float _OutlineSize;
            float _ZBias;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

#if defined(MODE_DEPTH) || defined(MODE_BACK)
                OUT.posScreen = ComputeScreenPos(OUT.positionHCS);
#endif
                return OUT;
            }

            half4 frag(Varyings i) : SV_Target
            {
#if MODE_DEPTH
                i.posScreen.xyz /= i.posScreen.w;

                float d = SampleSceneDepth(i.posScreen.xy);
                float z = i.posScreen.z + _ZBias * (UNITY_REVERSED_Z == 0 ? -1 : 1);
                float outline = (UNITY_REVERSED_Z == 0 ? z <= d : d <= z) ? 1 : 0;

                return outline;
#elif MODE_BACK
                return half4(1, i.posScreen.z / i.posScreen.w, 0, 0);
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
            #pragma shader_feature_local MODE_COMMON MODE_DEPTH MODE_BACK

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

            CBUFFER_START(UnityPerMaterial)
            float4 _OutlineColor;
            float4 _OutlineBackColor;
            float _OutlineSize;
            float _ZBias;
            CBUFFER_END

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
                float4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv3.xy);

                float p1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy).r;
                float p2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.zw).r;
                float p3 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv2.xy).r;
                float p4 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv2.zw).r;
                float p5 = c.r;
                float p6 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv3.zw).r;
                float p7 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv4.xy).r;
                float p8 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv4.zw).r;
                float p9 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv5.xy).r;

                half edge = abs(p3 + 2 * p6 + p9 - (p1 + 2 * p4 + p7)) +
                    abs(p1 + 2 * p2 + p3 - (p7 + 2 * p8 + p9));

#if MODE_BACK
                return half4(edge, c.g, 0, 0);
#else
                return edge;
#endif
            }
            ENDHLSL
        }

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha

            // Outline Pass
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local MODE_COMMON MODE_DEPTH MODE_BACK

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

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

            CBUFFER_START(UnityPerMaterial)
            float4 _OutlineColor;
            float4 _OutlineBackColor;
            float _OutlineSize;
            float _ZBias;
            CBUFFER_END

            Varyings vert(Attributes i)
            {
                Varyings o;

                o.pos = TransformObjectToHClip(i.pos.xyz);
                o.uv = i.uv;

                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                half outline = c.r;

                half4 color;

                color.rgb = _OutlineColor.rgb;
                color.a = outline * _OutlineColor.a;

#if MODE_BACK
                float d = SampleSceneDepth(i.uv);
                float z = c.g + _ZBias * (UNITY_REVERSED_Z == 0 ? -1 : 1);

                if (UNITY_REVERSED_Z == 0 ? d <= z : z <= d)
                {
                    color.rgb = _OutlineBackColor.rgb;
                    color.a = outline * _OutlineBackColor.a;
                }
#endif
                return color;
            }
            ENDHLSL
        }
    }
}
