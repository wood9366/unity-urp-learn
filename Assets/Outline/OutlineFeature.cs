using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class OutlineFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class OutlineSettings
    {
        public string name = "Outline";
        public LayerMask layer;
        [Range(1,32)]
        public int outlineRenderLayer = 32;
        [Range(0, 5000)]
        public int queueMin = 1000;
        [Range(0, 5000)]
        public int queueMax = 3000;
        public Material mat;
    }

    class OutlineRenderPass : ScriptableRenderPass
    {
        private OutlineSettings _settings;
        private FilteringSettings _filteringSettings;
        private ProfilingSampler _samplerDrawShape;
        private ProfilingSampler _samplerEdgeDetect;
        private ProfilingSampler _samplerDrawOutline;
        private int _rtShape;
        private int _rtEdge;
        private int _rtMerge;
        private RenderTargetIdentifier _rtCamera;
        private RenderTextureDescriptor _desc;

        private static readonly ShaderTagId PASS_NAME = new ShaderTagId("UniversalForward");

        private string nameDrawShape => _settings.name + "_DrawShape";
        private string nameEdgeDetect => _settings.name + "_EdgeDetect";
        private string nameDrawOutline => _settings.name + "_DrawOutline";

        public OutlineRenderPass(OutlineSettings settings)
        {
            _settings = settings;

            _samplerDrawShape = new ProfilingSampler(nameDrawShape);
            _samplerEdgeDetect = new ProfilingSampler(nameEdgeDetect);
            _samplerDrawOutline = new ProfilingSampler(nameDrawOutline);

            _filteringSettings = new FilteringSettings(new RenderQueueRange(_settings.queueMin,
                                                                            _settings.queueMax),
                                                       _settings.layer,
                                                       1u << (_settings.outlineRenderLayer - 1));

            _rtShape = Shader.PropertyToID("_OutlineShapeRT");
            _rtEdge = Shader.PropertyToID("_OutlineEdgeTex");
            _rtMerge = Shader.PropertyToID("_OutlineMergeRT");
        }

        public void Setup(ScriptableRenderer render)
        {
            _rtCamera = render.cameraColorTarget;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            _desc = cameraTextureDescriptor;

            var desc = new RenderTextureDescriptor(_desc.width, _desc.height, RenderTextureFormat.R8, 8);

            // desc.msaaSamples = UniversalRenderPipeline.asset.msaaSampleCount;

            cmd.GetTemporaryRT(_rtShape, desc, FilterMode.Bilinear);

            ConfigureTarget(_rtShape);
            ConfigureClear(ClearFlag.All, Color.black);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            DrawShape(context, ref renderingData);
            EdgeDetect(context, ref renderingData);
            DrawOutline(context, ref renderingData);
        }

        void DrawShape(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(nameDrawShape);

            using (new ProfilingScope(cmd, _samplerDrawShape))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                var drawingSettings = CreateDrawingSettings(PASS_NAME,
                                                            ref renderingData,
                                                            SortingCriteria.CommonOpaque);

                drawingSettings.overrideMaterial = _settings.mat;
                drawingSettings.overrideMaterialPassIndex = 0;

                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref _filteringSettings);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        void EdgeDetect(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(nameEdgeDetect);

            using (new ProfilingScope(cmd, _samplerEdgeDetect))
            {
                var desc = new RenderTextureDescriptor(_desc.width, _desc.height, RenderTextureFormat.R8, 0);

                // desc.msaaSamples = UniversalRenderPipeline.asset.msaaSampleCount;

                cmd.GetTemporaryRT(_rtEdge, desc, FilterMode.Bilinear);

                cmd.SetGlobalTexture("_MainTex", _rtShape);

                cmd.Blit(_rtShape, _rtEdge, _settings.mat, 1);

                cmd.ReleaseTemporaryRT(_rtShape);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        void DrawOutline(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(nameDrawOutline);

            using (new ProfilingScope(cmd, _samplerDrawOutline))
            {
                cmd.SetGlobalTexture("_MainTex", _rtEdge);

                cmd.Blit(_rtEdge, _rtCamera, _settings.mat, 2);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    public OutlineSettings _settings = new OutlineSettings();

    private OutlineRenderPass _pass;

    public override void Create()
    {
        _pass = new OutlineRenderPass(_settings);
        _pass.renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        _pass.Setup(renderer);
        renderer.EnqueuePass(_pass);
    }
}
