using Godot;

[GlobalClass]
[Tool]
public partial class CustomCompositorEffect : CompositorEffect
{
    RenderingDevice rd;
    Rid shader;
    Rid pipeline;

    public CustomCompositorEffect() : base()
    {
        EffectCallbackType = EffectCallbackTypeEnum.PostOpaque;

        rd = RenderingServer.GetRenderingDevice();
        RenderingServer.CallOnRenderThread(Callable.From(() => InitializeCompute()));
    }

    public override void _Notification(int what)
    {
        if (what == GodotObject.NotificationPredelete)
        {
            if (shader.IsValid)
            {
                RenderingServer.FreeRid(shader);
            }
        }
    }

    private void InitializeCompute()
    {
        rd = RenderingServer.GetRenderingDevice();
        if (rd == null)
            return;
        
        var shaderFile = ResourceLoader.Load<RDShaderFile>("res://CompositorEffects/test/custom_compositor_effect.glsl");
        if (shaderFile == null)
            return;

        shader = rd.ShaderCreateFromSpirV(shaderFile.GetSpirV());
        if (!shader.IsValid)
            return;

        pipeline = rd.ComputePipelineCreate(shader);
    }

    public override void _RenderCallback(int effectCallbackType, RenderData renderData)
    {
        if (rd == null || !pipeline.IsValid)
        {
            GD.Print("RenderingDevice or pipeline is invalid");
            Enabled = false;
            return;
        }

        if (effectCallbackType != (int)EffectCallbackTypeEnum.PostOpaque)
        {
            GD.Print("EffectCallbackType is not PostOpaque");
            Enabled = false;
            return;
        }

        if (renderData.GetRenderSceneBuffers() is not RenderSceneBuffersRD renderSceneBuffers)
        {
            GD.Print("RenderSceneBuffers is not RenderSceneBuffersRD");
            Enabled = false;
            return;
        }

        Vector2I size = renderSceneBuffers.GetInternalSize();
        if (size.X == 0 && size.Y == 0)
        {
            GD.Print("Size is 0");
            Enabled = false;
            return;
        }
        
        var xGroups = (size.X - 1) / 8 + 1;
        var yGroups = (size.Y - 1) / 8 + 1;
        var zGroups = 1;

        byte[] pushConstants;
        {
            using var ms = new System.IO.MemoryStream();
            using var bw = new System.IO.BinaryWriter(ms);

            bw.Write((float)size.X);
            bw.Write((float)size.Y);
            bw.Write(0f);
            bw.Write(0f);

            pushConstants = ms.ToArray();
        }

        uint viewCount = renderSceneBuffers.GetViewCount();
        if (viewCount == 0)
        {
            GD.Print("ViewCount is 0");
            Enabled = false;
            return;
        }

        for (uint i = 0; i < viewCount; i++)
        {
            Rid colorImage = renderSceneBuffers.GetColorLayer(i);

            var colorUniform = new RDUniform
            {
                UniformType = RenderingDevice.UniformType.Image,
                Binding = 0
            };
            colorUniform.AddId(colorImage);

            var uniformSet = UniformSetCacheRD.GetCache(shader, 0, [colorUniform]);

            var computeList = rd.ComputeListBegin();
            rd.ComputeListBindComputePipeline(computeList, pipeline);
            rd.ComputeListBindUniformSet(computeList, uniformSet, 0);
            rd.ComputeListSetPushConstant(computeList, pushConstants, (uint)pushConstants.Length);
            rd.ComputeListDispatch(computeList, (uint)xGroups, (uint)yGroups, (uint)zGroups);
            rd.ComputeListEnd();
        }
    }
}
