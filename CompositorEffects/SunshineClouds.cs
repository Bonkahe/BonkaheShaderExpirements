using Godot;
using Godot.NativeInterop;
using System;
using System.Collections.Generic;
using System.Linq;

[Tool]
[GlobalClass]
public partial class SunshineClouds : CompositorEffect
{
    [Export] public Texture2D HeightGradient { get { return _HeightGradient; } set { _HeightGradient = value; _valueChanged = true; } }
    private Texture2D _HeightGradient;
    [Export] public Texture3D LargeScaleNoise { get { return _LargeScaleNoise; } set { _LargeScaleNoise = value; _valueChanged = true; } }
    private Texture3D _LargeScaleNoise;
    [Export] public Texture3D MediumScaleNoise { get { return _MediumScaleNoise; } set { _MediumScaleNoise = value; _valueChanged = true; } }
    private Texture3D _MediumScaleNoise;
    [Export] public Texture3D SmallScaleNoise { get { return _SmallScaleNoise; } set { _SmallScaleNoise = value; _valueChanged = true; } }
    private Texture3D _SmallScaleNoise;

    [Export(PropertyHint.File, "*.glsl")] public RDShaderFile ComputeShader;

    [Export] public int MaxStepCount { get { return _maxStepCount; } set { _maxStepCount = value; _valueChanged = true; } }
    private int _maxStepCount = 300;
    [Export] public int LightingStepCount { get { return _lightingStepCount; } set { _lightingStepCount = value; _valueChanged = true; } }
    private int _lightingStepCount = 4;
    [Export(PropertyHint.Range, "0,1")] public float AtmosphericDensity { get { return _atmosphericDensity; } set { _atmosphericDensity = value; _valueChanged = true; } }
    private float _atmosphericDensity = 0.2f;
    [Export(PropertyHint.Range, "0,5")] public float CloudsDensity { get { return _cloudsDensity; } set { _cloudsDensity = value; _valueChanged = true; } }
    private float _cloudsDensity = 0.5f;
    [Export(PropertyHint.Range, "0,2")] public float CloudsSharpnessPower { get { return _cloudsSharpnessPower; } set { _cloudsSharpnessPower = value; _valueChanged = true; } }
    private float _cloudsSharpnessPower = 1.0f;
    [Export(PropertyHint.Range, "0,2")] public float CloudsLightingSharpnessPower { get { return _cloudsLightingSharpnessPower; } set { _cloudsLightingSharpnessPower = value; _valueChanged = true; } }
    private float _cloudsLightingSharpnessPower = 0.1f;
    [Export(PropertyHint.Range, "0,10")] public float LightingDensity { get { return _lightingDensity; } set { _lightingDensity = value; _valueChanged = true; } }
    private float _lightingDensity = 0.5f;
    [Export(PropertyHint.Range, "0,1")] public float CloudsDetailPower { get { return _cloudsDetailPower; } set { _cloudsDetailPower = value; _valueChanged = true; } }
    private float _cloudsDetailPower = 0.2f;
    [Export(PropertyHint.Range, "0,1")] public float CloudsCoverage { get { return _cloudsCoverage; } set { _cloudsCoverage = value; _valueChanged = true; } }
    private float _cloudsCoverage = 0.2f;
    [Export(PropertyHint.Range, "100,150000")] public float LargeNoiseScale { get { return _largeNoiseScale; } set { _largeNoiseScale = value; _valueChanged = true; } }
    private float _largeNoiseScale = 40000.0f;
    [Export(PropertyHint.Range, "100,40000")] public float MediumNoiseScale { get { return _mediumNoiseScale; } set { _mediumNoiseScale = value; _valueChanged = true; } }
    private float _mediumNoiseScale = 8000.0f;
    [Export(PropertyHint.Range, "100,20000")] public float SmallNoiseScale { get { return _smallNoiseScale; } set { _smallNoiseScale = value; _valueChanged = true; } }
    private float _smallNoiseScale = 5000.0f;

