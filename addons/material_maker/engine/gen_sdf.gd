tool
extends MMGenShader
class_name MMGenSDF


export var editor : bool = false
var scene : Array = []


func _ready():
	pass # Replace with function body.

func get_type() -> String:
	return "sdf"

func get_type_name() -> String:
	return "EasySDF"

func get_filtered_parameter_defs(parameters_filter : String) -> Array:
	if parameters_filter == "":
		return get_parameter_defs()
	else:
		var defs = []
		for p in get_parameter_defs():
			if p.name.begins_with(parameters_filter):
				defs.push_back(p)
		return defs

func get_output_defs(_show_hidden : bool = false) -> Array:
	var outputs : Array
	var color_output : String
	var gs_output : String
	match get_scene_type():
		"SDF3D":
			outputs = [ { type="sdf3d" } ]
			color_output = "tex3d"
			gs_output = "tex3d_gs"
		_:
			if editor:
				outputs = [ { type="rgb" } ]
			else:
				outputs = [ { type="sdf2d" } ]
			color_output = "rgba"
			gs_output = "float"
	outputs.push_back({type=color_output, channel="albedo"})
	outputs.push_back({type=gs_output, channel="metallic"})
	outputs.push_back({type=gs_output, channel="roughness"})
	outputs.push_back({type=color_output, channel="emission"})
	return outputs

func get_scene_type() -> String:
	if scene.empty():
		return ""
	return mm_sdf_builder.item_types[mm_sdf_builder.item_ids[scene[0].type]].item_category

func set_sdf_scene(s : Array):
	scene = s.duplicate(true)
	var scene_type : String = get_scene_type()
	var shader_model = { includes=[], parameters=[]}
	var uv = "$uv"
	# Generate distance function
	match scene_type:
		"SDF3D":
			shader_model.instance = "float $(name)_d(vec3 uv, int index) {\n"
		_:
			uv = "$uv-vec2(0.5)"
			shader_model.instance = "float $(name)_d(vec2 uv, int index) {\n"
	var first : bool = true
	var parameter_defs = []
	for i in scene:
		if i.has("hidden") and i.hidden:
			continue
		var item_shader_model = mm_sdf_builder.scene_to_shader_model(i, "uv", editor)
		if item_shader_model.has("includes"):
			shader_model.includes.append_array(item_shader_model.includes)
		if item_shader_model.has("parameters"):
			parameter_defs.append_array(item_shader_model.parameters)
		if item_shader_model.has("code"):
			shader_model.instance += item_shader_model.code.replace("$(name_uv)", "")
		if item_shader_model.has("outputs"):
			var output = item_shader_model.outputs[0]
			var output_name
			var field : String
			if scene_type == "SDF2D":
				field = "sdf2d"
			else:
				field = "sdf3d"
			if item_shader_model.outputs[0].has(field):
				output_name = item_shader_model.outputs[0][field].replace("$(name_uv)", "")
				if first:
					shader_model.instance += "float return_value = %s;\n" % output_name
					first = false
				else:
					shader_model.instance += "return_value = min(return_value, %s);\n" % output_name
	if first:
		shader_model.instance += "return 1.0;"
	else:
		shader_model.instance += "return index == 0 ? return_value : 1.0;"
	shader_model.instance += "}\n"
	match scene_type:
		"SDF3D":
			if editor:
				shader_model.code = "float $(name_uv)_d = $(name)_d(%s, 0);\n" % uv
			else:
				shader_model.code = "float $(name_uv)_d = $(name)_d(%s*vec3(1.0, -1.0, -1.0), 0);\n" % uv
			shader_model.parameters = parameter_defs
			shader_model.outputs = [{ sdf3d = "$(name_uv)_d", type = "sdf3d" }]
		_:
			if editor:
				parameter_defs.push_back({default=-1, name="index", type="float"})
			shader_model.parameters = parameter_defs
			shader_model.outputs = [{ sdf2d = "$(name)_d(%s, 0)" % uv, type = "sdf2d" }]
	for p in parameter_defs:
		if p.type == "float" and p.default is int:
			parameters[p.name] = float(p.default)
		else:
			parameters[p.name] = p.default
	set_shader_model(shader_model)

func _serialize(data: Dictionary) -> Dictionary:
	data.sdf_scene = mm_sdf_builder.serialize_scene(scene)
	return data

func _deserialize(data : Dictionary) -> void:
	if data.has("sdf_scene"):
		set_sdf_scene(mm_sdf_builder.deserialize_scene(data.sdf_scene))

func edit(node) -> void:
	if scene != null:
		var edit_window = load("res://material_maker/windows/sdf_builder/sdf_builder.tscn").instance()
		node.get_parent().add_child(edit_window)
		edit_window.set_sdf_scene(scene)
		edit_window.connect("node_changed", node, "update_sdf_generator")
		edit_window.connect("editor_window_closed", node, "finalize_generator_update")
		edit_window.popup_centered()
