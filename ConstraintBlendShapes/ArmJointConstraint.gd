@tool
extends Node

@export var meshInstance : MeshInstance3D;
@export var blendShapeName: String;
@export var jointBeginningName: String;
@export var jointEndingName: String;
@export var skeletonref : Skeleton3D;
@export var runCode : bool = true;
@export var invertLerp : bool = false;
@export var boneValid : bool = false;
@export var angleOffset : float = 90.0;
@export var angleSpread : float = 0.0;
@export var currentAngle : float = 0.0;
@export var currentLerp : float = 0.0;

var boneBeginningID : int;
var boneEndID : int;
var blendShapeID : int;
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if (!runCode):
		return;
	boneValid = false;
	if (jointBeginningName != "" && jointEndingName != "" && blendShapeName != "" && skeletonref != null && meshInstance != null):
		boneBeginningID = skeletonref.find_bone(jointBeginningName);
		boneEndID = skeletonref.find_bone(jointEndingName);
		blendShapeID = meshInstance.find_blend_shape_by_name(blendShapeName);
		if boneBeginningID != -1 && boneEndID != -1 && blendShapeID != -1:
			boneValid = true;
	
	if (boneValid):
		var beginningBonePose = skeletonref.get_bone_global_pose(boneBeginningID);
		var endingBonePose = skeletonref.get_bone_global_pose(boneEndID);
		
		var desiredtorsoPosition = Vector3(0.0, 1.0, 0.0); #< - WORLD SPACE
		var resultingPosition = skeletonref.to_local(desiredtorsoPosition);
		
		beginningBonePose.origin = resultingPosition;
		
		skeletonref.set_bone_global_pose_override(boneBeginningID, beginningBonePose, 1.0)
		
		
		
		var angle = abs(beginningBonePose.basis.y.angle_to(endingBonePose.basis.y));
		angle = rad_to_deg(angle);
		currentAngle = angle;
		#print(currentAngle);
		angle = clamp(angle - (angleOffset - (angleSpread / 2)), 0.0, angleSpread);
		currentLerp = angle / angleSpread;
		if (invertLerp):
			currentLerp = 1.0 - currentLerp;
		
		meshInstance.set_blend_shape_value(blendShapeID, currentLerp);
		#angle = clamp((angle - (90 - (angleSpread / 2))) / angleSpread, 0.0, 1.0);
		
		#print(rad_to_deg( angle));
		#print(beginningBonePose.basis - endingBonePose.basis);
		#var bonePose = skeletonref.get_bone_global_pose(boneID);
		
		#print(bonePose.basis.get_euler());