    [Export] public float MinStepDistance { get { return _minStepDistance; } set { _minStepDistance = value; _valueChanged = true; } }
    private float _minStepDistance = 200.0f;
    [Export] public float MaxStepDistance { get { return _maxStepDistance; } set { _maxStepDistance = value; _valueChanged = true; } }
    private float _maxStepDistance = 300.0f;
    [Export] public float LightingStepDistance { get { return _lightingStepDistance; } set { _lightingStepDistance = value; _valueChanged = true; } }
    private float _lightingStepDistance = 300.0f;
    [Export(PropertyHint.Range,"0,1")] public float StepDistanceBias { get { return _stepDistanceBias; } set { _stepDistanceBias = value; _valueChanged = true; } }
    private float _stepDistanceBias = 0.05f;

    [Export] public float CloudFloor { get { return _cloudFloor; } set { _cloudFloor = value; _valueChanged = true; } }
    private float _cloudFloor = 500.0f;
    [Export] public float CloudCeiling { get { return _cloudCeiling; } set { _cloudCeiling = value; _valueChanged = true; } }
    private float _cloudCeiling = 5000.0f;

    [Export] public Vector3 LargeScaleCloudsPosition { get; set; } = Vector3.Zero;
    [Export] public Vector3 MediumScaleCloudsPosition { get; set; } = Vector3.Zero;
    [Export] public Vector3 DetailCloudsPosition { get; set; } = Vector3.Zero;
    [Export] public Vector3 PrimaryDirectionalLightDirection { get; set; } = new Vector3(1.0f, 1.0f, 0.0f);
    [Export] public Color PrimaryDirectionalLightColor { get; set; } = new Color(1.0f, 1.0f, 1.0f, 1.0f);
    [Export] public Color AmbientLightColor { get; set; } = new Color(0.0f, 0.0f, 0.0f, 1.0f);
    [Export] public Color DistanceFogColor { get; set; } = new Color(1.0f, 1.0f, 1.0f, 1.0f);
    [Export] public Color GroundColor { get; set; } = new Color(0.0f, 0.0f, 0.0f, 1.0f);



    private RenderingDevice _rd;
    private Rid _shader;
    private Rid _pipeline;
    private Rid _nearestSampler;
    private Rid _linearSampler;
    private Rid _linearSamplerNoRepeat;
    private Rid _generalDataBuffer;
    private Rid[] _accumilationTextures;
    private byte[] _pushConstants;
    private Vector2I _lastSize = new Vector2I(0,0);

    private RenderSceneBuffersRD _buffers;


    private Rid[] _uniformSets;
    private float[] _camMat;
    private float[] _projMat;
    private float[] _simpleData;
    private byte[] _generalData;

    private bool _valueChanged = false;

    private float _time = 0.0f;

    public SunshineClouds()
    {
        EffectCallbackType = EffectCallbackTypeEnum.PreTransparent;
        AccessResolvedDepth = true;

        _rd = RenderingServer.GetRenderingDevice();
        RenderingServer.CallOnRenderThread(Callable.From(InitializeCompute));

        RDSamplerState samplerState = new RDSamplerState();
        samplerState.MinFilter = RenderingDevice.SamplerFilter.Nearest;
        samplerState.MagFilter = RenderingDevice.SamplerFilter.Nearest;
        samplerState.RepeatU = RenderingDevice.SamplerRepeatMode.Repeat;
        samplerState.RepeatV = RenderingDevice.SamplerRepeatMode.Repeat;
        samplerState.RepeatW = RenderingDevice.SamplerRepeatMode.Repeat;
        _nearestSampler = _rd.SamplerCreate(samplerState);

        RDSamplerState linearsamplerState = new RDSamplerState();
        linearsamplerState.MinFilter = RenderingDevice.SamplerFilter.Linear;
        linearsamplerState.MagFilter = RenderingDevice.SamplerFilter.Linear;
        linearsamplerState.RepeatU = RenderingDevice.SamplerRepeatMode.Repeat;
        linearsamplerState.RepeatV = RenderingDevice.SamplerRepeatMode.Repeat;
        linearsamplerState.RepeatW = RenderingDevice.SamplerRepeatMode.Repeat;
        _linearSampler = _rd.SamplerCreate(linearsamplerState);


        RDSamplerState linearsamplerStateNoRepeat = new RDSamplerState();
        linearsamplerStateNoRepeat.MinFilter = RenderingDevice.SamplerFilter.Linear;
        linearsamplerStateNoRepeat.MagFilter = RenderingDevice.SamplerFilter.Linear;
        linearsamplerStateNoRepeat.RepeatU = RenderingDevice.SamplerRepeatMode.ClampToEdge;
        linearsamplerStateNoRepeat.RepeatV = RenderingDevice.SamplerRepeatMode.ClampToEdge;
        linearsamplerStateNoRepeat.RepeatW = RenderingDevice.SamplerRepeatMode.ClampToEdge;
        _linearSamplerNoRepeat = _rd.SamplerCreate(linearsamplerStateNoRepeat);
    }


