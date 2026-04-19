extends Destroyable
class_name Meteor

const DRIFT_INTERVAL_MIN: float = 2.0
const DRIFT_INTERVAL_MAX: float = 5.5
const DRIFT_IMPULSE_MIN: float = 0.12
const DRIFT_IMPULSE_MAX: float = 0.55

const OUTLINE_BY_DROP: Dictionary = {
	Item.Item_Type.ROCK: Color(0.72, 0.58, 0.42),
	Item.Item_Type.METAL: Color(0.82, 0.9, 1.0),
	Item.Item_Type.OXYGEN: Color(0.35, 0.92, 1.0),
	Item.Item_Type.WATER: Color(0.2, 0.48, 1.0),
}

@onready var drift_timer: Timer = $DriftTimer

var simulated: bool = true
var collision_layer_default: int = 1


func _ready() -> void:
	super._ready()
	collision_layer_default = collision_layer
	add_to_group(&"meteor_cull")
	call_deferred("_apply_stencil_outline_for_resource")
	drift_timer.timeout.connect(_on_drift_timer_timeout)
	_randomize_drift_wait_time()
	drift_timer.start()


func set_simulated(enabled: bool) -> void:
	if simulated == enabled:
		return
	simulated = enabled
	if enabled:
		freeze = false
		visible = true
		collision_layer = collision_layer_default
		drift_timer.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		freeze = true
		visible = false
		collision_layer = 0
		drift_timer.process_mode = Node.PROCESS_MODE_DISABLED


func _apply_stencil_outline_for_resource() -> void:
	var tint_color: Color = OUTLINE_BY_DROP.get(resource_drop, Color(0, 1, 0.14))
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index: int in mesh_instance.mesh.get_surface_count():
			var active_material: Material = mesh_instance.get_active_material(surface_index)
			if not (active_material is StandardMaterial3D):
				continue
			var duplicated_material: StandardMaterial3D = active_material.duplicate(true)
			duplicated_material.stencil_color = tint_color
			if duplicated_material.next_pass is StandardMaterial3D:
				var outline_material: StandardMaterial3D = (
					duplicated_material.next_pass as StandardMaterial3D
				).duplicate(true)
				outline_material.albedo_color = tint_color
				duplicated_material.next_pass = outline_material
			mesh_instance.set_surface_override_material(surface_index, duplicated_material)


func _on_destroyable_destroyed() -> void:
	GlobalValues.add_fuel_from_meteor()
	GlobalValues.show_meteor_reward_toast(resource_drop, drop_rate)


func _randomize_drift_wait_time() -> void:
	drift_timer.wait_time = randf_range(DRIFT_INTERVAL_MIN, DRIFT_INTERVAL_MAX)


func _on_drift_timer_timeout() -> void:
	var impulse_direction: Vector3 = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	)
	if impulse_direction.length_squared() < 0.0001:
		impulse_direction = Vector3(1, 0, 0)
	impulse_direction = impulse_direction.normalized()
	apply_central_impulse(
		impulse_direction * randf_range(DRIFT_IMPULSE_MIN, DRIFT_IMPULSE_MAX)
	)
	_randomize_drift_wait_time()
