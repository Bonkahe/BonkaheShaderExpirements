using Godot;
using System;

[GlobalClass]
[Tool]
public partial class SunshineCloudsDriver : Node
{
    [Export] public bool UpdateContiniously { get { return _updateContiniously; } set { _updateContiniously = value; RetrieveTextureData(); } }
    private bool _updateContiniously = false;
    [Export] public Vector3 WindDirection { get; set; } = Vector3.Zero;
    [Export] public float LargeStructuresWindSpeed { get; set; } = 30.0f;
    [Export] public float BaseWindSpeed { get; set; } = 10.0f;
    [Export] public float DetailCloudsSpeed { get; set; } = 12.0f;
    [Export] public SunshineClouds CloudsResource { get; set; }

    [Export] public Vector3 LargeCloudsPos = Vector3.Zero;
    [Export] public Vector3 MediumCloudsPos = Vector3.Zero;
    [Export] public Vector3 SmallCloudsPos = Vector3.Zero;


    private float _largeCloudsDomain = 0.0f;
    private float _mediumCloudsDomain = 0.0f;
    private float _smallCloudsDomain = 0.0f;



    public override void _Ready()
    {
        if (_updateContiniously)
        {
            if (CloudsResource == null)
            {
                _updateContiniously = false;
                return;
            }
            RetrieveTextureData();
        }
    }


    public override void _Process(double delta)
    {
        if (_updateContiniously)
        {
            if (CloudsResource == null)
            {
                _updateContiniously = false;
                return;
            }
            LargeCloudsPos += WindDirection * LargeStructuresWindSpeed * (float)delta;
            LargeCloudsPos = WrapVector(LargeCloudsPos, _largeCloudsDomain);
            MediumCloudsPos += WindDirection * BaseWindSpeed * (float)delta;
            MediumCloudsPos = WrapVector(MediumCloudsPos, _mediumCloudsDomain);
            SmallCloudsPos += (-WindDirection + Vector3.Up).Normalized() * DetailCloudsSpeed * (float)delta;
            SmallCloudsPos = WrapVector(SmallCloudsPos, _smallCloudsDomain);

            CloudsResource.LargeScaleCloudsPosition = LargeCloudsPos;
            CloudsResource.MediumScaleCloudsPosition = MediumCloudsPos;
            CloudsResource.DetailCloudsPosition = SmallCloudsPos;
        }
    }

    private void RetrieveTextureData()
    {
        if (CloudsResource != null)
        {
            _largeCloudsDomain = CloudsResource.LargeNoiseScale / 2.0f;
            GD.Print("Large domain: ", _largeCloudsDomain);
            _mediumCloudsDomain = CloudsResource.MediumNoiseScale / 2.0f;
            GD.Print("Medium domain: ", _mediumCloudsDomain);
            _smallCloudsDomain = CloudsResource.SmallNoiseScale / 2.0f;
            GD.Print("Small domain: ", _smallCloudsDomain);
        }
    }

    public Vector3 WrapVector(Vector3 target, float domainSize)
    {
        if (target.X > domainSize)
        {
            target.X -= domainSize * 2.0f;
        }
        else if (target.X < -domainSize)
        {
            target.X += domainSize * 2.0f;
        }

        if (target.Y > domainSize)
        {
            target.Y -= domainSize * 2.0f;
        }
        else if (target.Y < -domainSize)
        {
            target.Y += domainSize * 2.0f;
        }

        if (target.Z > domainSize)
        {
            target.Z -= domainSize * 2.0f;
        }
        else if (target.Z < -domainSize)
        {
            target.Z += domainSize * 2.0f;
        }

        return target;
    }
}