    public override void _Notification(int what)
    {
        if (what == NotificationPredelete)
        {
            RenderingServer.CallOnRenderThread(Callable.From(ClearCompute));
        }
    }

    private void ClearCompute()
    {
        GD.Print("clearing compute");
        if (_rd != null && _shader.IsValid)
        {
            _rd.FreeRid(_shader);
            _rd.FreeRid(_nearestSampler);
            _rd.FreeRid(_linearSampler);
            _rd.FreeRid(_linearSamplerNoRepeat);
            _rd.FreeRid(_pipeline);
            _rd.FreeRid(_generalDataBuffer);
            foreach (var item in _uniformSets)
            {
                if (item.IsValid)
                {
                    _rd.FreeRid(item);
                }
            }
            _uniformSets = null;
        }
    }

    public void InitializeCompute()
    {
        if (_rd == null)
        {
            Enabled = false;
            GD.PrintErr("No rendering device on load.");
            return;
        }

        ClearCompute();

        if (ComputeShader == null)
        {
            ComputeShader = ResourceLoader.Load<RDShaderFile>("res://CompositorEffects/SunshineCloudsCompute.glsl");
        }

        if (ComputeShader == null)
        {
            Enabled = false;
            GD.PrintErr("No Shader found on load.");
            return;
        }

        var shaderSpirv = ComputeShader.GetSpirV();
        _shader = _rd.ShaderCreateFromSpirV(shaderSpirv);
        if (_shader.IsValid)
        {
            _pipeline = _rd.ComputePipelineCreate(_shader);
        }
    }

