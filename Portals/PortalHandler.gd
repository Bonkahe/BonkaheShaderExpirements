extends Node

@export var RootCamera : Camera3D

@export var DoorAMesh : MeshInstance3D
@export var DoorBMesh : MeshInstance3D

@export var DoorACamera : Camera3D
@export var DoorBCamera : Camera3D



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var Cam_Pos_Relative_DoorA : Vector3 = DoorAMesh.to_local(RootCamera.global_position) * -1
	var Cam_Pos_Relative_DoorB : Vector3 = DoorBMesh.to_local(RootCamera.global_position) * -1
	
	var Cam_Rot_Relative_DoorA : Vector3 = (DoorAMesh.global_rotation - RootCamera.global_rotation) * -1
	var Cam_Rot_Relative_DoorB : Vector3 = (DoorBMesh.global_rotation - RootCamera.global_rotation) * -1
	
	#DoorACamera.global_position = DoorBMesh.to_global(Cam_Pos_Relative_DoorB)
	#DoorBCamera.global_position = DoorAMesh.to_global(Cam_Pos_Relative_DoorA)
	#
	#DoorACamera.global_rotation = DoorBMesh.global_rotation + Cam_Rot_Relative_DoorB
	#DoorBCamera.global_rotation = DoorAMesh.global_rotation + Cam_Rot_Relative_DoorA
	
	DoorACamera.global_position = DoorAMesh.to_global(Cam_Pos_Relative_DoorA)
	DoorBCamera.global_position = DoorBMesh.to_global(Cam_Pos_Relative_DoorB)
	
	DoorACamera.global_rotation = DoorAMesh.global_rotation + Cam_Rot_Relative_DoorA
	DoorBCamera.global_rotation = DoorBMesh.global_rotation + Cam_Rot_Relative_DoorB
	
	DoorACamera.near = DoorBMesh.global_position.distance_to(DoorACamera.global_position)
	DoorBCamera.near = DoorAMesh.global_position.distance_to(DoorBCamera.global_position)
	
