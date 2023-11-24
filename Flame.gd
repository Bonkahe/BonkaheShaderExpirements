@tool
extends MeshInstance3D

@export var light: OmniLight3D;
@export var lightflickerTimeScale: float;
@export var lightflickerPositionScale: float;
@export var lightflickerNoise: Noise;
@export var lightBaseLine: float;
@export var lightflickerNoisePower: float;

@export var maxDrift : float;
@export var upwardDrift : float;
@export var velocityMultiplier : float;
@export var RandomNoisePower : float;

var lastPosition : Vector3;
var timecurrent: float = 0.0;

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var rng := RandomNumberGenerator.new();
	rng.randomize();
	lastPosition = lastPosition.lerp(global_position + Vector3(rng.randf_range(-RandomNoisePower,RandomNoisePower), rng.randf_range(RandomNoisePower,RandomNoisePower), rng.randf_range(-RandomNoisePower,RandomNoisePower)), delta * velocityMultiplier);
	lastPosition += Vector3.UP * delta * upwardDrift;
	if (global_position.distance_to(lastPosition) > maxDrift):
		lastPosition = global_position + (lastPosition - global_position).normalized() * maxDrift;
	
	if (light != null):
		timecurrent += delta * lightflickerTimeScale;
		light.global_position = lastPosition;
		var newSamplePos : Vector3 = (light.global_position * lightflickerPositionScale) + (Vector3.UP * timecurrent);
		light.light_energy = lightBaseLine + maxf( (lightflickerNoise.get_noise_3d(newSamplePos.x, newSamplePos.y, newSamplePos.z) * lightflickerNoisePower) + 1.0, 0.0);
		print(light.light_energy);
	
	set_instance_shader_parameter("OffsetDirection", lastPosition);