    public override void _RenderCallback(int effectCallbackType, RenderData renderData)
    {
        if (_rd != null && _pipeline.IsValid && HeightGradient != null && LargeScaleNoise != null && MediumScaleNoise != null && SmallScaleNoise != null)
        {
            _buffers = renderData.GetRenderSceneBuffers() as RenderSceneBuffersRD;
            if (_buffers != null)
            {
                
                Vector2I size = _buffers.GetInternalSize();
                if (size.X == 0 && size.Y == 0)
                {
                    return;
                }

                uint viewCount = _buffers.GetViewCount();

                if (size != _lastSize || _uniformSets == null || _uniformSets.Length != viewCount)
                {
                    //Set up uniforms to be re-used.
                    if (_accumilationTextures != null)
                    {
                        foreach (var item in _accumilationTextures)
                        {
                            if (item.IsValid)
                            {
                                _rd.FreeRid(item);
                            }
                        }
                    }
                    _accumilationTextures = new Rid[viewCount];
                    _uniformSets = new Rid[viewCount];
                    for (uint view = 0; view < viewCount; view++)
                    {
                        Rid colorImage = _buffers.GetColorLayer(view);
                        Rid depthImage = _buffers.GetDepthLayer(view);

                        var format = _rd.TextureGetFormat(colorImage);
                        format.Format = RenderingDevice.DataFormat.R32G32Sfloat;
                        //GD.Print(format.Format);
                        _accumilationTextures[view] = _rd.TextureCreate(format, new RDTextureView(), null);

                        var _uniformsArray = new Godot.Collections.Array<RDUniform>();

                        var coloruniform = new RDUniform();
                        coloruniform.UniformType = RenderingDevice.UniformType.Image;
                        coloruniform.Binding = 0;
                        coloruniform.AddId(colorImage);
                        _uniformsArray.Add(coloruniform);

                        var depthuniform = new RDUniform();
                        depthuniform.UniformType = RenderingDevice.UniformType.SamplerWithTexture;
                        depthuniform.Binding = 1;
                        depthuniform.AddId(_nearestSampler);
                        depthuniform.AddId(depthImage);
                        _uniformsArray.Add(depthuniform);

                        var noiseuniform = new RDUniform();
                        noiseuniform.UniformType = RenderingDevice.UniformType.SamplerWithTexture;
                        noiseuniform.Binding = 2;
                        noiseuniform.AddId(_linearSampler);
                        noiseuniform.AddId(RenderingServer.TextureGetRdTexture(LargeScaleNoise.GetRid()));
                        _uniformsArray.Add(noiseuniform);
                        

                        var mediumnoiseuniform = new RDUniform();
                        mediumnoiseuniform.UniformType = RenderingDevice.UniformType.SamplerWithTexture;
                        mediumnoiseuniform.Binding = 3;
                        mediumnoiseuniform.AddId(_linearSampler);
                        mediumnoiseuniform.AddId(RenderingServer.TextureGetRdTexture(MediumScaleNoise.GetRid()));
                        _uniformsArray.Add(mediumnoiseuniform);

                        var smallnoiseuniform = new RDUniform();
                        smallnoiseuniform.UniformType = RenderingDevice.UniformType.SamplerWithTexture;
                        smallnoiseuniform.Binding = 4;
                        smallnoiseuniform.AddId(_linearSampler);
                        smallnoiseuniform.AddId(RenderingServer.TextureGetRdTexture(SmallScaleNoise.GetRid()));
                        _uniformsArray.Add(smallnoiseuniform);

                        var heightgradientuniform = new RDUniform();
                        heightgradientuniform.UniformType = RenderingDevice.UniformType.SamplerWithTexture;
                        heightgradientuniform.Binding = 5;
                        heightgradientuniform.AddId(_linearSamplerNoRepeat);
                        heightgradientuniform.AddId(RenderingServer.TextureGetRdTexture(HeightGradient.GetRid()));
                        _uniformsArray.Add(heightgradientuniform);

                        _generalDataBuffer = _rd.UniformBufferCreate(76 * 4);
                        var camerauniform = new RDUniform();
                        camerauniform.UniformType = RenderingDevice.UniformType.UniformBuffer;
                        camerauniform.Binding = 6;
                        camerauniform.AddId(_generalDataBuffer);
                        _uniformsArray.Add(camerauniform);

                        _uniformSets[view] = _rd.UniformSetCreate(_uniformsArray, _shader, 0);
                    }
                }

                _time += 1.0f;
                using var ms = new System.IO.MemoryStream();
                using var bw = new System.IO.BinaryWriter(ms);

                bw.Write((float)size.X);
                bw.Write((float)size.Y);
                bw.Write(LargeNoiseScale);
                bw.Write(MediumNoiseScale);

                bw.Write(_time);
                bw.Write(CloudsCoverage);
                bw.Write(CloudsDensity);
                bw.Write(CloudsDetailPower);

                bw.Write(LightingDensity);
                bw.Write(0.0f);
                bw.Write(0.0f);
                bw.Write(0.0f);

                _pushConstants = ms.ToArray();
                _lastSize = size;

                UpdateMatricies(renderData.GetRenderSceneData());

                uint xGroups = ((uint)size.X - 1) / 8 + 1;
                uint yGroups = ((uint)size.Y - 1) / 8 + 1;

                for (uint view = 0; view < viewCount; view++)
                {
                    var computeList = _rd.ComputeListBegin();
                    _rd.ComputeListBindComputePipeline(computeList, _pipeline);
                    _rd.ComputeListBindUniformSet(computeList, _uniformSets[view], 0);
                    _rd.ComputeListSetPushConstant(computeList, _pushConstants, (uint)_pushConstants.Length);
                    _rd.ComputeListDispatch(computeList, xGroups, yGroups, 1);
                    _rd.ComputeListEnd();
                }
            }
        }
    }

