@tool
extends Camera3D

@export var cameraTarget: Node3D;
@export var movementSpeed : float;


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if (cameraTarget != null):
		global_position = global_position.lerp(cameraTarget.global_position, delta * movementSpeed);
