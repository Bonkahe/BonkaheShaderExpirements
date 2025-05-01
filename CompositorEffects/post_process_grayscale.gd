@tool
class_name PostProcessGrayScale
extends CompositorEffect

var rd: RenderingDevice
var shader: RID
var pipeline: RID

var nearest_sampler: RID


func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initialize_compute)
	
	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	nearest_sampler = RenderingServer.get_rendering_device().sampler_create(sampler_state)


# System notifications, we want to react on the notification that
# alerts us we are about to be destroyed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			# Freeing our shader will also free any dependents such as the pipeline!
			rd.free_rid(shader)


#region Code in this region runs on the rendering thread.
# Compile our shader at initialization.
func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return

	# Compile our shader.
	var shader_file := load("res://CompositorEffects/post_process_grayscale.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()

	shader = rd.shader_create_from_spirv(shader_spirv)
	if shader.is_valid():
		pipeline = rd.compute_pipeline_create(shader)


# Called by the rendering thread every frame.
func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if rd and p_effect_callback_type == EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT and pipeline.is_valid():
		# Get our render scene buffers object, this gives us access to our render buffers.
		# Note that implementation differs per renderer hence the need for the cast.
		var render_scene_buffers := p_render_data.get_render_scene_buffers()
		if render_scene_buffers:
			# Get our render size, this is the 3D render resolution!
			var size: Vector2i = render_scene_buffers.get_internal_size()
			if size.x == 0 and size.y == 0:
				return

			# We can use a compute shader here.
			@warning_ignore("integer_division")
			var x_groups := (size.x - 1) / 8 + 1
			@warning_ignore("integer_division")
			var y_groups := (size.y - 1) / 8 + 1
			var z_groups := 1

			# Create push constant.
			# Must be aligned to 16 bytes and be in the same order as defined in the shader.
			var push_constant := PackedFloat32Array([
				size.x,
				size.y,
				0.0,
				0.0,
			])

			# Loop through views just in case we're doing stereo rendering. No extra cost if this is mono.
			var view_count: int = render_scene_buffers.get_view_count()
			for view in view_count:
				# Get the RID for our color image, we will be reading from and writing to it.
				var input_image: RID = render_scene_buffers.get_color_layer(view)
				var depth_image: RID = render_scene_buffers.get_depth_layer(view, false)
				# Create a uniform set, this will be cached, the cache will be cleared if our viewports configuration is changed.
				var uniform := RDUniform.new()
				uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				uniform.binding = 0
				uniform.add_id(input_image)
				#var depthuniform := RDUniform.new()
				#depthuniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
				#depthuniform.binding = 1
				#depthuniform.add_id(depth_image)
				
				var depthuniform := RDUniform.new()
				depthuniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
				depthuniform.binding = 1
				depthuniform.add_id(nearest_sampler)
				depthuniform.add_id(depth_image)
				
				var render_scene_data = p_render_data.get_render_scene_data()
				
				var cam_tr = render_scene_data.get_cam_transform()
				var view_proj = render_scene_data.get_view_projection(view)
				
				var cam_mat = [
					cam_tr.basis.x.x, cam_tr.basis.x.y, cam_tr.basis.x.z, 0.0, 
					cam_tr.basis.y.x, cam_tr.basis.y.y, cam_tr.basis.y.z, 0.0, 
					cam_tr.basis.z.x, cam_tr.basis.z.y, cam_tr.basis.z.z, 0.0, 
					cam_tr.origin.x, cam_tr.origin.y, cam_tr.origin.z, 1.0, 
				]
				
				var proj_mat = [
					view_proj.x.x, view_proj.x.y, view_proj.x.z, view_proj.x.w, 
					view_proj.y.x, view_proj.y.y, view_proj.y.z, view_proj.y.w, 
					view_proj.z.x, view_proj.z.y, view_proj.z.z, view_proj.z.w, 
					view_proj.w.x, view_proj.w.y, view_proj.w.z, view_proj.w.w, 
				]
				
				var cma = PackedFloat32Array(cam_mat).to_byte_array()
				var vpa = PackedFloat32Array(proj_mat).to_byte_array()
				
				var pb = PackedByteArray()
				pb.append_array(cma)
				pb.append_array(vpa)
				
				var mat_buffer : RID =  rd.uniform_buffer_create(128, pb)
				
				var matrices_uniform : RDUniform = RDUniform.new()
				matrices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
				matrices_uniform.binding = 2
				matrices_uniform.add_id(mat_buffer)
				
				var uniforms : Array[RDUniform] = []
				uniforms.append(uniform)
				uniforms.append(depthuniform)
				uniforms.append(matrices_uniform)
				#var uniform_set := UniformSetCacheRD.get_cache(shader, 0, [uniform, depthuniform])
				var uniformset = rd.uniform_set_create(uniforms, shader, 0)
				# Run our compute shader.
				var compute_list := rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
				rd.compute_list_bind_uniform_set(compute_list, uniformset, 0)
				rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
				rd.compute_list_end()
#endregion