    private void UpdateMatricies(RenderSceneData renderSceneData)
    {
        var cameraTR = renderSceneData.GetCamTransform();
        var viewProj = renderSceneData.GetCamProjection();

        if (_camMat == null) _camMat = new float[16];
        if (_projMat == null) _projMat = new float[16];
        if (_simpleData == null) _simpleData = new float[40];
        if (_generalData == null) _generalData = new byte[76 * 4];

        _camMat[0] = cameraTR.Basis.X.X;
        _camMat[1] = cameraTR.Basis.X.Y;
        _camMat[2] = cameraTR.Basis.X.Z;
        _camMat[3] = 0;

        _camMat[4] = cameraTR.Basis.Y.X;
        _camMat[5] = cameraTR.Basis.Y.Y;
        _camMat[6] = cameraTR.Basis.Y.Z;
        _camMat[7] = 0;

        _camMat[8] = cameraTR.Basis.Z.X;
        _camMat[9] = cameraTR.Basis.Z.Y;
        _camMat[10] = cameraTR.Basis.Z.Z;
        _camMat[11] = 0;

        _camMat[12] = cameraTR.Origin.X;
        _camMat[13] = cameraTR.Origin.Y;
        _camMat[14] = cameraTR.Origin.Z;
        _camMat[15] = 1.0f;

        _projMat[0] = viewProj.X.X;
        _projMat[1] = viewProj.X.Y;
        _projMat[2] = viewProj.X.Z;
        _projMat[3] = viewProj.X.W;

        _projMat[4] = viewProj.Y.X;
        _projMat[5] = viewProj.Y.Y;
        _projMat[6] = viewProj.Y.Z;
        _projMat[7] = viewProj.Y.W;

        _projMat[8] = viewProj.Z.X;
        _projMat[9] = viewProj.Z.Y;
        _projMat[10] = viewProj.Z.Z;
        _projMat[11] = viewProj.Z.W;

        _projMat[12] = viewProj.W.X;
        _projMat[13] = viewProj.W.Y;
        _projMat[14] = viewProj.W.Z;
        _projMat[15] = viewProj.W.W;

        _simpleData[0] = PrimaryDirectionalLightDirection.X;
        _simpleData[1] = PrimaryDirectionalLightDirection.Y;
        _simpleData[2] = PrimaryDirectionalLightDirection.Z;
        _simpleData[3] = CloudsSharpnessPower;

        _simpleData[4] = PrimaryDirectionalLightColor.R;
        _simpleData[5] = PrimaryDirectionalLightColor.G;
        _simpleData[6] = PrimaryDirectionalLightColor.B;
        _simpleData[7] = PrimaryDirectionalLightColor.A;

        
        _simpleData[8] = AmbientLightColor.R;
        _simpleData[9] = AmbientLightColor.G;
        _simpleData[10] = AmbientLightColor.B;
        _simpleData[11] = AmbientLightColor.A;

        _simpleData[12] = GroundColor.R;
        _simpleData[13] = GroundColor.G;
        _simpleData[14] = GroundColor.B;
        _simpleData[15] = GroundColor.A;

        _simpleData[16] = DistanceFogColor.R;
        _simpleData[17] = DistanceFogColor.G;
        _simpleData[18] = DistanceFogColor.B;
        _simpleData[19] = DistanceFogColor.A;

        _simpleData[20] = SmallNoiseScale;
        _simpleData[21] = MinStepDistance;
        _simpleData[22] = MaxStepDistance;
        _simpleData[23] = StepDistanceBias;

        _simpleData[24] = CloudFloor;
        _simpleData[25] = CloudCeiling;
        _simpleData[26] = (float)MaxStepCount;
        _simpleData[27] = (float)LightingStepCount;

        _simpleData[28] = LargeScaleCloudsPosition.X;
        _simpleData[29] = LargeScaleCloudsPosition.Y;
        _simpleData[30] = LargeScaleCloudsPosition.Z;
        _simpleData[31] = CloudsLightingSharpnessPower;

        _simpleData[32] = MediumScaleCloudsPosition.X;
        _simpleData[33] = MediumScaleCloudsPosition.Y;
        _simpleData[34] = MediumScaleCloudsPosition.Z;
        _simpleData[35] = LightingStepDistance;

        _simpleData[36] = DetailCloudsPosition.X;
        _simpleData[37] = DetailCloudsPosition.Y;
        _simpleData[38] = DetailCloudsPosition.Z;
        _simpleData[39] = AtmosphericDensity;

        Buffer.BlockCopy(_camMat, 0, _generalData, 0, 64);
        Buffer.BlockCopy(_projMat, 0, _generalData, 64, 64);
        Buffer.BlockCopy(_simpleData, 0, _generalData, 128, 160);

        //string breakdown = "";
        //foreach (var item in _generalData)
        //{
        //    breakdown += item.ToString() + "  ";
        //}
        //GD.Print(breakdown);

        _rd.BufferUpdate(_generalDataBuffer, 0, (uint)_generalData.Length, _generalData);
    }
}
